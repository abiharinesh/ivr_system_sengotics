import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { RbacService } from '../../core/rbac/rbac.service';

/**
 * RolesGuard — a pure, synchronous check against the roles already decoded
 * onto the request by JwtStrategy. No DB calls here: `buildJwtPayload()` in
 * AuthService is the single place that resolves RBAC roles (UserRole → Role),
 * once, at login/context-switch time — guards just read the result.
 *
 * `user.is_super_admin` (driven by `Role.is_super_admin`, not a hardcoded
 * string) always passes. Otherwise the request passes if either the legacy
 * `user.role` string or any of the user's RBAC role names matches.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly rbac: RbacService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles || requiredRoles.length === 0) return true;

    const { user } = context.switchToHttp().getRequest();
    if (!user) return false;

    const entitlements = await this.rbac.entitlementsFor(user.id);
    if (entitlements.isSuperAdmin) return true;
    const roleNames = entitlements.roles.map((role) => role.name);
    return requiredRoles.some((required) => roleNames.includes(required));
  }
}
