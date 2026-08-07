import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { RbacController } from './rbac.controller';
import { SidebarController } from './sidebar.controller';
import { RbacAdminService } from './rbac-admin.service';
import { RbacAnalyticsService } from './rbac-analytics.service';
import { FeatureAccessService } from './feature-access.service';
import { RoleTemplateService } from './role-template.service';
import { RbacService } from './rbac.service';
import { SidebarBuilderService } from './sidebar-builder.service';
import { FeatureGateService } from './feature-gate.service';
import { PermissionCacheService } from './permission-cache.service';

/**
 * Access resolution and administration.
 *
 * Global because auth, the guards and the admin console all need the same
 * answer to "what can this user do and see".
 */
@Global()
@Module({
  imports: [PrismaModule],
  controllers: [RbacController, SidebarController],
  providers: [
    RbacService,
    RbacAdminService,
    RbacAnalyticsService,
    FeatureAccessService,
    RoleTemplateService,
    SidebarBuilderService,
    FeatureGateService,
    PermissionCacheService,
  ],
  exports: [
    RbacService,
    RbacAdminService,
    RbacAnalyticsService,
    FeatureAccessService,
    RoleTemplateService,
    SidebarBuilderService,
    FeatureGateService,
    PermissionCacheService,
  ],
})
export class RbacModule {}
