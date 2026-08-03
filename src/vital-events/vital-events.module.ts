import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { VitalEventsController } from './vital-events.controller';
import { VitalEventsPublicController } from './vital-events.public.controller';
import { VitalEventsService } from './vital-events.service';

/**
 * Birth & Death Registration (Screen Plan 14 §7).
 *
 * Two controllers: the authenticated register, and an unauthenticated
 * verification endpoint for scanned QR codes. Platform services (number
 * generation, workflow, SLA, audit, DMS) are `@Global()` and injected directly.
 */
@Module({
  imports: [PrismaModule],
  controllers: [VitalEventsController, VitalEventsPublicController],
  providers: [VitalEventsService],
  exports: [VitalEventsService],
})
export class VitalEventsModule {}
