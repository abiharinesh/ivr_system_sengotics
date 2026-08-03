import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { BuildingPermitController } from './building-permit.controller';
import { BuildingPermitService } from './building-permit.service';

/**
 * Building Permit & Plan Approval (Screen Plan 14 §6).
 *
 * Only `PrismaModule` is imported — the platform services this module leans on
 * (number generation, workflow, SLA, audit, DMS) are all `@Global()` and are
 * injected directly.
 */
@Module({
  imports: [PrismaModule],
  controllers: [BuildingPermitController],
  providers: [BuildingPermitService],
  exports: [BuildingPermitService],
})
export class BuildingPermitModule {}
