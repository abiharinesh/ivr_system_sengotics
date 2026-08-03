import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Read-only analytics behind the role console's insight views.
 *
 * The console's editing panes answer "what does this role have?". This service
 * answers the questions an administrator actually has to act on and which no
 * per-role form can show: which screens nobody can reach, which roles are
 * indistinguishable from each other, where in the district access is thin, and
 * who is stuck without a way in.
 *
 * Everything is derived from five bulk reads and aggregated in memory. Doing
 * it per-role would be dozens of round trips for a screen that is opened often
 * and refreshed on every grant change.
 */
@Injectable()
export class RbacAnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(tenantId: string) {
    const tenants = [tenantId, '__system__'];

    const [roles, screens, permissions, assignments, orgUnits, users, audit] =
      await Promise.all([
        this.prisma.role.findMany({
          where: { tenant_id: { in: tenants } },
          include: {
            screen_access: { select: { screen_id: true, can_view: true } },
            permissions: { select: { permission_id: true } },
          },
          orderBy: [{ hierarchy_level: 'asc' }, { display_name: 'asc' }],
        }),
        this.prisma.appScreen.findMany({
          where: { is_active: true },
          orderBy: [{ group_key: 'asc' }, { sort_order: 'asc' }],
        }),
        this.prisma.permission.findMany({
          select: { id: true, code: true, module: true, action: true },
        }),
        this.prisma.userRole.findMany({
          select: {
            id: true,
            user_id: true,
            role_id: true,
            org_unit_id: true,
            is_primary: true,
            created_at: true,
          },
        }),
        this.prisma.orgUnit.findMany({
          where: { tenant_id: tenantId, is_deleted: false },
          select: {
            id: true,
            name: true,
            branch_type: true,
            branch_status: true,
            district: true,
            center_lat: true,
            center_lng: true,
            ward_count: true,
          },
          orderBy: { id: 'asc' },
        }),
        this.prisma.user.findMany({
          where: { tenant_id: tenantId },
          select: {
            id: true,
            email: true,
            is_active: true,
            last_login_at: true,
            must_change_password: true,
            user_type: true,
            primary_org_unit_id: true,
          },
        }),
        this.prisma.auditLog.findMany({
          where: { tenant_id: tenantId, module: 'rbac' },
          orderBy: { created_at: 'desc' },
          take: 400,
          select: {
            id: true,
            action: true,
            entity_type: true,
            entity_id: true,
            user_id: true,
            after_value: true,
            created_at: true,
          },
        }),
      ]);

    const screenById = new Map(screens.map((s) => [s.id, s]));
    const permById = new Map(permissions.map((p) => [p.id, p]));
    const roleById = new Map(roles.map((r) => [r.id, r]));
    const orgById = new Map(orgUnits.map((o) => [o.id, o]));
    const userById = new Map(users.map((u) => [u.id, u]));

    /** Screens a role can actually see, resolved through inheritance. */
    const grantedScreens = new Map<number, Set<number>>();
    const resolve = (roleId: number, depth = 0): Set<number> => {
      const cached = grantedScreens.get(roleId);
      if (cached) return cached;
      const role = roleById.get(roleId);
      if (!role || depth > 10) return new Set();

      const own = new Set(
        role.screen_access.filter((a) => a.can_view).map((a) => a.screen_id),
      );
      // A super admin reaches everything by definition, not by grant rows.
      if (role.is_super_admin) {
        for (const s of screens) own.add(s.id);
      }
      if (role.inherits_from_role_id) {
        for (const id of resolve(role.inherits_from_role_id, depth + 1)) own.add(id);
      }
      grantedScreens.set(roleId, own);
      return own;
    };
    for (const r of roles) resolve(r.id);

