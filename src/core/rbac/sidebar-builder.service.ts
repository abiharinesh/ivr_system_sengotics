import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RbacService, NavScreen } from './rbac.service';
import { FeatureAccessService } from './feature-access.service';
import { PermissionCacheService } from './permission-cache.service';

export interface SidebarResponse {
  menus: NavScreen[];
  permissions: string[];
  modules: string[];
  user: {
    id: number;
    email: string | null;
    phone_e164: string | null;
    role: string;
    is_super_admin: boolean;
    must_change_password: boolean;
  };
  tenant: {
    id: string;
    name: string;
    slug: string;
    logo_url?: string | null;
  } | null;
  branch: {
    id: number;
    name: string;
    branch_type: string;
  } | null;
}

@Injectable()
export class SidebarBuilderService {
  private readonly logger = new Logger(SidebarBuilderService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rbacService: RbacService,
    private readonly featureAccess: FeatureAccessService,
    private readonly cache: PermissionCacheService,
  ) {}

  /**
   * Build the complete unified entitlement context payload for a user.
   * NEVER stored in DB or JWT — evaluated dynamically on every request/login.
   */
  async buildSidebar(
    userId: number,
    requestTenantId?: string,
  ): Promise<SidebarResponse> {
    // Tenant-scoped prefix lets provisioning changes clear every affected
    // sidebar without retaining a separate user-to-tenant index.
    const cacheKey = `tenant:${requestTenantId || 'unknown'}:user:${userId}:sidebar`;
    const cached = this.cache.get<SidebarResponse>(cacheKey);
    if (cached) return cached;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        tenant: true,
        primary_org_unit: true,
        user_roles: {
          include: {
            role: true,
            org_unit: true,
          },
        },
      },
    });

    if (!user) {
      return {
        menus: [],
        permissions: [],
        modules: [],
        user: {
          id: userId,
          email: null,
          phone_e164: null,
          role: 'guest',
          is_super_admin: false,
          must_change_password: false,
        },
        tenant: null,
        branch: null,
      };
    }

    const isSuperAdmin = user.user_roles.some(
      (ur) => ur.role?.is_super_admin && ur.role?.is_active,
    );

    if (isSuperAdmin) {
      const platformNav = await this.rbacService.platformNav();
      const allPermissions = await this.prisma.permission.findMany({
        select: { code: true },
      });
      const response: SidebarResponse = {
        menus: platformNav,
        permissions: allPermissions.map((p) => p.code),
        modules: ['core', 'all'],
        user: {
          id: user.id,
          email: user.email,
          phone_e164: user.phone_e164,
          role: user.role,
          is_super_admin: true,
          must_change_password: user.must_change_password,
        },
        tenant: user.tenant
          ? {
              id: user.tenant.id,
              name: user.tenant.name,
              slug: user.tenant.slug,
              logo_url: user.tenant.logo_url,
            }
          : null,
        branch: user.primary_org_unit
          ? {
              id: user.primary_org_unit.id,
              name: user.primary_org_unit.name,
              branch_type: user.primary_org_unit.branch_type,
            }
          : null,
      };

      this.cache.set(cacheKey, response);
      return response;
    }

    const entitlements = await this.rbacService.entitlementsFor(userId);
    const orgUnitId = user.primary_org_unit_id;
    const enabledModulesSet =
      await this.featureAccess.enabledModulesFor(orgUnitId);
    const enabledModules = enabledModulesSet
      ? Array.from(enabledModulesSet)
      : [];

    const response: SidebarResponse = {
      menus: entitlements.nav,
      permissions: entitlements.permissions,
      modules: enabledModules,
      user: {
        id: user.id,
        email: user.email,
        phone_e164: user.phone_e164,
        role: user.role,
        is_super_admin: false,
        must_change_password: user.must_change_password,
      },
      tenant: user.tenant
        ? {
            id: user.tenant.id,
            name: user.tenant.name,
            slug: user.tenant.slug,
            logo_url: user.tenant.logo_url,
          }
        : null,
      branch: user.primary_org_unit
        ? {
            id: user.primary_org_unit.id,
            name: user.primary_org_unit.name,
            branch_type: user.primary_org_unit.branch_type,
          }
        : null,
    };

    this.cache.set(cacheKey, response);
    return response;
  }
}
