import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { TenantService } from '../core/tenant/tenant.service';
import { TenantProvisioningService } from './tenant-provisioning.service';
import type { ProvisionTenantInput } from './tenant-provisioning.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Real CRUD for the `Tenant` model — the top-level client boundary. Distinct
 * from `SuperAdminController`'s `/panchayats` (now `/org-units`) routes,
 * which manage the org-unit hierarchy *within* a tenant. Before this
 * controller, `TenantService` was dead code with no route exposing it.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin')
@Controller('api/superadmin/tenants')
export class TenantController {
  constructor(
    private readonly tenants: TenantService,
    private readonly provisioning: TenantProvisioningService,
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  list() {
    return this.tenants.list();
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.tenants.findById(id);
  }

  /** Onboard a brand-new client: Tenant + root org unit + departments + first admin, in one call. */
  @Post('provision')
  provision(@Body() body: ProvisionTenantInput) {
    return this.provisioning.provisionTenant(body);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() body: Record<string, any>) {
    return this.tenants.update(id, body);
  }

  @Patch(':id/deactivate')
  deactivate(@Param('id') id: string) {
    return this.tenants.deactivate(id);
  }

  /**
   * Subscription-level feature ceiling for this tenant — the per-org-unit
   * `BranchFeatureConfig` can only ever enable a module the tenant ceiling
   * allows. Auto-creates a default-everything-on config on first read.
   */
  @Get(':id/feature-ceiling')
  async getFeatureCeiling(@Param('id') id: string) {
    let config = await this.prisma.tenantFeatureConfig.findUnique({ where: { tenant_id: id } });
    if (!config) {
      config = await this.prisma.tenantFeatureConfig.create({ data: { tenant_id: id } });
    }
    return config;
  }

  @Patch(':id/feature-ceiling')
  async updateFeatureCeiling(@Param('id') id: string, @Body() body: Record<string, boolean>) {
    const existing = await this.prisma.tenantFeatureConfig.findUnique({ where: { tenant_id: id } });
    if (!existing) {
      return this.prisma.tenantFeatureConfig.create({ data: { tenant_id: id, ...body } });
    }
    return this.prisma.tenantFeatureConfig.update({ where: { tenant_id: id }, data: body });
  }
}
