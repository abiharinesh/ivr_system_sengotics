import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Enhanced RolesGuard — checks both the legacy `User.role` string field
 * AND the proper RBAC `UserRole` → `Role` tables.
 *
 * Priority:
 * 1. `super_admin` role always passes (hardcoded escape hatch).
 * 2. Legacy `user.role` is checked against required roles.
 * 3. If no match, queries the RBAC `user_roles` → `roles` tables.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles || requiredRoles.length === 0) return true;

    const { user } = context.switchToHttp().getRequest();
    if (!user) return false;

    // 1. Super admin always passes
    if (user.role === 'super_admin') return true;

    // 2. Check legacy User.role string
    if (requiredRoles.includes(user.role)) return true;

    // 3. Check RBAC UserRole → Role table
    try {
      const userRoles = await this.prisma.userRole.findMany({
        where: {
          user_id: user.id,
          valid_from: { lte: new Date() },
          OR: [
            { valid_until: null },
            { valid_until: { gte: new Date() } },
          ],
        },
        include: {
          // We can't include role directly (no relation in schema),
          // so we query separately
        },
      });

      if (userRoles.length === 0) return false;

      const roleIds = userRoles.map((ur) => ur.role_id);
      const roles = await this.prisma.role.findMany({
        where: {
          id: { in: roleIds },
          is_active: true,
        },
        select: { name: true },
      });

      const roleNames = roles.map((r) => r.name);
      return requiredRoles.some((required) => roleNames.includes(required));
    } catch (error) {
      // If RBAC tables don't exist yet (pre-migration), fall back gracefully
      return false;
    }
  }
}
