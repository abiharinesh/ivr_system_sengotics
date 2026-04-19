import { Controller, Post, Get, Body, Query, Res, UseFilters, Logger } from '@nestjs/common'
import { IvrServiceService } from './ivr-service.service'
import { IvrCallbackDto } from './dto/ivr-callback.dto'
import type { Response } from 'express'
import { IvrExceptionFilter } from './ivr-exception.filter'
import { VoiceProcessingService } from './voice-processing/voice-processing.service'

@UseFilters(IvrExceptionFilter)
@Controller('ivr')
export class IvrServiceController {
    private readonly logger = new Logger(IvrServiceController.name)
    constructor(
        private readonly ivrService: IvrServiceService,
        private readonly voiceProcessing: VoiceProcessingService,
    ) {}

    private sendEmptyXml(res: Response): void {
        res.status(200).type('application/xml').send(`<?xml version="1.0" encoding="UTF-8"?>\n<Response></Response>`)
    }
    private sendSuccessXml(res: Response): void {
        res.status(200).type('application/xml').send(`<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>உங்கள் புகார் பதிவு செய்யப்பட்டுள்ளது. நன்றி.</Say>\n</Response>`)
    }
    private normalizeRecordingUrl(data: IvrCallbackDto): string {
        return data.RecordingUrl || data.recording_url || data.recordingUrl || data.recording || ''
    }

    @Post('service')
    async handleServiceSelectionPost(@Body() data: IvrCallbackDto, @Res() res: Response) { return this.handleServiceSelection(data, res) }
    @Get('service')
    async handleServiceSelectionGet(@Query() data: IvrCallbackDto, @Res() res: Response) { return this.handleServiceSelection(data, res) }
    private async handleServiceSelection(data: IvrCallbackDto, res: Response): Promise<void> {
        try { await this.ivrService.handleServiceSelection(data) } catch (err) { this.logger.error(`[EP1] Error (non-fatal): ${(err as Error).message}`) }
        this.sendEmptyXml(res)
    }

    @Post('poll')
    async handlePollInputPost(@Body() data: IvrCallbackDto, @Res() res: Response) { return this.handlePollInput(data, res) }
    @Get('poll')
    async handlePollInputGet(@Query() data: IvrCallbackDto, @Res() res: Response) { return this.handlePollInput(data, res) }
    private async handlePollInput(data: IvrCallbackDto, res: Response): Promise<void> {
        try { await this.ivrService.handlePollInput(data) } catch (err) { this.logger.error(`[EP2] Error (non-fatal): ${(err as Error).message}`) }
        this.sendEmptyXml(res)
    }

    @Post('voice-match')
    async handleVoicePhase1Post(@Body() data: IvrCallbackDto, @Res() res: Response) { return this.handleVoicePhase1(data, res) }
    @Get('voice-match')
    async handleVoicePhase1Get(@Query() data: IvrCallbackDto, @Res() res: Response) { return this.handleVoicePhase1(data, res) }
    private async handleVoicePhase1(data: IvrCallbackDto, res: Response): Promise<void> {
        try {
            const recordingUrl = this.normalizeRecordingUrl(data)
            if (!recordingUrl || !data.CallSid) { this.sendEmptyXml(res); return }
            if (data.ProcessStatus && data.ProcessStatus !== 'ready') { this.sendEmptyXml(res); return }
            const ivrNumber = data.CallTo || data.To || ''
            await this.voiceProcessing.processPhase1Voice(data.CallSid, recordingUrl, ivrNumber)
            this.sendSuccessXml(res); return
        } catch (err) { this.logger.error(`[EP3-P1] Error (non-fatal): ${(err as Error).message}`); this.sendEmptyXml(res) }
    }

    @Post('voice-llm')
    async handleVoiceLlmPost(@Body() data: IvrCallbackDto, @Res() res: Response) { return this.handleVoiceLlm(data, res) }
    @Get('voice-llm')
    async handleVoiceLlmGet(@Query() data: IvrCallbackDto, @Res() res: Response) { return this.handleVoiceLlm(data, res) }
    private async handleVoiceLlm(data: IvrCallbackDto, res: Response): Promise<void> {
        try {
            const recordingUrl = this.normalizeRecordingUrl(data)
            if (!recordingUrl || !data.CallSid) { this.sendEmptyXml(res); return }
            const ivrNumber = data.CallTo || data.To || ''
            await this.voiceProcessing.acceptPhase2Llm(data.CallSid, recordingUrl, ivrNumber)
            this.sendSuccessXml(res)
        } catch (err) { this.logger.error(`[EP3-P2] Error (non-fatal): ${(err as Error).message}`); this.sendEmptyXml(res) }
    }
}
