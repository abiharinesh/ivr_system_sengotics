import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { RbacController } from './rbac.controller';
import { RbacAdminService } from './rbac-admin.service';
import { RbacAnalyticsService } from './rbac-analytics.service';
import { FeatureAccessService } from './feature-access.service';
import { RoleTemplateService } from './role-template.service';
import { RbacService } from './rbac.service';

/**
 * Access resolution and administration.
 *
 * Global because auth, the guards and the admin console all need the same
 * answer to "what can this user do and see" — the split source of truth
 * between the API guards and the hardcoded Dart sidebar is exactly what this
 * module exists to close.
 */
@Global()
@Module({
  imports: [PrismaModule],
  controllers: [RbacController],
  providers: [
    RbacService,
    RbacAdminService,
    RbacAnalyticsService,
    FeatureAccessService,
    RoleTemplateService,
  ],
  exports: [
    RbacService,
    RbacAdminService,
    RbacAnalyticsService,
    FeatureAccessService,
    RoleTemplateService,
  ],
})
export class RbacModule {}
