import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { TradeLicenceController } from './trade-licence.controller';
import { TradeLicencePublicController } from './trade-licence.public.controller';
import { TradeLicenceService } from './trade-licence.service';

/**
 * Trade Licence & Renewal (Screen Plan 16).
 *
 * Wires into number generation, workflow (approval chain), SLA (decision
 * window), audit and the DMS. The nightly expiry sweep is what turns a silent
 * lapse into a visible one on the renewal board.
 */
@Module({
  imports: [PrismaModule],
  controllers: [TradeLicenceController, TradeLicencePublicController],
  providers: [TradeLicenceService],
  exports: [TradeLicenceService],
})
export class TradeLicenceModule {}
