import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { BranchType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { PermissionCacheService } from './permission-cache.service';

const MODULE = 'rbac';

/** The shelf cross-tenant role templates live on. Never a tenant's own. */
const SYSTEM_TENANT = '__system__';

/**
 * Everything the super admin role console reads and writes.
 *
 * Kept apart from {@link RbacService}, which resolves a *user's* access on the
 * hot login path. This one is the administrative side: it is allowed to be
 * chattier, and every mutation is audited because changing who can see what in
 * a government system is exactly the kind of act that gets questioned later.
 */
@Injectable()
export class RbacAdminService {
  private readonly logger = new Logger(RbacAdminService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    @Optional() private readonly cache?: PermissionCacheService,
  ) {}

  // ── Reads ─────────────────────────────────────────────────────────────────

  /** The screen catalogue, grouped, for the console's checklist. */
  async listScreens() {
    const screens = await this.prisma.appScreen.findMany({
      where: { is_active: true },
      orderBy: [{ group_key: 'asc' }, { sort_order: 'asc' }],
    });

    const groups = new Map<string, typeof screens>();
    for (const s of screens) {
      if (!groups.has(s.group_key)) groups.set(s.group_key, []);
      groups.get(s.group_key)!.push(s);
    }

    return {
      total: screens.length,
      groups: [...groups.entries()].map(([group_key, items]) => ({
        group_key,
        items,
      })),
    };
  }

  /** The permission catalogue, grouped by module. */
  async listPermissions() {
    const perms = await this.prisma.permission.findMany({
      orderBy: [{ module: 'asc' }, { action: 'asc' }],
    });

    const byModule = new Map<string, typeof perms>();
    for (const p of perms) {
      if (!byModule.has(p.module)) byModule.set(p.module, []);
      byModule.get(p.module)!.push(p);
    }

    return [...byModule.entries()].map(([module, items]) => ({
      module,
      items,
    }));
  }

  /**
   * Roles available to a tenant: its own, plus the `__system__` templates.
   * Optionally narrowed to those that make sense for a body type — a village
   * panchayat has no Municipal Commissioner.
   */
  async listRoles(tenantId: string, branchType?: BranchType) {
    const roles = await this.prisma.role.findMany({
      where: {
        tenant_id: { in: [tenantId, '__system__'] },
        is_active: true,
      },
      include: {
        _count: {
          select: { user_roles: true, permissions: true, screen_access: true },
        },
      },
      orderBy: [{ hierarchy_level: 'asc' }, { display_name: 'asc' }],
    });

    const applicable = branchType
      ? roles.filter(
          (r) =>
            r.applicable_branch_types.length === 0 ||
            r.applicable_branch_types.includes(branchType),
        )
      : roles;

    return applicable.map((r) => ({
      ...r,
      user_count: r._count.user_roles,
      permission_count: r._count.permissions,
      screen_count: r._count.screen_access,
    }));
  }

  /** One role with its grants, for the console's detail pane. */
  async getRole(tenantId: string, roleId: number) {
    const role = await this.prisma.role.findFirst({
      where: { id: roleId, tenant_id: { in: [tenantId, '__system__'] } },
      include: {
        permissions: { include: { permission: true } },
        screen_access: { include: { screen: true } },
        _count: { select: { user_roles: true } },
      },
    });
    if (!role) throw new NotFoundException(`Role #${roleId} not found`);

    return {
      ...role,
      permission_codes: role.permissions.map((p) => p.permission.code).sort(),
      screen_keys: role.screen_access
        .filter((a) => a.can_view)
        .map((a) => a.screen.key)
        .sort(),
      user_count: role._count.user_roles,
    };
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /**
   * Load a role and refuse if it belongs to another tenant.
   *
   * `__system__` roles are readable by everyone but editable by nobody through
   * this API: they are the shared template set, and letting one tenant edit
   * them would silently change every other tenant's roles.
   */
  private async editableRole(tenantId: string, roleId: number) {
    const role = await this.prisma.role.findUnique({ where: { id: roleId } });
    if (!role) throw new NotFoundException(`Role #${roleId} not found`);

    if (role.tenant_id === '__system__') {
      throw new ForbiddenException(
        `"${role.display_name}" is a shared system role. Clone it into your tenant to change its access.`,
      );
    }
    if (role.tenant_id !== tenantId) {
      throw new ForbiddenException('That role belongs to another tenant');
    }
    return role;
  }

  /**
   * Record that this tenant has made the role their own.
   *
   * A role provisioned from a template starts identical to it, and
   * {@link RoleTemplateService.syncTenant} may bring later improvements across.
   * The moment a council changes the grants themselves, that stops being
   * welcome: a sync would revert a deliberate decision, and unlike being left
   * on an old default, that is invisible until somebody loses access they were
   * given on purpose.
   *
   * Stamped once and never cleared. A role that has been customised and then
   * edited back to match its template is still a role somebody is managing by
   * hand, and quietly re-enrolling it in automatic updates would be a surprise.
   */
  private async markCustomised(role: {
    id: number;
    template_id: number | null;
    customised_at: Date | null;
  }) {
    if (role.template_id == null || role.customised_at !== null) return;

    await this.prisma.role.update({
      where: { id: role.id },
      data: { customised_at: new Date() },
    });
    this.logger.log(
      `Role #${role.id} now differs from its template; future syncs will skip it`,
    );
  }

  /** Resolve and enforce the platform template switch for a role. */
  private async assertTemplateEnabled(
    tenantId: string,
    role: { id: number; tenant_id: string; template_id: number | null },
  ): Promise<number | null> {
    const templateId =
      role.template_id ?? (role.tenant_id === SYSTEM_TENANT ? role.id : null);
    if (templateId == null) return null;

    const config = await this.prisma.tenantRoleTemplate.findUnique({
      where: {
        tenant_id_role_template_id: {
          tenant_id: tenantId,
          role_template_id: templateId,
        },
      },
      select: { enabled: true },
    });
    if (config?.enabled === false) {
      throw new ForbiddenException(
        'This role template is disabled for your tenant',
      );
    }
    return templateId;
  }

  /**
   * Create a role from scratch, inside the caller's own tenant.
   *
   * Until this existed the only way to get a role was `cloneRole` — a council
   * could copy one of the shipped designations but never define one of its
   * own. That made every client dependent on the platform operator for a job
   * title the shipped roster happens not to have, which is most of them once
   * you leave the six body types this was seeded for.
   *
   * The role starts with no grants at all. A new designation that could see
   * everything by default would be a way to escalate by creating rather than
   * by being granted.
   */
  async createRole(
    tenantId: string,
    userId: number,
    input: {
      name: string;
      display_name: string;
      display_name_ta?: string;
      department?: string;
      hierarchy_level?: number;
      can_approve?: boolean;
      applicable_branch_types?: BranchType[];
    },
  ) {
    const name = input.name
      ?.trim()
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, '_');
    if (!name) throw new BadRequestException('A role needs a name');
    if (name.length > 60) {
      throw new BadRequestException('That role name is too long');
    }

    const display = input.display_name?.trim();
    if (!display) throw new BadRequestException('A role needs a display name');

    // Names are matched against `@Roles()` decorators, so one that collides
    // with a shipped role would silently inherit that role's API access.
    const clash = await this.prisma.role.findFirst({
      where: {
        tenant_id: { in: [tenantId, SYSTEM_TENANT] },
        org_unit_id: null,
        name,
      },
    });
    if (clash) {
      throw new BadRequestException(
        clash.tenant_id === SYSTEM_TENANT
          ? `"${name}" is a shipped role name. Clone it instead, or choose another name.`
          : `Your tenant already has a role named "${name}"`,
      );
    }

    const level = input.hierarchy_level ?? 5;
    if (level < 1 || level > 10) {
      throw new BadRequestException('Hierarchy level must be between 1 and 10');
    }

    const role = await this.prisma.role.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: null,
        name,
        display_name: display,
        display_name_ta: input.display_name_ta?.trim() || null,
        department: input.department?.trim() || null,
        // Level 0 is the platform operator's rung and is not offered.
        hierarchy_level: level,
        is_super_admin: false,
        can_approve: input.can_approve ?? false,
        // Not a system role: a tenant's own role must stay deletable by the
        // tenant that made it.
        is_system: false,
        is_active: true,
        applicable_branch_types: input.applicable_branch_types ?? [],
      },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: MODULE,
      entityType: 'role',
      entityId: role.id.toString(),
      action: 'role_created',
      afterValue: {
        name,
        display_name: display,
        hierarchy_level: level,
      },
    });

    this.logger.log(`Role "${name}" created in tenant ${tenantId}`);
    this.cache?.invalidateTenant(tenantId);
    return this.getRole(tenantId, role.id);
  }

  /**
   * Copy a `__system__` template into a tenant so it can be customised.
   *
   * This is how a council departs from the default without affecting anyone
   * else. Grants are copied so the clone starts identical to what people
   * already have, rather than empty.
   */
  async cloneRole(
    tenantId: string,
    roleId: number,
    userId: number,
    newName?: string,
  ) {
    const source = await this.prisma.role.findUnique({
      where: { id: roleId },
      include: { permissions: true, screen_access: true },
    });
    if (!source) throw new NotFoundException(`Role #${roleId} not found`);
    if (source.tenant_id !== tenantId && source.tenant_id !== SYSTEM_TENANT) {
      throw new ForbiddenException('That role belongs to another tenant');
    }
    const templateId = await this.assertTemplateEnabled(tenantId, source);

    const name = newName?.trim() || source.name;
    const existing = await this.prisma.role.findFirst({
      where: { tenant_id: tenantId, org_unit_id: null, name },
    });
    if (existing) {
      throw new BadRequestException(
        `Your tenant already has a role named "${name}"`,
      );
    }

    const clone = await this.prisma.role.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: null,
        name,
        display_name: source.display_name,
        display_name_ta: source.display_name_ta,
        department: source.department,
        hierarchy_level: source.hierarchy_level,
        // A cloned role never inherits the super-admin flag: escalation must be
        // a deliberate act, not a side effect of copying a template.
        is_super_admin: false,
        can_approve: source.can_approve,
        is_system: false,
        applicable_branch_types: source.applicable_branch_types,
        template_id: templateId,
        // A direct clone of an untouched platform template can safely receive
        // future template updates. Cloning a tenant-customised role cannot.
        customised_at: source.tenant_id === SYSTEM_TENANT ? null : new Date(),
        permissions: {
          create: source.permissions.map((p) => ({
            permission_id: p.permission_id,
            granted_by: userId,
          })),
        },
        screen_access: {
          create: source.screen_access.map((a) => ({
            screen_id: a.screen_id,
            can_view: a.can_view,
            granted_by: userId,
          })),
        },
      },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: MODULE,
      entityType: 'role',
      entityId: clone.id.toString(),
      action: 'role_cloned',
      afterValue: { from_role: source.name, name, tenant_id: tenantId },
    });

    this.cache?.invalidateTenant(tenantId);
    return this.getRole(tenantId, clone.id);
  }

  /**
   * Set which screens a role can see, as a whole list.
   *
   * Revoking flips `can_view` to false rather than deleting the row, so the
   * record of who granted it and when survives being switched off.
   */
  async setRoleScreens(
    tenantId: string,
    roleId: number,
    userId: number,
    screenKeys: string[],
  ) {
    const role = await this.editableRole(tenantId, roleId);

    const screens = await this.prisma.appScreen.findMany({
      where: { is_active: true },
      select: { id: true, key: true, is_platform_only: true },
    });

    const wanted = new Set(screenKeys);
    const unknown = screenKeys.filter((k) => !screens.some((s) => s.key === k));
    if (unknown.length) {
      throw new BadRequestException(`Unknown screen(s): ${unknown.join(', ')}`);
    }

    // Platform screens manage the platform itself, not a council's work.
    const platform = screens.filter(
      (s) => s.is_platform_only && wanted.has(s.key),
    );
    if (platform.length && !role.is_super_admin) {
      throw new BadRequestException(
        `Platform-only screen(s) cannot be granted to a branch role: ${platform
          .map((s) => s.key)
          .join(', ')}`,
      );
    }

    const before = await this.prisma.roleScreenAccess.findMany({
      where: { role_id: roleId, can_view: true },
      include: { screen: { select: { key: true } } },
    });

    for (const s of screens) {
      const shouldSee = wanted.has(s.key);
      await this.prisma.roleScreenAccess.upsert({
        where: { role_id_screen_id: { role_id: roleId, screen_id: s.id } },
        update: { can_view: shouldSee, granted_by: userId },
        create: {
          role_id: roleId,
          screen_id: s.id,
          can_view: shouldSee,
          granted_by: userId,
        },
      });
    }

    await this.markCustomised(role);

    const beforeKeys = before.map((b) => b.screen.key).sort();
    await this.audit.log({
      tenantId,
      userId,
      module: MODULE,
      entityType: 'role',
      entityId: roleId.toString(),
      action: 'role_screens_updated',
      beforeValue: { screens: beforeKeys },
      afterValue: { screens: [...wanted].sort() },
      changedFields: ['screen_access'],
    });

    this.logger.log(
      `Role ${role.name}: screens ${beforeKeys.length} → ${wanted.size}`,
    );
    this.cache?.invalidateTenant(tenantId);
    return this.getRole(tenantId, roleId);
  }

  /** Set a role's permission grants as a whole list. */
  async setRolePermissions(
    tenantId: string,
    roleId: number,
    userId: number,
    codes: string[],
  ) {
    const role = await this.editableRole(tenantId, roleId);

    const perms = await this.prisma.permission.findMany({
      where: { code: { in: codes } },
      select: { id: true, code: true },
    });
    const unknown = codes.filter((c) => !perms.some((p) => p.code === c));
    if (unknown.length) {
      throw new BadRequestException(
        `Unknown permission code(s): ${unknown.join(', ')}`,
      );
    }

    const before = await this.prisma.rolePermission.findMany({
      where: { role_id: roleId },
      include: { permission: { select: { code: true } } },
    });

    await this.prisma.$transaction([
      this.prisma.rolePermission.deleteMany({ where: { role_id: roleId } }),
      this.prisma.rolePermission.createMany({
        data: perms.map((p) => ({
          role_id: roleId,
          permission_id: p.id,
          granted_by: userId,
        })),
      }),
    ]);

    await this.markCustomised(role);

    await this.audit.log({
      tenantId,
      userId,
      module: MODULE,
      entityType: 'role',
      entityId: roleId.toString(),
      action: 'role_permissions_updated',
      beforeValue: { permissions: before.map((b) => b.permission.code).sort() },
      afterValue: { permissions: [...codes].sort() },
      changedFields: ['permissions'],
    });

    this.logger.log(
      `Role ${role.name}: permissions ${before.length} → ${perms.length}`,
    );
    this.cache?.invalidateTenant(tenantId);
    return this.getRole(tenantId, roleId);
  }

  /** Enable or disable a role outright. */
  async setRoleActive(
    tenantId: string,
    roleId: number,
    userId: number,
    isActive: boolean,
  ) {
    const role = await this.editableRole(tenantId, roleId);

    if (!isActive) {
      const holders = await this.prisma.userRole.count({
        where: { role_id: roleId },
      });
      if (holders > 0) {
        throw new BadRequestException(
          `${holders} user(s) still hold "${role.display_name}". Reassign them before disabling it.`,
        );
      }
    }

    await this.prisma.role.update({
      where: { id: roleId },
      data: { is_active: isActive },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: MODULE,
      entityType: 'role',
      entityId: roleId.toString(),
      action: isActive ? 'role_enabled' : 'role_disabled',
      beforeValue: { is_active: role.is_active },
      afterValue: { is_active: isActive },
      changedFields: ['is_active'],
    });

    this.cache?.invalidateTenant(tenantId);
    return this.getRole(tenantId, roleId);
  }

  // ── User assignment ───────────────────────────────────────────────────────

  /** Users holding a role, for the console's people pane. */
  async listRoleMembers(tenantId: string, roleId: number) {
    const rows = await this.prisma.userRole.findMany({
      where: { role_id: roleId },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            phone_e164: true,
            is_active: true,
            last_login_at: true,
            must_change_password: true,
          },
        },
        org_unit: { select: { id: true, name: true, branch_type: true } },
      },
      orderBy: { created_at: 'desc' },
    });

    return rows.filter((r) => r.user != null);
  }

  async assignRole(
    tenantId: string,
    userId: number,
    actorId: number,
    roleId: number,
    orgUnitId: number,
    isPrimary = false,
  ) {
    const [user, role, orgUnit] = await Promise.all([
      this.prisma.user.findFirst({
        where: { id: userId, tenant_id: tenantId },
      }),
      this.prisma.role.findFirst({
        where: { id: roleId, tenant_id: { in: [tenantId, '__system__'] } },
      }),
      this.prisma.orgUnit.findFirst({
        where: { id: orgUnitId, tenant_id: tenantId },
      }),
    ]);

    if (!user)
      throw new NotFoundException(`User #${userId} not found in your tenant`);
    if (!role)
      throw new NotFoundException(
        `Role #${roleId} not available to your tenant`,
      );
    if (!orgUnit)
      throw new ForbiddenException(
        `Branch #${orgUnitId} is not in your tenant`,
      );

    await this.assertTemplateEnabled(tenantId, role);

    // A role restricted to certain body types must not be granted at a branch
    // of a different type — that is how a village panchayat ends up with a
    // Municipal Commissioner.
    if (
      role.applicable_branch_types.length > 0 &&
      !role.applicable_branch_types.includes(orgUnit.branch_type)
    ) {
      throw new BadRequestException(
        `"${role.display_name}" does not exist at a ${orgUnit.branch_type.toLowerCase().replace(/_/g, ' ')}`,
      );
    }

    if (isPrimary) {
      await this.prisma.userRole.updateMany({
        where: { user_id: userId },
        data: { is_primary: false },
      });
    }

    // `upsert` is unusable here. The compound unique is
    // (user_id, role_id, org_unit_id, department_id) and `department_id` is
    // null for an assignment that is not scoped to a department — which is
    // most of them. Prisma refuses null inside a compound-key `where`, because
    // SQL NULL never equals NULL and the underlying index would not match
    // anyway. So this endpoint threw on every call: nobody could be assigned
    // to a role from the console at all.
    const existing = await this.prisma.userRole.findFirst({
      where: {
        user_id: userId,
        role_id: roleId,
        org_unit_id: orgUnitId,
        department_id: null,
      },
    });

    const assignment = existing
      ? await this.prisma.userRole.update({
          where: { id: existing.id },
          data: { is_primary: isPrimary, granted_by: actorId },
        })
      : await this.prisma.userRole.create({
          data: {
            user_id: userId,
            role_id: roleId,
            org_unit_id: orgUnitId,
            // The branch owns the tenant — already checked to be in this one
            // above. A database trigger refuses the row if they disagree.
            tenant_id: orgUnit.tenant_id,
            is_primary: isPrimary,
            granted_by: actorId,
          },
        });

    await this.audit.log({
      tenantId,
      orgUnitId,
      userId: actorId,
      module: MODULE,
      entityType: 'user_role',
      entityId: assignment.id.toString(),
      action: 'role_assigned',
      afterValue: {
        target_user_id: userId,
        role: role.name,
        org_unit_id: orgUnitId,
        is_primary: isPrimary,
      },
    });

    this.cache?.invalidateTenant(tenantId);
    return assignment;
  }

  async revokeRole(tenantId: string, assignmentId: number, actorId: number) {
    const assignment = await this.prisma.userRole.findUnique({
      where: { id: assignmentId },
      include: { role: true, user: { select: { tenant_id: true } } },
    });
    if (!assignment) throw new NotFoundException('Assignment not found');
    if (assignment.user?.tenant_id !== tenantId) {
      throw new ForbiddenException('That assignment belongs to another tenant');
    }

    await this.prisma.userRole.delete({ where: { id: assignmentId } });

    await this.audit.log({
      tenantId,
      userId: actorId,
      module: MODULE,
      entityType: 'user_role',
      entityId: assignmentId.toString(),
      action: 'role_revoked',
      beforeValue: {
        target_user_id: assignment.user_id,
        role: assignment.role.name,
      },
    });

    this.cache?.invalidateTenant(tenantId);
    return { success: true };
  }

  /** Headline counters for the console. */
  async summary(tenantId: string) {
    const [roles, screens, assignments, unassigned, pendingPassword] =
      await Promise.all([
        this.prisma.role.count({
          where: {
            tenant_id: { in: [tenantId, '__system__'] },
            is_active: true,
          },
        }),
        this.prisma.appScreen.count({ where: { is_active: true } }),
        this.prisma.userRole.count(),
        this.prisma.user.count({
          where: {
            tenant_id: tenantId,
            is_active: true,
            user_roles: { none: {} },
          },
        }),
        this.prisma.user.count({
          where: { tenant_id: tenantId, must_change_password: true },
        }),
      ]);

    return {
      roles,
      screens,
      assignments,
      // A user with no role sees an empty sidebar and cannot work — worth
      // surfacing rather than leaving to be discovered by the user themselves.
      users_without_role: unassigned,
      users_pending_password_change: pendingPassword,
    };
  }
}
