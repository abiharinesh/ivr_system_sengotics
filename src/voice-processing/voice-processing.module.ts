import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { VoiceProcessingService } from './voice-processing.service';
import { VoiceToTextService } from './voice-to-text.service';
import { LocationExtractionService } from './location-extraction.service';
import { GeoMatchingService } from './geo-matching.service';
import { WardIdentificationService } from './ward-identification.service';

@Module({
  imports: [ConfigModule, PrismaModule],
  providers: [
    VoiceProcessingService,
    VoiceToTextService,
    LocationExtractionService,
    GeoMatchingService,
    WardIdentificationService,
  ],
  exports: [VoiceProcessingService, WardIdentificationService],
})
export class VoiceProcessingModule {}

