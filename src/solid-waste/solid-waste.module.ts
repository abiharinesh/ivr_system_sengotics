import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { SolidWasteController } from './solid-waste.controller';
import { SolidWasteService } from './solid-waste.service';

/**
 * Solid Waste Management (Screen Plan 14 §1).
 *
 * Wires into number generation, SLA (bin clearance) and audit. Deliberately
 * *not* into the workflow engine: collection is operational rather than
 * transactional — nobody approves a bin being emptied — and instantiating an
 * approval chain here would be cargo-culting the pattern rather than using it.
 */
@Module({
  imports: [PrismaModule],
  controllers: [SolidWasteController],
  providers: [SolidWasteService],
  exports: [SolidWasteService],
})
export class SolidWasteModule {}
