import { Controller, Post, Get, Body, Query, Res, UseFilters, HttpStatus } from '@nestjs/common'
import { IvrService } from './ivr.service'
import { IvrCallbackDto } from './dto/ivr-callback.dto'
import type { Response } from 'express'
import { IvrExceptionFilter } from './ivr-exception.filter'

@UseFilters(IvrExceptionFilter)
@Controller('api/ivr')
export class IvrController {
    constructor(private readonly ivrService: IvrService) { }

    private sendXml(res: Response): void {
        const xml = `<?xml version="1.0" encoding="UTF-8"?><Response></Response>`
        res.status(200).type('text/xml').send(xml)
    }

    @Post('service')
    async handleServiceSelectionPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        await this.ivrService.handleServiceSelection(data)
        this.sendXml(res)
    }

    @Get('service')
    async handleServiceSelectionGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        await this.ivrService.handleServiceSelection(data)
        this.sendXml(res)
    }

    @Post('poll')
    async handlePollInputPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        const result = await this.ivrService.handlePollInput(data)
        if (!result.found) {
            return res.status(HttpStatus.NOT_FOUND).json({ message: 'Pole not found' })
        }
        this.sendXml(res)
    }

    @Get('poll')
    async handlePollInputGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        const result = await this.ivrService.handlePollInput(data)
        if (!result.found) {
            return res.status(HttpStatus.NOT_FOUND).json({ message: 'Pole not found' })
        }
        this.sendXml(res)
    }

    @Post('voicemail')
    async handleVoicemailPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        await this.ivrService.handleVoicemail(data)
        this.sendXml(res)
    }

    @Get('voicemail')
    async handleVoicemailGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        await this.ivrService.handleVoicemail(data)
        this.sendXml(res)
    }
}
