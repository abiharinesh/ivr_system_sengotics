import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  AUTHORIZATION_KEY,
  AuthorizationPolicy,
} from '../decorators/authorize.decorator';
import { FeatureGateService } from '../../core/rbac/feature-gate.service';
import { RbacService } from '../../core/rbac/rbac.service';

@Injectable()
export class AuthorizationGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly gate: FeatureGateService,
    private readonly rbac: RbacService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const policy = this.reflector.getAllAndOverride<AuthorizationPolicy>(
      AUTHORIZATION_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!policy) return true;

    const { user } = context.switchToHttp().getRequest();
    if (!user?.id || !user.tenant_id) return false;

    const entitlements = await this.rbac.entitlementsFor(user.id);
    if (policy.platformOnly) return entitlements.isSuperAdmin;

    const permissions = policy.permissions ?? [];
    if (permissions.length === 0) {
      await this.gate.checkOrThrow({
        userId: user.id,
        tenantId: user.tenant_id,
        orgUnitId: user.org_unit_id,
        moduleKey: policy.module,
      });
      return true;
    }

    // Multiple listed permissions mean any independently valid capability can
    // perform the operation (for example read-own or read-all). Each check
    // still evaluates tenant, template and branch feature gates.
    for (const permissionCode of permissions) {
      try {
        await this.gate.checkOrThrow({
          userId: user.id,
          tenantId: user.tenant_id,
          orgUnitId: user.org_unit_id,
          moduleKey: policy.module,
          permissionCode,
        });
        return true;
      } catch {
        // Try the next permitted capability before denying the request.
      }
    }
    return false;
  }
}
