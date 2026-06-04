import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { ElectricianOpsService } from './field-ops.service';

@Module({
  imports: [PrismaModule],
  providers: [ElectricianOpsService],
  exports: [ElectricianOpsService],
})
export class ElectricianOpsModule {}
