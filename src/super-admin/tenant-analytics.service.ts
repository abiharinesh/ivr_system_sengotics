import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Cross-tenant aggregates for the super admin dashboard — deliberately uses
 * the unscoped `PrismaService` directly (not `scopedToTenant()`), since the
 * entire point is visibility *across* every client, grouped by tenant.
 */
@Injectable()
export class TenantAnalyticsService {
  constructor(private prisma: PrismaService) {}

  async overview() {
    const [tenants, orgUnitsByTenant, usersByTenant, complaintsByTenant] = await Promise.all([
      this.prisma.tenant.findMany({
        orderBy: { name: 'asc' },
      }),
      this.prisma.orgUnit.groupBy({
        by: ['tenant_id'],
        _count: { _all: true },
        where: { is_deleted: false },
      }),
      this.prisma.user.groupBy({
        by: ['tenant_id'],
        _count: { _all: true },
        where: { is_deleted: false },
      }),
      this.prisma.complaint.groupBy({
        by: ['panchayat_id'],
        _count: { _all: true },
      }),
    ]);

    // Complaints are scoped by org_unit (panchayat_id), not tenant_id directly —
    // roll them up to tenant via each org unit's tenant_id.
    const orgUnits = await this.prisma.orgUnit.findMany({
      select: { id: true, tenant_id: true },
    });
    const tenantByOrgUnit = new Map(orgUnits.map((o) => [o.id, o.tenant_id]));
    const complaintsPerTenant = new Map<string, number>();
    for (const row of complaintsByTenant) {
      if (row.panchayat_id == null) continue;
      const tenantId = tenantByOrgUnit.get(row.panchayat_id);
      if (!tenantId) continue;
      complaintsPerTenant.set(
        tenantId,
        (complaintsPerTenant.get(tenantId) ?? 0) + row._count._all,
      );
    }

    const orgUnitCountByTenant = new Map(orgUnitsByTenant.map((r) => [r.tenant_id, r._count._all]));
    const userCountByTenant = new Map(usersByTenant.map((r) => [r.tenant_id, r._count._all]));

    return {
      total_tenants: tenants.length,
      active_tenants: tenants.filter((t) => t.is_active).length,
      total_org_units: orgUnitsByTenant.reduce((sum, r) => sum + r._count._all, 0),
      total_users: usersByTenant.reduce((sum, r) => sum + r._count._all, 0),
      tenants: tenants.map((t) => ({
        id: t.id,
        name: t.name,
        slug: t.slug,
        branch_type_hint: t.branch_type_hint,
        is_active: t.is_active,
        org_units: orgUnitCountByTenant.get(t.id) ?? 0,
        users: userCountByTenant.get(t.id) ?? 0,
        complaints: complaintsPerTenant.get(t.id) ?? 0,
      })),
    };
  }
}
