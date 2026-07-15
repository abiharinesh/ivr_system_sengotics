import { Module } from '@nestjs/common';
import { ContractorController, WorkOrderController } from './contractor.controller';
import { ContractorService } from './contractor.service';
import { PrismaModule } from '../prisma/prisma.module';
import { NumberGenModule } from '../core/number-gen/number-gen.module';
import { AuditModule } from '../core/audit/audit.module';
import { TenantModule } from '../core/tenant/tenant.module';

@Module({
  imports: [
    PrismaModule,
    NumberGenModule,
    AuditModule,
    TenantModule,
  ],
  controllers: [ContractorController, WorkOrderController],
  providers: [ContractorService],
  exports: [ContractorService],
})
export class ContractorModule {}
