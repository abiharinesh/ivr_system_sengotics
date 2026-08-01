import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';

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
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles || requiredRoles.length === 0) return true;

    const { user } = context.switchToHttp().getRequest();
    if (!user) return false;

    if (user.is_super_admin) return true;
    if (requiredRoles.includes(user.role)) return true;

    const rbacRoleNames: string[] = (user.rbac_roles || []).map((r: any) => r.name);
    return requiredRoles.some((required) => rbacRoleNames.includes(required));
  }
}
