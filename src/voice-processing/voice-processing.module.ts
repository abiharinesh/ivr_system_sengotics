import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { VoiceProcessingService } from './voice-processing.service'
import { VoiceToTextService } from './voice-to-text.service'
import { LocationExtractionService } from './location-extraction.service'
import { GeoMatchingService } from './geo-matching.service'

@Module({
    imports: [ConfigModule],
    providers: [
        VoiceProcessingService,
        VoiceToTextService,
        LocationExtractionService,
        GeoMatchingService
    ],
    exports: [VoiceProcessingService]
})
export class VoiceProcessingModule { }
