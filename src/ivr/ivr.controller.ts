import { Controller, Post, Body, HttpCode } from '@nestjs/common'
import { IvrService } from './ivr.service'
import { IvrCallbackDto } from './dto/ivr-callback.dto'

@Controller('api/ivr')
export class IvrController {
    constructor(private readonly ivrService: IvrService) { }

    @Post('service')
    @HttpCode(200)
    async handleServiceSelection(@Body() data: IvrCallbackDto) {
        await this.ivrService.handleServiceSelection(data)
        return {}
    }

    @Post('poll')
    @HttpCode(200)
    async handlePollInput(@Body() data: IvrCallbackDto) {
        await this.ivrService.handlePollInput(data)
        return {}
    }

    @Post('voicemail')
    @HttpCode(200)
    async handleVoicemail(@Body() data: IvrCallbackDto) {
        await this.ivrService.handleVoicemail(data)
        return {}
    }
}
