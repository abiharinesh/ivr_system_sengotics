import { Injectable, Logger, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { PermissionCacheService } from './permission-cache.service';

export interface EvaluationContext {
  userId: number;
  tenantId: string;
  orgUnitId?: number | null;
  moduleKey?: string;
  permissionCode?: string;
  roleTemplateId?: number;
}

export enum GateResult {
  ALLOW = 'ALLOW',
  DENY = 'DENY',
}

@Injectable()
export class FeatureGateService {
  private readonly logger = new Logger(FeatureGateService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: PermissionCacheService,
  ) {}

  /**
   * Evaluates top-down 5-Level Permission Check:
   * Level 1: Platform Module Enabled
   * Level 2: Platform Role Template Enabled
   * Level 3: Tenant Role Permission
   * Level 4: User Assigned Role
   * Level 5: Branch Feature Enabled
   */
  async evaluate(ctx: EvaluationContext): Promise<GateResult> {
    const user = await this.prisma.user.findUnique({
      where: { id: ctx.userId },
      include: {
        user_roles: {
          include: { role: true },
        },
      },
    });

    if (!user) return GateResult.DENY;

    // Super Admin Bypass
    const isSuperAdmin = user.role === 'super_admin' || user.user_roles.some((ur) => ur.role?.is_super_admin);
    if (isSuperAdmin) return GateResult.ALLOW;

    // Level 1: Platform Module Check
    if (ctx.moduleKey) {
      const tenantConfig = await this.prisma.tenantFeatureConfig.findUnique({
        where: { tenant_id: ctx.tenantId },
      });
      if (tenantConfig && (tenantConfig as any)[ctx.moduleKey] === false) {
        this.logger.warn(`Denied Level 1 (Platform Module): ${ctx.moduleKey} for tenant ${ctx.tenantId}`);
        return GateResult.DENY;
      }
    }

    // Level 2: Platform Role Template Check
    if (ctx.roleTemplateId) {
      const roleTemplateConfig = await this.prisma.tenantRoleTemplate.findUnique({
        where: {
          tenant_id_role_template_id: {
            tenant_id: ctx.tenantId,
            role_template_id: ctx.roleTemplateId,
          },
        },
      });
      if (roleTemplateConfig && roleTemplateConfig.enabled === false) {
        this.logger.warn(`Denied Level 2 (Platform Role Template): #${ctx.roleTemplateId} for tenant ${ctx.tenantId}`);
        return GateResult.DENY;
      }
    }

    // Level 4: User Assigned Role Check
    const activeRoles = user.user_roles.filter(
      (ur) => ur.tenant_id === ctx.tenantId && (!ur.valid_until || ur.valid_until >= new Date()),
    );
    if (activeRoles.length === 0) {
      this.logger.warn(`Denied Level 4 (User Role Assignment): No active role for user #${ctx.userId} in tenant ${ctx.tenantId}`);
      return GateResult.DENY;
    }

    const roleIds = activeRoles.map((ur) => ur.role_id);

    // Level 3: Tenant Role Permission Check
    if (ctx.permissionCode) {
      const permissionGrants = await this.prisma.rolePermission.findMany({
        where: {
          role_id: { in: roleIds },
          permission: { code: ctx.permissionCode },
        },
      });
      if (permissionGrants.length === 0) {
        this.logger.warn(`Denied Level 3 (Tenant Role Permission): ${ctx.permissionCode} for user #${ctx.userId}`);
        return GateResult.DENY;
      }
    }

    // Level 5: Branch Feature Check
    if (ctx.orgUnitId && ctx.moduleKey) {
      const branchConfig = await this.prisma.branchFeatureConfig.findUnique({
        where: { org_unit_id: ctx.orgUnitId },
      });
      if (branchConfig && (branchConfig as any)[ctx.moduleKey] === false) {
        this.logger.warn(`Denied Level 5 (Branch Feature): ${ctx.moduleKey} for orgUnit #${ctx.orgUnitId}`);
        return GateResult.DENY;
      }
    }

    return GateResult.ALLOW;
  }

  /** Assert access or throw HTTP 403 ForbiddenException */
  async checkOrThrow(ctx: EvaluationContext): Promise<void> {
    const result = await this.evaluate(ctx);
    if (result === GateResult.DENY) {
      throw new ForbiddenException('Access denied by system authorization engine');
    }
  }
}
