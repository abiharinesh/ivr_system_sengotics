import { Injectable, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

/** Canonical department catalog seeded onto every new tenant's root org unit. */
const DEFAULT_DEPARTMENTS = [
  { code: 'engineering', name: 'Engineering' },
  { code: 'revenue', name: 'Revenue' },
  { code: 'public_health', name: 'Public Health' },
  { code: 'town_planning', name: 'Town Planning' },
  { code: 'accounts', name: 'Accounts' },
  { code: 'general_administration', name: 'General Administration' },
];

/** Which system role a tenant's first admin gets, by the kind of body it is. */
const DEFAULT_ADMIN_ROLE_BY_BRANCH_TYPE: Record<string, string> = {
  MUNICIPAL_CORPORATION: 'municipal_commissioner',
  MUNICIPALITY: 'municipal_commissioner',
  TOWN_PANCHAYAT: 'panchayat_admin',
  DISTRICT_PANCHAYAT: 'panchayat_admin',
  PANCHAYAT_UNION: 'panchayat_admin',
  VILLAGE_PANCHAYAT: 'panchayat_admin',
};

export interface ProvisionTenantInput {
  slug: string;
  name: string;
  branch_type: string;
  district?: string;
  admin_email: string;
  admin_password?: string;
  admin_phone?: string;
}

/**
 * Onboards a brand-new client in one transaction: Tenant → root OrgUnit →
 * default Departments → TenantFeatureConfig → first admin User + primary
 * UserRole. Generalizes the older `createUnifiedPanchayat` flow (which only
 * created a branch + branding + admin) to the real Tenant boundary.
 */
@Injectable()
export class TenantProvisioningService {
  constructor(private prisma: PrismaService) {}

  async provisionTenant(input: ProvisionTenantInput) {
    const existingTenant = await this.prisma.tenant.findFirst({
      where: { OR: [{ id: input.slug }, { slug: input.slug }] },
    });
    if (existingTenant) {
      throw new BadRequestException(`Tenant slug "${input.slug}" is already in use`);
    }

    const adminRoleName = DEFAULT_ADMIN_ROLE_BY_BRANCH_TYPE[input.branch_type] ?? 'panchayat_admin';
    const adminRole = await this.prisma.role.findFirst({
      where: { tenant_id: '__system__', org_unit_id: null, name: adminRoleName },
    });
    if (!adminRole) {
      throw new BadRequestException(
        `System role "${adminRoleName}" is not seeded — run prisma/seed-roles.js first`,
      );
    }

    const passwordHash = await bcrypt.hash(input.admin_password || 'Password@123', 10);

    return this.prisma.$transaction(async (tx) => {
      const tenant = await tx.tenant.create({
        data: {
          id: input.slug,
          slug: input.slug,
          name: input.name,
          branch_type_hint: input.branch_type as any,
          is_active: true,
        },
      });

      const rootOrgUnit = await tx.orgUnit.create({
        data: {
          name: input.name,
          tenant_id: tenant.id,
          branch_type: input.branch_type as any,
          district: input.district ?? null,
        },
      });

      await tx.department.createMany({
        data: DEFAULT_DEPARTMENTS.map((d) => ({
          tenant_id: tenant.id,
          org_unit_id: rootOrgUnit.id,
          code: d.code,
          name: d.name,
        })),
      });

      await tx.branchFeatureConfig.create({ data: { org_unit_id: rootOrgUnit.id } });
      await tx.tenantFeatureConfig.create({ data: { tenant_id: tenant.id } });

      const adminUser = await tx.user.create({
        data: {
          email: input.admin_email.trim(),
          password_hash: passwordHash,
          role: adminRoleName,
          tenant_id: tenant.id,
          primary_org_unit_id: rootOrgUnit.id,
          phone_e164: input.admin_phone?.trim() || null,
          user_type: 'employee',
          is_active: true,
          is_verified: true,
        },
      });

      await tx.userRole.create({
        data: {
          user_id: adminUser.id,
          role_id: adminRole.id,
          org_unit_id: rootOrgUnit.id,
          tenant_id: tenant.id,
          is_primary: true,
          access_scope: 'own_org_unit',
        },
      });

      return {
        tenant,
        root_org_unit: rootOrgUnit,
        admin_user: { id: adminUser.id, email: adminUser.email, role: adminUser.role },
      };
    });
  }
}
