import { Module } from '@nestjs/common';
import { AssetBookingService } from './asset-booking.service';
import { AssetBookingController } from './asset-booking.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [AssetBookingController],
  providers: [AssetBookingService],
  exports: [AssetBookingService],
})
export class AssetBookingModule {}
