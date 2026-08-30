import { Module } from '@nestjs/common';
import { IvrController } from './ivr.controller';
import { IvrOperationsController } from './ivr-operations.controller';
import { IvrOperationsService } from './ivr-operations.service';
import { IvrService } from './ivr.service';
import { ExotelSyncService } from './exotel-sync.service';
import { PrismaModule } from '../prisma/prisma.module';
import { VoiceProcessingModule } from '../voice-processing/voice-processing.module';

/**
 * Two audiences, deliberately separate controllers.
 *
 * `IvrController` is webhook surface: Exotel posts to it mid-call, so it stays
 * unauthenticated and does as little as possible. `IvrOperationsController` is
 * the office reading back what happened, behind the usual guards.
 */
@Module({
  imports: [PrismaModule, VoiceProcessingModule],
  controllers: [IvrController, IvrOperationsController],
  providers: [IvrService, IvrOperationsService, ExotelSyncService],
  exports: [ExotelSyncService],
})
export class IvrModule {}

