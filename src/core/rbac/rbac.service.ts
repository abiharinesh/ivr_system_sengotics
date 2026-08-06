import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { FeatureAccessService } from './feature-access.service';

/**
 * Everything the client needs to draw one sidebar entry.
 *
 * The Dart side kept its own copy of this — key, route, label, icon and group
 * for all 34 screens — which meant shipping a module took an edit in two
 * places and the two could disagree with nothing to catch it. `AppScreen` has
 * carried these columns since it was written; this is what finally sends them.
 */
export interface NavScreen {
  key: string;
  route: string;
  group_key: string;
  label_en: string;
  label_ta: string | null;
  /** Material icon name, resolved to an `IconData` on the client. */
  icon: string;
  sort_order: number;
  module: string;
}

export interface Entitlements {
  /** Permission codes, e.g. `trade_licences.read`. */
  permissions: string[];
  /** Screen keys the sidebar may render, e.g. `trade_licences`. */
  screens: string[];
  /**
   * The same screens with everything needed to render them, in catalogue
   * order. `screens` stays because the JWT and the guards want keys alone and
   * a token should not grow every time a module ships.
   */
  nav: NavScreen[];
  roles: { id: number; name: string; display_name: string; is_super_admin: boolean }[];
  isSuperAdmin: boolean;
}

/** The columns that make up a {@link NavScreen}, for Prisma `select`. */
const NAV_FIELDS = {
  key: true,
  route: true,
  group_key: true,
  label_en: true,
  label_ta: true,
  icon: true,
  sort_order: true,
  module: true,
  is_active: true,
} as const;

/**
 * Catalogue order.
 *
 * `sort_order` is assigned from the screen's position in the seed's single
 * list, and groups are contiguous in that list — so ordering by it alone puts
 * both the groups and the items inside them where the catalogue intends. The
 * client groups by `group_key` in first-appearance order.
 *
 * Sorting by `group_key` instead would be alphabetical, which puts
 * ADMINISTRATION above OVERVIEW.
 */
function inCatalogueOrder(a: NavScreen, b: NavScreen): number {
  return a.sort_order - b.sort_order || a.key.localeCompare(b.key);
}

/**
 * Resolves what a user may do and see.
 *
 * One service answers both questions from the same walk of the role graph, so
 * the API guard and the sidebar can never disagree about a user's access —
 * which was the whole problem before: the guards read RBAC from the database
 * while the sidebar read a hardcoded map of role-name strings in Dart, and
 * changing a role in the admin console therefore changed nothing on screen.
 *
 * Role inheritance is followed transitively, with cycle protection: a role
 * chain that loops would otherwise hang the login request.
 */
@Injectable()
export class RbacService {
  private readonly logger = new Logger(RbacService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly features: FeatureAccessService,
  ) {}

  /**
   * Every role id reachable from the given roles, following
   * `inherits_from_role_id` upwards.
   */
  private async expandInheritance(roleIds: number[]): Promise<number[]> {
    const seen = new Set<number>(roleIds);
    let frontier = [...roleIds];

    // Bounded rather than `while (frontier.length)` so a mis-seeded cycle
    // costs a few queries instead of the request.
    for (let depth = 0; depth < 10 && frontier.length > 0; depth++) {
      const parents = await this.prisma.role.findMany({
        where: { id: { in: frontier }, inherits_from_role_id: { not: null } },
        select: { inherits_from_role_id: true },
      });
      frontier = parents
        .map((p) => p.inherits_from_role_id!)
        .filter((id) => !seen.has(id));
      frontier.forEach((id) => seen.add(id));
    }

    return [...seen];
  }

