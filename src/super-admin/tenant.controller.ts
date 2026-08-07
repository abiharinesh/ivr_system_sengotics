import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Authorize } from '../auth/decorators/authorize.decorator';
import { AuthorizationGuard } from '../auth/guards/authorization.guard';
import { TenantService } from '../core/tenant/tenant.service';
import { TenantProvisioningService } from './tenant-provisioning.service';
import type { ProvisionTenantInput } from './tenant-provisioning.service';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionCacheService } from '../core/rbac/permission-cache.service';

/**
 * Real CRUD for the `Tenant` model — the top-level client boundary. Distinct
 * from `SuperAdminController`'s `/panchayats` (now `/org-units`) routes,
 * which manage the org-unit hierarchy *within* a tenant. Before this
 * controller, `TenantService` was dead code with no route exposing it.
 */
@UseGuards(JwtAuthGuard, AuthorizationGuard)
@Authorize({ platformOnly: true })
@Controller('api/superadmin/tenants')
export class TenantController {
  constructor(
    private readonly tenants: TenantService,
    private readonly provisioning: TenantProvisioningService,
    private readonly prisma: PrismaService,
    private readonly cache: PermissionCacheService,
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
    let config = await this.prisma.tenantFeatureConfig.findUnique({
      where: { tenant_id: id },
    });
    if (!config) {
      config = await this.prisma.tenantFeatureConfig.create({
        data: { tenant_id: id },
      });
    }
    return config;
  }

  @Patch(':id/feature-ceiling')
  async updateFeatureCeiling(
    @Param('id') id: string,
    @Body() body: Record<string, boolean>,
  ) {
    const existing = await this.prisma.tenantFeatureConfig.findUnique({
      where: { tenant_id: id },
    });
    if (!existing) {
      const created = await this.prisma.tenantFeatureConfig.create({
        data: { tenant_id: id, ...body },
      });
      this.cache.invalidateTenant(id);
      return created;
    }
    const updated = await this.prisma.tenantFeatureConfig.update({
      where: { tenant_id: id },
      data: body,
    });
    this.cache.invalidateTenant(id);
    return updated;
  }

  @Get(':id/role-templates')
  async getTenantRoleTemplates(@Param('id') id: string) {
    const allTemplates = await this.prisma.role.findMany({
      where: { tenant_id: '__system__', org_unit_id: null },
      select: {
        id: true,
        name: true,
        display_name: true,
        applicable_branch_types: true,
      },
    });

    const tenantGrants = await this.prisma.tenantRoleTemplate.findMany({
      where: { tenant_id: id },
    });

    const grantMap = new Map(
      tenantGrants.map((g) => [g.role_template_id, g.enabled]),
    );

    return allTemplates.map((t) => ({
      role_template_id: t.id,
      name: t.name,
      display_name: t.display_name,
      applicable_branch_types: t.applicable_branch_types,
      enabled: grantMap.get(t.id) ?? true,
    }));
  }

  @Patch(':id/role-templates')
  async updateTenantRoleTemplates(
    @Param('id') id: string,
    @Body() body: { role_template_id: number; enabled: boolean },
  ) {
    const updated = await this.prisma.tenantRoleTemplate.upsert({
      where: {
        tenant_id_role_template_id: {
          tenant_id: id,
          role_template_id: body.role_template_id,
        },
      },
      update: { enabled: body.enabled },
      create: {
        tenant_id: id,
        role_template_id: body.role_template_id,
        enabled: body.enabled,
      },
    });
    this.cache.invalidateTenant(id);
    return updated;
  }

  @Get(':id/settings')
  async getTenantSettings(@Param('id') id: string) {
    let settings = await this.prisma.tenantSettings.findUnique({
      where: { tenant_id: id },
    });
    if (!settings) {
      settings = await this.prisma.tenantSettings.create({
        data: { tenant_id: id },
      });
    }
    return settings;
  }

  @Patch(':id/settings')
  async updateTenantSettings(
    @Param('id') id: string,
    @Body() body: Record<string, any>,
  ) {
    return this.prisma.tenantSettings.upsert({
      where: { tenant_id: id },
      update: body,
      create: { tenant_id: id, ...body },
    });
  }

  @Get(':id/audit-logs')
  async getTenantAuditLogs(@Param('id') id: string) {
    return this.prisma.auditLog.findMany({
      where: { tenant_id: id },
      include: {
        user: { select: { id: true, email: true, role: true } },
        org_unit: { select: { id: true, name: true } },
      },
      orderBy: { created_at: 'desc' },
      take: 100,
    });
  }
}
