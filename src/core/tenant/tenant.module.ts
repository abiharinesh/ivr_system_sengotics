import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { TenantService } from './tenant.service';
import { OrgHierarchyService } from './org-hierarchy.service';
import { TenantConfigController } from './tenant-config.controller';
import { TenantContext } from './tenant-context';
import { TenantContextInterceptor } from './tenant-context.interceptor';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [TenantConfigController],
  providers: [
    TenantService,
    OrgHierarchyService,
    TenantContext,
    { provide: APP_INTERCEPTOR, useClass: TenantContextInterceptor },
  ],
  exports: [TenantService, OrgHierarchyService, TenantContext],
})
export class TenantModule {}