    const grantedPerms = new Map<number, Set<number>>();
    const resolvePerms = (roleId: number, depth = 0): Set<number> => {
      const cached = grantedPerms.get(roleId);
      if (cached) return cached;
      const role = roleById.get(roleId);
      if (!role || depth > 10) return new Set();
      const own = new Set(role.permissions.map((p) => p.permission_id));
      if (role.is_super_admin) for (const p of permissions) own.add(p.id);
      if (role.inherits_from_role_id) {
        for (const id of resolvePerms(role.inherits_from_role_id, depth + 1)) own.add(id);
      }
      grantedPerms.set(roleId, own);
      return own;
    };
    for (const r of roles) resolvePerms(r.id);

    // ── Membership ──────────────────────────────────────────────────────────
    const usersByRole = new Map<number, Set<number>>();
    const rolesByOrg = new Map<number, Set<number>>();
    const usersByOrg = new Map<number, Set<number>>();
    const assignmentsByOrg = new Map<number, number>();
    for (const a of assignments) {
      if (!usersByRole.has(a.role_id)) usersByRole.set(a.role_id, new Set());
      usersByRole.get(a.role_id)!.add(a.user_id);
      if (!rolesByOrg.has(a.org_unit_id)) rolesByOrg.set(a.org_unit_id, new Set());
      rolesByOrg.get(a.org_unit_id)!.add(a.role_id);
      if (!usersByOrg.has(a.org_unit_id)) usersByOrg.set(a.org_unit_id, new Set());
      usersByOrg.get(a.org_unit_id)!.add(a.user_id);
      assignmentsByOrg.set(a.org_unit_id, (assignmentsByOrg.get(a.org_unit_id) ?? 0) + 1);
    }

    // ── Coverage matrix: roles × sidebar groups ─────────────────────────────
    const groupKeys = [...new Set(screens.map((s) => s.group_key))];
    const groupTotals = new Map<string, number>();
    for (const s of screens) {
      groupTotals.set(s.group_key, (groupTotals.get(s.group_key) ?? 0) + 1);
    }

    const activeRoles = roles.filter((r) => r.is_active);
    const matrix = activeRoles.map((role) => {
      const granted = grantedScreens.get(role.id) ?? new Set();
      const perGroup = new Map<string, number>();
      for (const id of granted) {
        const s = screenById.get(id);
        if (!s) continue;
        perGroup.set(s.group_key, (perGroup.get(s.group_key) ?? 0) + 1);
      }
      return {
        role_id: role.id,
        name: role.name,
        display_name: role.display_name,
        hierarchy_level: role.hierarchy_level,
        department: role.department,
        is_super_admin: role.is_super_admin,
        is_editable: role.tenant_id !== '__system__',
        user_count: usersByRole.get(role.id)?.size ?? 0,
        screen_count: granted.size,
        permission_count: grantedPerms.get(role.id)?.size ?? 0,
        cells: groupKeys.map((g) => ({
          group_key: g,
          granted: perGroup.get(g) ?? 0,
          total: groupTotals.get(g) ?? 0,
        })),
      };
    });

    // ── Screen reach: who can actually get to each destination ──────────────
    const screenReach = screens.map((s) => {
      const holders = activeRoles.filter((r) => grantedScreens.get(r.id)?.has(s.id));
      const reachers = new Set<number>();
      for (const r of holders) {
        for (const u of usersByRole.get(r.id) ?? []) reachers.add(u);
      }
      return {
        screen_id: s.id,
        key: s.key,
        label: s.label_en,
        group_key: s.group_key,
        module: s.module,
        is_platform_only: s.is_platform_only,
        role_count: holders.length,
        user_count: reachers.size,
        role_names: holders.slice(0, 8).map((r) => r.display_name),
      };
    });

