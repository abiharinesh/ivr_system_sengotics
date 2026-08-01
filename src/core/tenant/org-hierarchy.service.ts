import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class OrgHierarchyService {
  constructor(private prisma: PrismaService) {}

  /**
   * Fetch all descendant branch IDs recursively for a given parent branch.
   */
  async getDescendantBranchIds(tenantId: string, parentId: number): Promise<number[]> {
    const results = await this.prisma.$queryRaw<{ id: number }[]>`
      WITH RECURSIVE org_unit_tree AS (
        SELECT id FROM org_units
        WHERE id = ${parentId} AND tenant_id = ${tenantId} AND is_deleted = false
        UNION ALL
        SELECT p.id FROM org_units p
        INNER JOIN org_unit_tree bt ON p.parent_org_unit_id = bt.id
        WHERE p.tenant_id = ${tenantId} AND p.is_deleted = false
      )
      SELECT id FROM org_unit_tree
    `;
    return results.map((r) => r.id);
  }

  /**
   * Fetch the full ancestral path up to the root branch.
   */
  async getAncestorBranchIds(tenantId: string, childId: number): Promise<number[]> {
    const results = await this.prisma.$queryRaw<{ id: number }[]>`
      WITH RECURSIVE org_unit_path AS (
        SELECT id, parent_org_unit_id FROM org_units
        WHERE id = ${childId} AND tenant_id = ${tenantId} AND is_deleted = false
        UNION ALL
        SELECT p.id, p.parent_org_unit_id FROM org_units p
        INNER JOIN org_unit_path bp ON p.id = bp.parent_org_unit_id
        WHERE p.tenant_id = ${tenantId} AND p.is_deleted = false
      )
      SELECT id FROM org_unit_path
    `;
    return results.map((r) => r.id);
  }

  /**
   * Check if user (with access scope) can access a target org unit.
   */
  async canAccessOrgUnit(
    tenantId: string,
    userBranchId: number,
    accessScope: string,
    targetBranchId: number,
  ): Promise<boolean> {
    if (accessScope === 'all_org_units') return true;
    if (accessScope === 'own_org_unit') return userBranchId === targetBranchId;

    if (accessScope === 'child_org_units') {
      const children = await this.getDescendantBranchIds(tenantId, userBranchId);
      return children.includes(targetBranchId);
    }

    return false;
  }
}
