import { Module } from '@nestjs/common';
import { MunicipalityController } from './municipality.controller';
import { MunicipalityService } from './municipality.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [MunicipalityController],
  providers: [MunicipalityService],
  exports: [MunicipalityService],
})
export class MunicipalityModule {}
