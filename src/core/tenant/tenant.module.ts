import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { TenantService } from './tenant.service';
import { OrgHierarchyService } from './org-hierarchy.service';
import { TenantConfigController } from './tenant-config.controller';
import { TenantContext } from './tenant-context';
import { TenantContextInterceptor } from './tenant-context.interceptor';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuditModule } from '../audit/audit.module';
import { TenantUserService } from '../../tenant/tenant-user.service';
import { TenantUserController } from '../../tenant/tenant-user.controller';
import { TenantRoleController } from '../../tenant/tenant-role.controller';
import { TenantFeatureController } from '../../tenant/tenant-feature.controller';

@Module({
  imports: [PrismaModule, AuditModule],
  controllers: [
    TenantConfigController,
    TenantUserController,
    TenantRoleController,
    TenantFeatureController,
  ],
  providers: [
    TenantService,
    TenantUserService,
    OrgHierarchyService,
    TenantContext,
    { provide: APP_INTERCEPTOR, useClass: TenantContextInterceptor },
  ],
  exports: [TenantService, TenantUserService, OrgHierarchyService, TenantContext],
})
export class TenantModule {}
