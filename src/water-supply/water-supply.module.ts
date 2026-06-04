import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { WaterSupplyController } from './water-supply.controller';
import { WaterSupplyService } from './water-supply.service';

@Module({
  imports: [PrismaModule],
  controllers: [WaterSupplyController],
  providers: [WaterSupplyService],
  exports: [WaterSupplyService],
})
export class WaterSupplyModule {}
