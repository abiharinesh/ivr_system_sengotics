import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * PermissionsGuard — checks if the logged-in user has the required
 * permission codes via their assigned roles → permission groups.
 *
 * Usage: @Permissions('complaints.read', 'complaints.write')
 *
 * Super admin bypasses all permission checks.
 */
@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredPermissions || requiredPermissions.length === 0) return true;

    const { user } = context.switchToHttp().getRequest();
    if (!user) return false;

    // Super admin bypasses all permission checks
    if (user.role === 'super_admin') return true;

    // Check if user has the required permissions via JWT payload
    if (user.permissions && Array.isArray(user.permissions)) {
      return requiredPermissions.every((perm) =>
        user.permissions.includes(perm),
      );
    }

    // Fallback: Query RBAC tables directly
    try {
      const userPermissions = await this.getUserPermissions(user.id);
      return requiredPermissions.every((perm) =>
        userPermissions.includes(perm),
      );
    } catch (error) {
      // If RBAC tables don't exist yet, deny access
      return false;
    }
  }

  /**
   * Resolves all permission codes for a user by traversing:
   * UserRole → Role → PermissionGroup → permissions[]
   */
  private async getUserPermissions(userId: number): Promise<string[]> {
    // 1. Get active user roles
    const userRoles = await this.prisma.userRole.findMany({
      where: {
        user_id: userId,
        valid_from: { lte: new Date() },
        OR: [
          { valid_until: null },
          { valid_until: { gte: new Date() } },
        ],
      },
    });

    if (userRoles.length === 0) return [];

    // 2. Get roles with permission group IDs
    const roleIds = userRoles.map((ur) => ur.role_id);
    const roles = await this.prisma.role.findMany({
      where: {
        id: { in: roleIds },
        is_active: true,
        permission_group_id: { not: null },
      },
      select: { permission_group_id: true },
    });

    const groupIds = roles
      .map((r) => r.permission_group_id)
      .filter((id): id is number => id !== null);

    if (groupIds.length === 0) return [];

    // 3. Get permission groups and flatten permission codes
    const groups = await this.prisma.permissionGroup.findMany({
      where: { id: { in: groupIds } },
      select: { permissions: true },
    });

    const allPermissions = new Set<string>();
    for (const group of groups) {
      const perms = group.permissions as string[];
      if (Array.isArray(perms)) {
        perms.forEach((p) => allPermissions.add(p));
      }
    }

    return Array.from(allPermissions);
  }
}
