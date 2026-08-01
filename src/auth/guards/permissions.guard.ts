import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';

/**
 * PermissionsGuard — a pure, synchronous check against the permission codes
 * already flattened onto the request by JwtStrategy (from AuthService's
 * buildJwtPayload → UserRole → Role → PermissionGroup resolution). No DB
 * calls here, and no silent-deny fallback: if `user.permissions` is missing
 * the check simply evaluates against an empty list.
 *
 * Usage: @Permissions('complaints.read', 'complaints.write')
 * `user.is_super_admin` bypasses all permission checks.
 */
@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredPermissions || requiredPermissions.length === 0) return true;

    const { user } = context.switchToHttp().getRequest();
    if (!user) return false;

    if (user.is_super_admin) return true;

    const userPermissions: string[] = user.permissions || [];
    return requiredPermissions.every((perm) => userPermissions.includes(perm));
  }
}