  /**
   * Resolve a user's full entitlements.
   *
   * A super admin is not given an expanded list of every code in the system —
   * it short-circuits, and the guards already bypass on `is_super_admin`. That
   * keeps the JWT small and means adding a permission never requires
   * re-issuing super admin tokens.
   */
  async entitlementsFor(userId: number): Promise<Entitlements> {
    type Assignment = {
      org_unit_id: number | null;
      is_primary: boolean;
      role: {
        id: number;
        name: string;
        display_name: string;
        is_super_admin: boolean;
        is_active: boolean;
      } | null;
    };

    const assignments: Assignment[] = await this.prisma.userRole
      .findMany({
        where: {
          user_id: userId,
          OR: [{ valid_until: null }, { valid_until: { gte: new Date() } }],
        },
        select: {
          org_unit_id: true,
          is_primary: true,
          role: {
            select: {
              id: true,
              name: true,
              display_name: true,
              is_super_admin: true,
              is_active: true,
            },
          },
        },
      })
      .catch(() => []);

    const roles = assignments
      .map((a) => a.role)
      .filter((r): r is NonNullable<typeof r> => r != null && r.is_active)
      .map((r) => ({
        id: r.id,
        name: r.name,
        display_name: r.display_name,
        is_super_admin: r.is_super_admin,
      }));

    const isSuperAdmin = roles.some((r) => r.is_super_admin);
    if (isSuperAdmin) {
      return { permissions: [], screens: [], nav: [], roles, isSuperAdmin: true };
    }

    if (roles.length === 0) {
      return { permissions: [], screens: [], nav: [], roles: [], isSuperAdmin: false };
    }

    const roleIds = await this.expandInheritance(roles.map((r) => r.id));

    // The branch the user actually works at decides which modules are
    // provisioned. Their primary assignment is their working context; without
    // one, any assignment will do.
    const orgUnitId =
      assignments.find((a) => a.is_primary)?.org_unit_id ??
      assignments[0]?.org_unit_id ??
      null;

    const [grants, access, enabledModules, knownFeatures] = await Promise.all([
      this.prisma.rolePermission.findMany({
        where: { role_id: { in: roleIds } },
        select: { permission: { select: { code: true } } },
      }),
      this.prisma.roleScreenAccess.findMany({
        where: { role_id: { in: roleIds }, can_view: true },
        select: { screen: { select: NAV_FIELDS } },
      }),
      this.features.enabledModulesFor(orgUnitId),
      this.features.knownFeatures(),
    ]);

    // Granted ∩ provisioned. A role may be granted a screen the branch has not
    // licensed — that is not a mistake in the grant, it is the same role
    // definition being reused across branches that differ.
    const granted = access
      .filter((a) => a.screen.is_active)
      .map((a) => a.screen);
    const visible = this.features.filterScreens(
      granted,
      enabledModules,
      knownFeatures,
    );

    // Two roles can grant the same screen; the sidebar must show it once.
    const byKey = new Map<string, NavScreen>();
    for (const s of visible) {
      const { is_active, ...nav } = s;
      void is_active;
      byKey.set(nav.key, nav);
    }
    const nav = [...byKey.values()].sort(inCatalogueOrder);

    return {
      permissions: [...new Set(grants.map((g) => g.permission.code))].sort(),
      screens: nav.map((s) => s.key).sort(),
      nav,
      roles,
      isSuperAdmin: false,
    };
  }

  /**
   * The screens a *super admin* sees.
   *
   * Resolved from the registry rather than from grants, because a platform
   * operator's menu should follow the catalogue automatically as modules ship,
   * without anyone remembering to tick a box.
   */
  async platformScreens(): Promise<string[]> {
    return (await this.platformNav()).map((s) => s.key);
  }

  /**
   * The same catalogue a super admin sees, with everything needed to render
   * it. Separate from {@link platformScreens} because the JWT wants keys and
   * only the sidebar wants the rest.
   */
  async platformNav(): Promise<NavScreen[]> {
    // Non-throwing for the same reason the rest of this service is: a database
    // that has not had the RBAC migration applied must not make login fail.
    const screens: NavScreen[] = await this.prisma.appScreen
      .findMany({
        where: { is_active: true },
        select: { ...NAV_FIELDS, is_active: false },
      })
      .catch(() => [] as NavScreen[]);
    return [...screens].sort(inCatalogueOrder);
  }
}