    // ── Permission distribution by module ───────────────────────────────────
    const moduleStats = new Map<
      string,
      { permission_count: number; grant_count: number; roles: Set<number> }
    >();
    for (const p of permissions) {
      if (!moduleStats.has(p.module)) {
        moduleStats.set(p.module, {
          permission_count: 0,
          grant_count: 0,
          roles: new Set(),
        });
      }
      moduleStats.get(p.module)!.permission_count++;
    }
    for (const role of activeRoles) {
      for (const pid of grantedPerms.get(role.id) ?? []) {
        const p = permById.get(pid);
        if (!p) continue;
        const m = moduleStats.get(p.module);
        if (!m) continue;
        m.grant_count++;
        m.roles.add(role.id);
      }
    }
    const permissionDistribution = [...moduleStats.entries()]
      .map(([module, v]) => ({
        module,
        permission_count: v.permission_count,
        grant_count: v.grant_count,
        role_count: v.roles.size,
      }))
      .sort((a, b) => b.grant_count - a.grant_count);

    // ── Hierarchy: the chain of command, level by level ─────────────────────
    // Levels follow the seeded roster: 0 is the platform operator, 1 the head
    // of the body, and it descends to the people outside the organisation.
    const LEVEL_LABEL: Record<number, string> = {
      0: 'Platform',
      1: 'Head of body',
      2: 'Senior officer',
      3: 'Officer',
      4: 'Supervisor',
      5: 'Inspector',
      6: 'Clerical',
      7: 'Field staff',
      8: 'Contractor',
      9: 'External',
      10: 'Citizen',
    };
    const levels = [...new Set(activeRoles.map((r) => r.hierarchy_level))].sort(
      (a, b) => a - b,
    );
    const hierarchy = levels.map((level) => {
      const at = activeRoles.filter((r) => r.hierarchy_level === level);
      const holders = new Set<number>();
      for (const r of at) for (const u of usersByRole.get(r.id) ?? []) holders.add(u);
      return {
        level,
        label: LEVEL_LABEL[level] ?? `Level ${level}`,
        role_count: at.length,
        user_count: holders.size,
        avg_screens: at.length
          ? Math.round(
              at.reduce((n, r) => n + (grantedScreens.get(r.id)?.size ?? 0), 0) /
                at.length,
            )
          : 0,
        roles: at.map((r) => ({
          role_id: r.id,
          display_name: r.display_name,
          user_count: usersByRole.get(r.id)?.size ?? 0,
          screen_count: grantedScreens.get(r.id)?.size ?? 0,
        })),
      };
    });

    // ── Geographic deployment ───────────────────────────────────────────────
    const branchMap = orgUnits.map((o) => {
      const roleIds = rolesByOrg.get(o.id) ?? new Set();
      const holders = usersByOrg.get(o.id) ?? new Set();
      // Screens reachable by *someone* at this branch — thin coverage here is
      // a branch whose staff literally cannot open most of the product.
      const reachable = new Set<number>();
      for (const rid of roleIds) {
        for (const sid of grantedScreens.get(rid) ?? []) reachable.add(sid);
      }
      const nonPlatform = screens.filter((s) => !s.is_platform_only).length;
      const reachableNonPlatform = [...reachable].filter(
        (id) => !screenById.get(id)?.is_platform_only,
      ).length;
      return {
        org_unit_id: o.id,
        name: o.name,
        branch_type: o.branch_type,
        branch_status: o.branch_status,
        district: o.district,
        lat: o.center_lat,
        lng: o.center_lng,
        ward_count: o.ward_count,
        role_count: roleIds.size,
        user_count: holders.size,
        assignment_count: assignmentsByOrg.get(o.id) ?? 0,
        screen_reach: reachableNonPlatform,
        screen_total: nonPlatform,
        coverage_pct: nonPlatform
          ? Math.round((reachableNonPlatform / nonPlatform) * 100)
          : 0,
        top_roles: [...roleIds]
          .map((id) => roleById.get(id))
          .filter((r): r is NonNullable<typeof r> => r != null)
          .sort((a, b) => a.hierarchy_level - b.hierarchy_level)
          .slice(0, 5)
          .map((r) => r.display_name),
      };
    });

