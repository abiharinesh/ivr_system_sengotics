import { Module } from '@nestjs/common';
import { PanchayatAdminService } from './panchayat-admin.service';
import { PanchayatAdminController } from './panchayat-admin.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { WhatsAppModule } from '../whatsapp/whatsapp.module';
import { ElectricianOpsModule } from '../field-ops/field-ops.module';
import { PlumberModule } from '../plumber/plumber.module';
import { PenaltyModule } from '../penalty/penalty.module';
import { TenantModule } from '../core';

@Module({
  imports: [
    PrismaModule,
    AuthModule,
    WhatsAppModule,
    ElectricianOpsModule,
    PlumberModule,
    PenaltyModule,
    TenantModule,
  ],
  providers: [PanchayatAdminService],
  controllers: [PanchayatAdminController],
  exports: [PanchayatAdminService],
})
export class PanchayatAdminModule {}
