import {
  Controller,
  Get,
  Put,
  Body,
  Param,
  Req,
  ParseIntPipe,
  UseGuards,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { PermissionCacheService } from '../core/rbac/permission-cache.service';
import { FeatureGateService } from '../core/rbac/feature-gate.service';

@UseGuards(JwtAuthGuard)
@Controller('api/tenant/features')
export class TenantFeatureController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly cache: PermissionCacheService,
    private readonly gate: FeatureGateService,
  ) {}

  private extractTenantId(req: any): string {
    const tenantId = req.user?.tenant_id;
    if (!tenantId) {
      throw new ForbiddenException('Tenant context missing from request');
    }
    return tenantId;
  }

  private async authorize(req: any): Promise<void> {
    await this.gate.checkOrThrow({
      userId: req.user.id,
      tenantId: this.extractTenantId(req),
      orgUnitId: req.user.org_unit_id,
      moduleKey: 'core',
      permissionCode: 'branches.configure_features',
    });
  }

  @Get('branches/:branchId')
  async getBranchFeatures(
    @Req() req: any,
    @Param('branchId', ParseIntPipe) branchId: number,
  ) {
    await this.authorize(req);
    const tenantId = this.extractTenantId(req);
    const org = await this.prisma.orgUnit.findFirst({
      where: { id: branchId, tenant_id: tenantId },
    });
    if (!org) {
      throw new NotFoundException(
        `Branch #${branchId} not found for tenant "${tenantId}"`,
      );
    }

    const [tenantCeiling, branchConfig] = await Promise.all([
      this.prisma.tenantFeatureConfig.findUnique({
        where: { tenant_id: tenantId },
      }),
      this.prisma.branchFeatureConfig.findUnique({
        where: { org_unit_id: branchId },
      }),
    ]);

    return {
      branch_id: branchId,
      platform_ceiling: tenantCeiling,
      branch_config: branchConfig,
    };
  }

  @Put('branches/:branchId')
  async updateBranchFeatures(
    @Req() req: any,
    @Param('branchId', ParseIntPipe) branchId: number,
    @Body() features: Record<string, boolean>,
  ) {
    await this.authorize(req);
    const tenantId = this.extractTenantId(req);
    const actorUserId = req.user?.id;

    const org = await this.prisma.orgUnit.findFirst({
      where: { id: branchId, tenant_id: tenantId },
    });
    if (!org) {
      throw new NotFoundException(
        `Branch #${branchId} not found for tenant "${tenantId}"`,
      );
    }

    const tenantCeiling = await this.prisma.tenantFeatureConfig.findUnique({
      where: { tenant_id: tenantId },
    });

    const allowedData: Record<string, boolean> = {};
    for (const [key, val] of Object.entries(features)) {
      if (['id', 'org_unit_id', 'created_at', 'updated_at'].includes(key))
        continue;

      // Platform Ceiling Enforcement: Tenant Admin cannot enable a feature disabled by Super Admin
      if (
        val === true &&
        tenantCeiling &&
        (tenantCeiling as any)[key] === false
      ) {
        throw new ForbiddenException(
          `Feature "${key}" is disabled by Super Admin at platform level and cannot be enabled for branch`,
        );
      }
      allowedData[key] = Boolean(val);
    }

    const updated = await this.prisma.branchFeatureConfig.upsert({
      where: { org_unit_id: branchId },
      update: allowedData,
      create: { org_unit_id: branchId, ...allowedData },
    });

    this.cache.invalidateTenant(tenantId);

    await this.audit.log({
      tenantId,
      orgUnitId: branchId,
      actorUserId,
      action: 'branch_feature.update',
      newValue: allowedData,
    });

    return updated;
  }
}
