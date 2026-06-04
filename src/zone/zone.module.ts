import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { ZoneService } from './zone.service';
import {
  PanchayatAdminZoneController,
  SuperAdminZoneController,
} from './zone.controller';

@Module({
  imports: [PrismaModule],
  controllers: [PanchayatAdminZoneController, SuperAdminZoneController],
  providers: [ZoneService],
  exports: [ZoneService],
})
export class ZoneModule {}
