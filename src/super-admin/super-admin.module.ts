import { Module } from '@nestjs/common';
import { SuperAdminService } from './super-admin.service';
import { SuperAdminController } from './super-admin.controller';
import { TenantController } from './tenant.controller';
import { TenantProvisioningService } from './tenant-provisioning.service';
import { TenantAnalyticsController } from './tenant-analytics.controller';
import { TenantAnalyticsService } from './tenant-analytics.service';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { ElectricianOpsModule } from '../field-ops/field-ops.module';
import { PanchayatAdminModule } from '../panchayat-admin/panchayat-admin.module';
import { TenderModule } from '../tender/tender.module';
import { PlumberModule } from '../plumber/plumber.module';
import { PenaltyModule } from '../penalty/penalty.module';
import { TenantModule } from '../core/tenant/tenant.module';

@Module({
  imports: [
    PrismaModule,
    AuthModule,
    ElectricianOpsModule,
    PanchayatAdminModule,
    TenderModule,
    PlumberModule,
    PenaltyModule,
    TenantModule,
  ],
  providers: [SuperAdminService, TenantProvisioningService, TenantAnalyticsService],
  controllers: [SuperAdminController, TenantController, TenantAnalyticsController],
})
export class SuperAdminModule {}