    // ── Near-duplicate roles ────────────────────────────────────────────────
    //
    // Two roles granting almost the same screens are a maintenance trap: an
    // access change made to one and not the other drifts silently.
    const overlaps: Array<{
      a_id: number;
      a_name: string;
      b_id: number;
      b_name: string;
      shared: number;
      only_a: number;
      only_b: number;
      similarity: number;
    }> = [];
    const comparable = activeRoles.filter(
      (r) => !r.is_super_admin && (grantedScreens.get(r.id)?.size ?? 0) > 0,
    );
    for (let i = 0; i < comparable.length; i++) {
      for (let j = i + 1; j < comparable.length; j++) {
        const a = grantedScreens.get(comparable[i].id)!;
        const b = grantedScreens.get(comparable[j].id)!;
        let shared = 0;
        for (const id of a) if (b.has(id)) shared++;
        const union = a.size + b.size - shared;
        const similarity = union ? shared / union : 0;
        if (similarity >= 0.6) {
          overlaps.push({
            a_id: comparable[i].id,
            a_name: comparable[i].display_name,
            b_id: comparable[j].id,
            b_name: comparable[j].display_name,
            shared,
            only_a: a.size - shared,
            only_b: b.size - shared,
            similarity: Math.round(similarity * 100),
          });
        }
      }
    }
    overlaps.sort((x, y) => y.similarity - x.similarity);

    // ── Findings that need someone to act ───────────────────────────────────
    const risks: Array<{
      severity: 'high' | 'medium' | 'low';
      code: string;
      title: string;
      detail: string;
      count: number;
    }> = [];

    const emptyMenuRoles = activeRoles.filter(
      (r) => (usersByRole.get(r.id)?.size ?? 0) > 0 && (grantedScreens.get(r.id)?.size ?? 0) === 0,
    );
    if (emptyMenuRoles.length) {
      risks.push({
        severity: 'high',
        code: 'role_no_screens',
        title: 'Roles that sign in to an empty menu',
        detail: emptyMenuRoles.map((r) => r.display_name).join(', '),
        count: emptyMenuRoles.length,
      });
    }

    const orphanScreens = screenReach.filter(
      (s) => s.role_count === 0 && !s.is_platform_only,
    );
    if (orphanScreens.length) {
      risks.push({
        severity: 'high',
        code: 'screen_unreachable',
        title: 'Screens no role can open',
        detail: orphanScreens.map((s) => s.label).join(', '),
        count: orphanScreens.length,
      });
    }

    const noRoleUsers = users.filter(
      (u) => u.is_active && !assignments.some((a) => a.user_id === u.id),
    );
    if (noRoleUsers.length) {
      risks.push({
        severity: 'high',
        code: 'user_no_role',
        title: 'Active accounts with no role',
        detail: `${noRoleUsers.length} account(s) can sign in but see nothing.`,
        count: noRoleUsers.length,
      });
    }

    const unusedRoles = activeRoles.filter(
      (r) => (usersByRole.get(r.id)?.size ?? 0) === 0 && r.tenant_id !== '__system__',
    );
    if (unusedRoles.length) {
      risks.push({
        severity: 'low',
        code: 'role_unused',
        title: 'Roles nobody holds',
        detail: unusedRoles.map((r) => r.display_name).join(', '),
        count: unusedRoles.length,
      });
    }

    const overPrivileged = activeRoles.filter(
      (r) =>
        !r.is_super_admin &&
        permissions.length > 0 &&
        (grantedPerms.get(r.id)?.size ?? 0) / permissions.length >= 0.8,
    );
    if (overPrivileged.length) {
      risks.push({
        severity: 'medium',
        code: 'role_over_privileged',
        title: 'Roles holding almost every permission',
        detail: overPrivileged
          .map(
            (r) =>
              `${r.display_name} (${Math.round(
                ((grantedPerms.get(r.id)?.size ?? 0) / permissions.length) * 100,
              )}%)`,
          )
          .join(', '),
        count: overPrivileged.length,
      });
    }

