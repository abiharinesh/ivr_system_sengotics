import { Module } from '@nestjs/common';
import { InspectionController } from './inspection.controller';
import { InspectionService } from './inspection.service';
import { PrismaModule } from '../prisma/prisma.module';
import { TenantModule } from '../core/tenant/tenant.module';

@Module({
  imports: [
    PrismaModule,
    TenantModule,
  ],
  controllers: [InspectionController],
  providers: [InspectionService],
  exports: [InspectionService],
})
export class InspectionModule {}
