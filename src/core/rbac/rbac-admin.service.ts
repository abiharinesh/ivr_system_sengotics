import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { BranchType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

const MODULE = 'rbac';

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

    return [...byModule.entries()].map(([module, items]) => ({ module, items }));
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
        _count: { select: { user_roles: true, permissions: true, screen_access: true } },
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
   * Copy a `__system__` template into a tenant so it can be customised.
   *
   * This is how a council departs from the default without affecting anyone
   * else. Grants are copied so the clone starts identical to what people
   * already have, rather than empty.
   */
  async cloneRole(tenantId: string, roleId: number, userId: number, newName?: string) {
    const source = await this.prisma.role.findUnique({
      where: { id: roleId },
      include: { permissions: true, screen_access: true },
    });
    if (!source) throw new NotFoundException(`Role #${roleId} not found`);

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
    const platform = screens.filter((s) => s.is_platform_only && wanted.has(s.key));
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
      const holders = await this.prisma.userRole.count({ where: { role_id: roleId } });
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
      this.prisma.user.findFirst({ where: { id: userId, tenant_id: tenantId } }),
      this.prisma.role.findFirst({
        where: { id: roleId, tenant_id: { in: [tenantId, '__system__'] } },
      }),
      this.prisma.orgUnit.findFirst({ where: { id: orgUnitId, tenant_id: tenantId } }),
    ]);

    if (!user) throw new NotFoundException(`User #${userId} not found in your tenant`);
    if (!role) throw new NotFoundException(`Role #${roleId} not available to your tenant`);
    if (!orgUnit) throw new ForbiddenException(`Branch #${orgUnitId} is not in your tenant`);

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

    const assignment = await this.prisma.userRole.upsert({
      where: {
        user_id_role_id_org_unit_id_department_id: {
          user_id: userId,
          role_id: roleId,
          org_unit_id: orgUnitId,
          department_id: null as unknown as number,
        },
      },
      update: { is_primary: isPrimary, granted_by: actorId },
      create: {
        user_id: userId,
        role_id: roleId,
        org_unit_id: orgUnitId,
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

    return { success: true };
  }

  /** Headline counters for the console. */
  async summary(tenantId: string) {
    const [roles, screens, assignments, unassigned, pendingPassword] =
      await Promise.all([
        this.prisma.role.count({
          where: { tenant_id: { in: [tenantId, '__system__'] }, is_active: true },
        }),
        this.prisma.appScreen.count({ where: { is_active: true } }),
        this.prisma.userRole.count(),
        this.prisma.user.count({
          where: { tenant_id: tenantId, is_active: true, user_roles: { none: {} } },
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
