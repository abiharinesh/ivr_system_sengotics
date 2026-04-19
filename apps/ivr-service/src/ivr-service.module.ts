import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule } from '@app/shared'
import { IvrServiceController } from './ivr-service.controller'
import { IvrServiceService } from './ivr-service.service'
import { VoiceProcessingService } from './voice-processing/voice-processing.service'
import { VoiceToTextService } from './voice-processing/voice-to-text.service'
import { LocationExtractionService } from './voice-processing/location-extraction.service'
import { GeoMatchingService } from './voice-processing/geo-matching.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
    ],
    controllers: [IvrServiceController],
    providers: [
        IvrServiceService,
        VoiceProcessingService,
        VoiceToTextService,
        LocationExtractionService,
        GeoMatchingService,
    ],
})
export class IvrServiceModule {}
