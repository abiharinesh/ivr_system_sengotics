import { Module } from '@nestjs/common'
import { IvrController } from './ivr.controller'
import { IvrService } from './ivr.service'
import { VoiceProcessingModule } from '../voice-processing/voice-processing.module'

@Module({
    imports: [VoiceProcessingModule],
    controllers: [IvrController],
    providers: [IvrService]
})
export class IvrModule { }