    const pendingPassword = users.filter((u) => u.must_change_password && u.is_active);
    if (pendingPassword.length) {
      risks.push({
        severity: 'medium',
        code: 'password_not_set',
        title: 'Issued passwords never changed',
        detail: `${pendingPassword.length} account(s) still on the password they were issued.`,
        count: pendingPassword.length,
      });
    }

    const neverLoggedIn = users.filter(
      (u) => u.is_active && u.last_login_at == null && u.user_type === 'employee',
    );
    if (neverLoggedIn.length) {
      risks.push({
        severity: 'low',
        code: 'never_signed_in',
        title: 'Staff accounts never used',
        detail: `${neverLoggedIn.length} account(s) have never signed in.`,
        count: neverLoggedIn.length,
      });
    }

    if (overlaps.length) {
      risks.push({
        severity: 'low',
        code: 'role_near_duplicate',
        title: 'Near-identical roles',
        detail: overlaps
          .slice(0, 4)
          .map((o) => `${o.a_name} ≈ ${o.b_name} (${o.similarity}%)`)
          .join(', '),
        count: overlaps.length,
      });
    }

    const SEVERITY_ORDER = { high: 0, medium: 1, low: 2 };
    risks.sort((a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity]);

    // ── Change activity ─────────────────────────────────────────────────────
    const DAYS = 30;
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const buckets = new Map<string, number>();
    for (let d = DAYS - 1; d >= 0; d--) {
      const day = new Date(today.getTime() - d * 86400000);
      buckets.set(day.toISOString().slice(0, 10), 0);
    }
    const actionCounts = new Map<string, number>();
    for (const e of audit) {
      const key = e.created_at.toISOString().slice(0, 10);
      if (buckets.has(key)) buckets.set(key, buckets.get(key)! + 1);
      actionCounts.set(e.action, (actionCounts.get(e.action) ?? 0) + 1);
    }

    const activity = {
      days: [...buckets.entries()].map(([date, count]) => ({ date, count })),
      by_action: [...actionCounts.entries()]
        .map(([action, count]) => ({ action, count }))
        .sort((a, b) => b.count - a.count),
      recent: audit.slice(0, 25).map((e) => ({
        id: e.id.toString(),
        action: e.action,
        entity_type: e.entity_type,
        entity_id: e.entity_id,
        actor: userById.get(e.user_id ?? -1)?.email ?? 'system',
        created_at: e.created_at,
      })),
    };

    // ── Headline totals ─────────────────────────────────────────────────────
    const nonPlatformScreens = screens.filter((s) => !s.is_platform_only);
    const reachableAnywhere = new Set<number>();
    for (const r of activeRoles) {
      for (const id of grantedScreens.get(r.id) ?? []) reachableAnywhere.add(id);
    }

    return {
      generated_at: new Date().toISOString(),
      totals: {
        roles: activeRoles.length,
        editable_roles: activeRoles.filter((r) => r.tenant_id !== '__system__').length,
        inactive_roles: roles.length - activeRoles.length,
        screens: screens.length,
        permissions: permissions.length,
        assignments: assignments.length,
        users: users.length,
        active_users: users.filter((u) => u.is_active).length,
        branches: orgUnits.length,
        avg_screens_per_role: activeRoles.length
          ? Math.round(
              activeRoles.reduce(
                (n, r) => n + (grantedScreens.get(r.id)?.size ?? 0),
                0,
              ) / activeRoles.length,
            )
          : 0,
        screen_coverage_pct: nonPlatformScreens.length
          ? Math.round(
              ([...reachableAnywhere].filter(
                (id) => !screenById.get(id)?.is_platform_only,
              ).length /
                nonPlatformScreens.length) *
                100,
            )
          : 0,
        users_without_role: noRoleUsers.length,
        users_pending_password_change: pendingPassword.length,
      },
      coverage: { group_keys: groupKeys, roles: matrix },
      screen_reach: screenReach,
      permission_distribution: permissionDistribution,
      hierarchy,
      branch_map: branchMap,
      role_overlaps: overlaps.slice(0, 12),
      risks,
      activity,
    };
  }
}
