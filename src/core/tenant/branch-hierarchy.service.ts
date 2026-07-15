import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class BranchHierarchyService {
  constructor(private prisma: PrismaService) {}

  /**
   * Fetch all descendant branch IDs recursively for a given parent branch.
   */
  async getDescendantBranchIds(tenantId: string, parentId: number): Promise<number[]> {
    const results = await this.prisma.$queryRaw<{ id: number }[]>`
      WITH RECURSIVE branch_tree AS (
        SELECT id FROM panchayats 
        WHERE id = ${parentId} AND tenant_id = ${tenantId} AND is_deleted = false
        UNION ALL
        SELECT p.id FROM panchayats p
        INNER JOIN branch_tree bt ON p.parent_branch_id = bt.id
        WHERE p.tenant_id = ${tenantId} AND p.is_deleted = false
      )
      SELECT id FROM branch_tree
    `;
    return results.map((r) => r.id);
  }

  /**
   * Fetch the full ancestral path up to the root branch.
   */
  async getAncestorBranchIds(tenantId: string, childId: number): Promise<number[]> {
    const results = await this.prisma.$queryRaw<{ id: number }[]>`
      WITH RECURSIVE branch_path AS (
        SELECT id, parent_branch_id FROM panchayats
        WHERE id = ${childId} AND tenant_id = ${tenantId} AND is_deleted = false
        UNION ALL
        SELECT p.id, p.parent_branch_id FROM panchayats p
        INNER JOIN branch_path bp ON p.id = bp.parent_branch_id
        WHERE p.tenant_id = ${tenantId} AND p.is_deleted = false
      )
      SELECT id FROM branch_path
    `;
    return results.map((r) => r.id);
  }

  /**
   * Check if user (with access scope) can access a target branch.
   */
  async canAccessBranch(
    tenantId: string,
    userBranchId: number,
    accessScope: string,
    targetBranchId: number,
  ): Promise<boolean> {
    if (accessScope === 'all_branches') return true;
    if (accessScope === 'own_branch') return userBranchId === targetBranchId;

    if (accessScope === 'child_branches') {
      const children = await this.getDescendantBranchIds(tenantId, userBranchId);
      return children.includes(targetBranchId);
    }

    return false;
  }
}
