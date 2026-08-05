import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { BranchType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';

const MODULE = 'rbac';

/** The shelf templates live on. Holds no users and no assignments. */
export const SYSTEM_TENANT = '__system__';

export interface SyncOutcome {
  role_id: number;
  name: string;
  display_name: string;
  screens_added: string[];
  screens_removed: string[];
  permissions_added: string[];
  permissions_removed: string[];
}

export interface SyncReport {
  tenant_id: string;
  dry_run: boolean;
  /** Roles whose grants were brought back in line with their template. */
  updated: SyncOutcome[];
  /** Roles the tenant has edited. Left exactly as they are. */
  skipped_customised: Array<{ role_id: number; name: string; customised_at: Date }>;
  /** Roles that already matched. */
  unchanged: number;
  /** Roles with no template — a tenant's own inventions. Never touched. */
  untemplated: number;
}

/**
 * Just the three delegates {@link RoleTemplateService.applyTemplates} touches.
 *
 * Structural rather than `PrismaService | Prisma.TransactionClient`, because a
 * transaction client is a narrowed `Omit<PrismaClient, …>` that no union of
 * the two names quite matches — and naming the delegates states what this may
 * reach for, which is the useful half of the constraint anyway.
 */
type Db = Pick<
  PrismaService,
  'role' | 'roleScreenAccess' | 'rolePermission' | 'appScreen'
>;

/**
 * Keeps every client's roles descended from one shipped catalogue.
 *
 * Each tenant owns real copies of the roles it uses rather than sharing rows
 * with anyone else — an authorization decision must never depend on a row a
 * different council can edit, and a council must be able to change its own
 * roles without changing everybody's. But unrelated copies drift: improving
 * the shipped roster meant repeating one edit per client by hand, which stops
 * being possible somewhere around the third client and silently leaves the
 * rest behind.
 *
 * `Role.template_id` is the link that makes both true at once. Copies stay
 * local and editable; the template stays the single place to improve the
 * default. {@link syncTenant} carries an improvement across, and refuses to
 * touch any role the tenant has made their own — reverting a deliberate local
 * decision to ship a default is worse than leaving that council behind, and
 * unlike being left behind it is invisible until someone loses access.
 */
@Injectable()
export class RoleTemplateService {
  private readonly logger = new Logger(RoleTemplateService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  // ── Reads ─────────────────────────────────────────────────────────────────

  /**
   * The catalogue, optionally narrowed to one kind of body.
   *
   * A village panchayat has no Municipal Commissioner, and offering one is how
   * a client ends up with roles nobody can explain.
   */
  async listTemplates(branchType?: BranchType) {
    const templates = await this.prisma.role.findMany({
      where: { tenant_id: SYSTEM_TENANT, is_active: true },
      include: {
        _count: { select: { screen_access: true, permissions: true, instances: true } },
      },
      orderBy: [{ hierarchy_level: 'asc' }, { display_name: 'asc' }],
    });

    return templates
      .filter(
        (t) =>
          !branchType ||
          t.applicable_branch_types.length === 0 ||
          t.applicable_branch_types.includes(branchType),
      )
      .map((t) => ({
        id: t.id,
        name: t.name,
        display_name: t.display_name,
        display_name_ta: t.display_name_ta,
        department: t.department,
        hierarchy_level: t.hierarchy_level,
        applicable_branch_types: t.applicable_branch_types,
        screen_count: t._count.screen_access,
        permission_count: t._count.permissions,
        /** How many tenants are provisioned from this template. */
        in_use_by: t._count.instances,
      }));
  }

  /** How one tenant's copy differs from the template it came from. */
  async diff(tenantId: string, roleId: number) {
    const role = await this.prisma.role.findFirst({
      where: { id: roleId, tenant_id: tenantId },
      include: {
        screen_access: { include: { screen: { select: { key: true } } } },
        permissions: { include: { permission: { select: { code: true } } } },
      },
    });
    if (!role) throw new NotFoundException(`Role #${roleId} not found`);
    if (role.template_id == null) {
      return {
        role_id: role.id,
        name: role.name,
        template: null,
        customised_at: role.customised_at,
        ...emptyDelta(),
      };
    }

    const template = await this.prisma.role.findUnique({
      where: { id: role.template_id },
      include: {
        screen_access: { include: { screen: { select: { key: true } } } },
        permissions: { include: { permission: { select: { code: true } } } },
      },
    });
    if (!template) throw new NotFoundException('That role\'s template is missing');

    return {
      role_id: role.id,
      name: role.name,
      template: { id: template.id, name: template.name },
      customised_at: role.customised_at,
      ...delta(
        grantsOf(template),
        grantsOf(role as unknown as GrantBearing),
      ),
    };
  }

  /** What {@link syncTenant} would do, without doing it. */
  async preview(tenantId: string): Promise<SyncReport> {
    return this.syncTenant(tenantId, null, { dryRun: true });
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /**
   * Give a tenant its own copy of every template that suits its body type.
   *
   * Existing roles are left completely alone, including their grants: this
   * runs during onboarding but is safe to run again, and a second run must not
   * undo whatever the client has done since the first.
   */
  async applyTemplates(
    tenantId: string,
    branchType: BranchType | null,
    db: Db = this.prisma,
  ): Promise<{ created: string[]; already_present: number }> {
    const templates = await db.role.findMany({
      where: {
        tenant_id: SYSTEM_TENANT,
        is_active: true,
        // Never provision a platform role into a client.
        //
        // `super_admin` is listed for every body type, because the platform
        // operator administers every body type. Copying it into each client
        // would hand that client its own role carrying `is_super_admin` — and
        // a council administrator, who can already assign roles within their
        // own tenant, could then grant it to themselves and step outside the
        // tenant boundary entirely. The escalation is available to anyone who
        // can reach the role console, which is the whole point of that screen.
        is_super_admin: false,
      },
      include: { screen_access: true, permissions: true },
    });

    // Belt and braces: platform screens administer the platform itself, not a
    // council's work, and `setRoleScreens` already refuses to grant one to a
    // branch role. Copying must obey the same rule, or provisioning becomes a
    // way around it.
    const platformScreens = new Set(
      (
        await db.appScreen.findMany({
          where: { is_platform_only: true },
          select: { id: true },
        })
      ).map((s) => s.id),
    );

    const applicable = templates.filter(
      (t) =>
        !branchType ||
        t.applicable_branch_types.length === 0 ||
        t.applicable_branch_types.includes(branchType),
    );

    const existing = await db.role.findMany({
      where: { tenant_id: tenantId },
      select: { name: true },
    });
    const held = new Set(existing.map((r) => r.name));

    const created: string[] = [];
    const screenRows: Array<{ role_id: number; screen_id: number; can_view: boolean }> = [];
    const permRows: Array<{ role_id: number; permission_id: number }> = [];

    for (const t of applicable) {
      if (held.has(t.name)) continue;

      const copy = await db.role.create({
        data: {
          tenant_id: tenantId,
          org_unit_id: null,
          name: t.name,
          display_name: t.display_name,
          display_name_ta: t.display_name_ta,
          department: t.department,
          hierarchy_level: t.hierarchy_level,
          is_super_admin: t.is_super_admin,
          can_approve: t.can_approve,
          is_system: t.is_system,
          is_active: true,
          applicable_branch_types: t.applicable_branch_types,
          template_id: t.id,
          // Untouched by this tenant, so a later sync may update it.
          customised_at: null,
        },
      });

      for (const s of t.screen_access) {
        if (s.can_view && !platformScreens.has(s.screen_id)) {
          screenRows.push({ role_id: copy.id, screen_id: s.screen_id, can_view: true });
        }
      }
      for (const p of t.permissions) {
        permRows.push({ role_id: copy.id, permission_id: p.permission_id });
      }
      created.push(t.name);
    }

    // Bulk, not per row: onboarding copies roughly 250 screen grants and 490
    // permission grants, and doing that one statement at a time inside the
    // provisioning transaction is how a transaction times out.
    if (screenRows.length) {
      await db.roleScreenAccess.createMany({ data: screenRows, skipDuplicates: true });
    }
    if (permRows.length) {
      await db.rolePermission.createMany({ data: permRows, skipDuplicates: true });
    }

    if (created.length) {
      this.logger.log(
        `Tenant ${tenantId}: provisioned ${created.length} roles from templates`,
      );
    }

    return { created, already_present: applicable.length - created.length };
  }

  /**
   * Carry template changes into a tenant's untouched copies.
   *
   * Only roles whose `customised_at` is still null are altered. A role the
   * council has edited is reported and skipped, so the operator can see who is
   * behind and decide what to do about it, rather than having the decision
   * made for them silently.
   */
  async syncTenant(
    tenantId: string,
    actorId: number | null,
    opts: { dryRun?: boolean; roleIds?: number[] } = {},
  ): Promise<SyncReport> {
    const dryRun = opts.dryRun ?? false;

    const roles = await this.prisma.role.findMany({
      where: {
        tenant_id: tenantId,
        ...(opts.roleIds?.length ? { id: { in: opts.roleIds } } : {}),
      },
      include: {
        screen_access: { include: { screen: { select: { key: true } } } },
        permissions: { include: { permission: { select: { code: true } } } },
      },
    });

    const templateIds = [
      ...new Set(roles.map((r) => r.template_id).filter((id): id is number => id != null)),
    ];
    const templates = await this.prisma.role.findMany({
      where: { id: { in: templateIds } },
      include: {
        screen_access: { include: { screen: { select: { key: true } } } },
        permissions: { include: { permission: { select: { code: true } } } },
      },
    });
    const byId = new Map(templates.map((t) => [t.id, t]));

    const report: SyncReport = {
      tenant_id: tenantId,
      dry_run: dryRun,
      updated: [],
      skipped_customised: [],
      unchanged: 0,
      untemplated: 0,
    };

    for (const role of roles) {
      if (role.template_id == null) {
        report.untemplated++;
        continue;
      }
      if (role.customised_at !== null) {
        report.skipped_customised.push({
          role_id: role.id,
          name: role.name,
          customised_at: role.customised_at,
        });
        continue;
      }

      const template = byId.get(role.template_id);
      if (!template) {
        report.untemplated++;
        continue;
      }

      const want = grantsOf(template);
      const have = grantsOf(role as unknown as GrantBearing);
      const d = delta(want, have);

      const changed =
        d.screens_added.length ||
        d.screens_removed.length ||
        d.permissions_added.length ||
        d.permissions_removed.length;

      if (!changed) {
        report.unchanged++;
        continue;
      }

      if (!dryRun) {
        await this.rewriteGrants(role.id, template.id);
      }

      report.updated.push({
        role_id: role.id,
        name: role.name,
        display_name: role.display_name,
        ...d,
      });
    }

    if (!dryRun && report.updated.length) {
      await this.audit.log({
        tenantId,
        userId: actorId ?? 0,
        module: MODULE,
        entityType: 'tenant',
        entityId: tenantId,
        action: 'roles_synced_from_templates',
        afterValue: {
          updated: report.updated.map((u) => u.name),
          skipped_customised: report.skipped_customised.map((s) => s.name),
        },
        changedFields: ['screen_access', 'permissions'],
      });

      this.logger.log(
        `Tenant ${tenantId}: synced ${report.updated.length} roles, ` +
          `skipped ${report.skipped_customised.length} customised`,
      );
    }

    return report;
  }

  /**
   * Make one role's grants match its template's exactly.
   *
   * Screens are flipped rather than deleted, matching how the console revokes
   * them, so the record of who granted a screen and when survives it being
   * switched off. `customised_at` deliberately stays null: the role still
   * matches its template afterwards, so it remains eligible for the next one.
   */
  private async rewriteGrants(roleId: number, templateId: number) {
    const template = await this.prisma.role.findUniqueOrThrow({
      where: { id: templateId },
      include: { screen_access: true, permissions: true },
    });

    const wantedScreens = new Set(
      template.screen_access.filter((s) => s.can_view).map((s) => s.screen_id),
    );

    await this.prisma.$transaction(async (tx) => {
      const current = await tx.roleScreenAccess.findMany({
        where: { role_id: roleId },
        select: { screen_id: true },
      });
      const currentIds = new Set(current.map((c) => c.screen_id));

      const toRevoke = [...currentIds].filter((id) => !wantedScreens.has(id));
      if (toRevoke.length) {
        await tx.roleScreenAccess.updateMany({
          where: { role_id: roleId, screen_id: { in: toRevoke } },
          data: { can_view: false },
        });
      }

      const toEnable = [...wantedScreens].filter((id) => currentIds.has(id));
      if (toEnable.length) {
        await tx.roleScreenAccess.updateMany({
          where: { role_id: roleId, screen_id: { in: toEnable } },
          data: { can_view: true },
        });
      }

      const toCreate = [...wantedScreens].filter((id) => !currentIds.has(id));
      if (toCreate.length) {
        await tx.roleScreenAccess.createMany({
          data: toCreate.map((screen_id) => ({ role_id: roleId, screen_id, can_view: true })),
          skipDuplicates: true,
        });
      }

      await tx.rolePermission.deleteMany({ where: { role_id: roleId } });
      if (template.permissions.length) {
        await tx.rolePermission.createMany({
          data: template.permissions.map((p) => ({
            role_id: roleId,
            permission_id: p.permission_id,
          })),
          skipDuplicates: true,
        });
      }
    });
  }
}

// ── Grant comparison ────────────────────────────────────────────────────────

interface GrantBearing {
  screen_access: Array<{ can_view: boolean; screen: { key: string } }>;
  permissions: Array<{ permission: { code: string } }>;
}

interface Grants {
  screens: Set<string>;
  permissions: Set<string>;
}

function grantsOf(role: GrantBearing): Grants {
  return {
    screens: new Set(
      role.screen_access.filter((s) => s.can_view).map((s) => s.screen.key),
    ),
    permissions: new Set(role.permissions.map((p) => p.permission.code)),
  };
}

function emptyDelta() {
  return {
    screens_added: [] as string[],
    screens_removed: [] as string[],
    permissions_added: [] as string[],
    permissions_removed: [] as string[],
  };
}

/** What would change to turn `have` into `want`. */
function delta(want: Grants, have: Grants) {
  return {
    screens_added: [...want.screens].filter((k) => !have.screens.has(k)).sort(),
    screens_removed: [...have.screens].filter((k) => !want.screens.has(k)).sort(),
    permissions_added: [...want.permissions]
      .filter((c) => !have.permissions.has(c))
      .sort(),
    permissions_removed: [...have.permissions]
      .filter((c) => !want.permissions.has(c))
      .sort(),
  };
}
