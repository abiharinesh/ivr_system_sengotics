import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Which modules are actually available to a branch.
 *
 * Access to a screen is the intersection of three independent decisions, and
 * until now only the third was consulted when building the sidebar:
 *
 *   1. the tenant's plan   — what this client bought      (TenantFeatureConfig)
 *   2. the branch's config — what this office switched on  (BranchFeatureConfig)
 *   3. the role's grant    — what this designation may see (RoleScreenAccess)
 *
 * The tables for 1 and 2 shipped and were read by `FeatureGuard` on two
 * controllers out of roughly twenty; nothing consulted them when deciding what
 * to render. A branch with solid waste switched off still showed the menu
 * entry, and clicking it produced an empty screen or a 403 — the toggle in the
 * super admin console looked broken because for the sidebar it was.
 *
 * The plan is a ceiling, not an override: a module the client has not licensed
 * cannot be switched on locally by a branch. Both must agree.
 */
@Injectable()
export class FeatureAccessService {
  private readonly logger = new Logger(FeatureAccessService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Module names that are not gated by provisioning at all.
   *
   * `core` is the product's own furniture — the dashboard, search, settings,
   * the role console. Gating it would let a branch configure itself into a
   * state with no way back out.
   */
  private static readonly ALWAYS_ON = new Set(['core']);

  /**
   * Resolve the modules enabled for a branch.
   *
   * Returns `null` when provisioning cannot be determined — no branch, or the
   * config tables are unreadable. Callers treat null as "do not filter": a
   * database hiccup must not empty somebody's menu, which is a far worse
   * failure than briefly showing a module they cannot use. The API guards
   * still refuse the underlying calls either way.
   */
  async enabledModulesFor(orgUnitId: number | null): Promise<Set<string> | null> {
    if (orgUnitId == null) return null;

    const org = await this.prisma.orgUnit
      .findUnique({
        where: { id: orgUnitId },
        select: { tenant_id: true },
      })
      .catch(() => null);
    if (!org) return null;

    const [branch, tenant] = await Promise.all([
      this.prisma.branchFeatureConfig
        .findUnique({ where: { org_unit_id: orgUnitId } })
        .catch(() => null),
      this.prisma.tenantFeatureConfig
        .findUnique({ where: { tenant_id: org.tenant_id } })
        .catch(() => null),
    ]);

    // Neither configured: this deployment does not use provisioning yet.
    // Filtering on absent rows would blank every menu in the product.
    if (!branch && !tenant) return null;

    const enabled = new Set<string>();
    const columns = new Set<string>([
      ...Object.keys(branch ?? {}),
      ...Object.keys(tenant ?? {}),
    ]);

    for (const column of columns) {
      if (!this.isFeatureColumn(column)) continue;

      // A missing row means "provisioned before this module existed", not
      // "refused" — so an absent config side is treated as permissive and the
      // other side decides. Only an explicit `false` closes the gate.
      const branchSaysNo = branch ? (branch as never)[column] === false : false;
      const tenantSaysNo = tenant ? (tenant as never)[column] === false : false;

      if (!branchSaysNo && !tenantSaysNo) enabled.add(column);
    }

    return enabled;
  }

  /**
   * Drop screens whose module is switched off.
   *
   * Screens are matched on `AppScreen.module`, which was named to line up with
   * the feature columns exactly so this join is possible. A module with no
   * matching column is left alone rather than hidden — an unrecognised name
   * means the catalogue is ahead of the config, and hiding the screen would
   * make every newly shipped module invisible until someone added a column.
   */
  filterScreens<T extends { key: string; module: string }>(
    screens: T[],
    enabled: Set<string> | null,
    knownFeatures: Set<string>,
  ): T[] {
    if (enabled == null) return screens;
    return screens.filter((s) => {
      if (FeatureAccessService.ALWAYS_ON.has(s.module)) return true;
      if (!knownFeatures.has(s.module)) return true;
      return enabled.has(s.module);
    });
  }

  /** Every module name the config tables can express. */
  async knownFeatures(): Promise<Set<string>> {
    // Derived from the row shape rather than a hand-kept list, so adding a
    // column to the schema is enough to make it gate.
    const row = await this.prisma.branchFeatureConfig
      .findFirst()
      .catch(() => null);
    if (!row) return new Set();
    return new Set(Object.keys(row).filter((c) => this.isFeatureColumn(c)));
  }

  /** Structural columns are not feature switches. */
  private isFeatureColumn(column: string): boolean {
    return !['id', 'org_unit_id', 'tenant_id', 'created_at', 'updated_at'].includes(
      column,
    );
  }
}
