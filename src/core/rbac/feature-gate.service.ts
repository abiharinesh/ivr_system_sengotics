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
    const isSuperAdmin = user.user_roles.some(
      (ur) =>
        ur.tenant_id === ctx.tenantId &&
        ur.role?.is_active &&
        ur.role.is_super_admin &&
        (!ur.valid_until || ur.valid_until >= new Date()),
    );
    if (isSuperAdmin) return GateResult.ALLOW;

    // The context must be owned by the caller. This stops an internal caller
    // from accidentally authorizing a valid user against another tenant's
    // feature and role configuration.
    if (user.tenant_id !== ctx.tenantId) {
      this.logger.warn(
        `Denied tenant mismatch: user #${ctx.userId} belongs to ${user.tenant_id}, requested ${ctx.tenantId}`,
      );
      return GateResult.DENY;
    }

    // Level 1: Platform Module Check
    if (ctx.moduleKey) {
      const tenantConfig = await this.prisma.tenantFeatureConfig.findUnique({
        where: { tenant_id: ctx.tenantId },
      });
      if (tenantConfig && (tenantConfig as any)[ctx.moduleKey] === false) {
        this.logger.warn(
          `Denied Level 1 (Platform Module): ${ctx.moduleKey} for tenant ${ctx.tenantId}`,
        );
        return GateResult.DENY;
      }
    }

    // Level 4: User Assigned Role Check
    const activeRoles = user.user_roles.filter(
      (ur) =>
        ur.tenant_id === ctx.tenantId &&
        ur.role?.is_active !== false &&
        (!ur.valid_until || ur.valid_until >= new Date()),
    );
    if (activeRoles.length === 0) {
      this.logger.warn(
        `Denied Level 4 (User Role Assignment): No active role for user #${ctx.userId} in tenant ${ctx.tenantId}`,
      );
      return GateResult.DENY;
    }

    // A template switch applies to every tenant copy descended from that
    // template. Do not rely on callers to supply an optional template ID.
    const templateIds = new Set<number>();
    if (ctx.roleTemplateId) templateIds.add(ctx.roleTemplateId);
    for (const assignment of activeRoles) {
      const role = assignment.role;
      if (role?.template_id != null) templateIds.add(role.template_id);
      if (role?.tenant_id === '__system__') templateIds.add(role.id);
    }
    let disabledTemplateIds = new Set<number>();
    if (templateIds.size > 0) {
      const disabled = await this.prisma.tenantRoleTemplate.findMany({
        where: {
          tenant_id: ctx.tenantId,
          role_template_id: { in: [...templateIds] },
          enabled: false,
        },
        select: { role_template_id: true },
      });
      disabledTemplateIds = new Set(
        disabled.map((row) => row.role_template_id),
      );
      if (ctx.roleTemplateId && disabledTemplateIds.has(ctx.roleTemplateId)) {
        this.logger.warn(
          `Denied Level 2 (Platform Role Template): #${ctx.roleTemplateId} for tenant ${ctx.tenantId}`,
        );
        return GateResult.DENY;
      }
    }

    // A user may hold more than one role. A disabled template removes only the
    // roles derived from that template; any separately valid assignment can
    // still grant the requested permission.
    const effectiveRoles = activeRoles.filter((assignment) => {
      const role = assignment.role;
      const templateId =
        role?.template_id ??
        (role?.tenant_id === '__system__' ? role.id : null);
      return templateId == null || !disabledTemplateIds.has(templateId);
    });
    if (effectiveRoles.length === 0) {
      this.logger.warn(
        `Denied Level 2 (Platform Role Template): all active roles are disabled for user #${ctx.userId}`,
      );
      return GateResult.DENY;
    }

    const roleIds = effectiveRoles.map((ur) => ur.role_id);

    // Level 3: Tenant Role Permission Check
    if (ctx.permissionCode) {
      const permissionGrants = await this.prisma.rolePermission.findMany({
        where: {
          role_id: { in: roleIds },
          permission: { code: ctx.permissionCode },
        },
      });
      if (permissionGrants.length === 0) {
        this.logger.warn(
          `Denied Level 3 (Tenant Role Permission): ${ctx.permissionCode} for user #${ctx.userId}`,
        );
        return GateResult.DENY;
      }
    }

    // Level 5: Branch Feature Check
    if (ctx.orgUnitId && ctx.moduleKey) {
      const branchConfig = await this.prisma.branchFeatureConfig.findUnique({
        where: { org_unit_id: ctx.orgUnitId },
      });
      if (branchConfig && (branchConfig as any)[ctx.moduleKey] === false) {
        this.logger.warn(
          `Denied Level 5 (Branch Feature): ${ctx.moduleKey} for orgUnit #${ctx.orgUnitId}`,
        );
        return GateResult.DENY;
      }
    }

    return GateResult.ALLOW;
  }

  /** Assert access or throw HTTP 403 ForbiddenException */
  async checkOrThrow(ctx: EvaluationContext): Promise<void> {
    const result = await this.evaluate(ctx);
    if (result === GateResult.DENY) {
      throw new ForbiddenException(
        'Access denied by system authorization engine',
      );
    }
  }
}
