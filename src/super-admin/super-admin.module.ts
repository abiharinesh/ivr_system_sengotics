import { Module } from '@nestjs/common';
import { SuperAdminService } from './super-admin.service';
import { SuperAdminController } from './super-admin.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { ElectricianOpsModule } from '../field-ops/field-ops.module';
import { PanchayatAdminModule } from '../panchayat-admin/panchayat-admin.module';
import { TenderModule } from '../tender/tender.module';
import { PlumberModule } from '../plumber/plumber.module';
import { PenaltyModule } from '../penalty/penalty.module';

@Module({
  imports: [
    PrismaModule,
    AuthModule,
    ElectricianOpsModule,
    PanchayatAdminModule,
    TenderModule,
    PlumberModule,
    PenaltyModule,
  ],
  providers: [SuperAdminService],
  controllers: [SuperAdminController],
})
export class SuperAdminModule {}
