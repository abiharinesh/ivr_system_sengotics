import { Controller, Post, Get, Body, Query, Res, UseFilters, HttpStatus, Logger } from '@nestjs/common'
import { IvrService } from './ivr.service'
import { IvrCallbackDto } from './dto/ivr-callback.dto'
import type { Response } from 'express'
import { IvrExceptionFilter } from './ivr-exception.filter'
import { VoiceProcessingService } from '../voice-processing/voice-processing.service'

@UseFilters(IvrExceptionFilter)
@Controller('api/ivr')
export class IvrController {
    private readonly logger = new Logger(IvrController.name)

    constructor(
        private readonly ivrService: IvrService,
        private readonly voiceProcessing: VoiceProcessingService
    ) { }

    // ── XML Response Helpers ────────────────────────────────────────────────

    private sendEmptyXml(res: Response): void {
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response></Response>`
        res.status(200).type('application/xml').send(xml)
    }

    private sendSuccessXml(res: Response): void {
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>Complaint registered successfully</Say>\n</Response>`
        res.status(200).type('application/xml').send(xml)
    }

    // ── EP1: Service Selection (digit → service type) ───────────────────────

    @Post('service')
    async handleServiceSelectionPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        return this.handleServiceSelection(data, res)
    }

    @Get('service')
    async handleServiceSelectionGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        return this.handleServiceSelection(data, res)
    }

    private async handleServiceSelection(data: IvrCallbackDto, res: Response): Promise<void> {
        await this.ivrService.handleServiceSelection(data)
        this.sendEmptyXml(res)
    }

    // ── EP2: Poll / Detail Input (creates complaint) ────────────────────────

    @Post('poll')
    async handlePollInputPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        return this.handlePollInput(data, res)
    }

    @Get('poll')
    async handlePollInputGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        return this.handlePollInput(data, res)
    }

    private async handlePollInput(data: IvrCallbackDto, res: Response): Promise<void> {
        const result = await this.ivrService.handlePollInput(data)

        if (!result.found) {
            res.status(HttpStatus.NOT_FOUND).json({ message: 'Pole not found' })
            return
        }

        this.sendEmptyXml(res)
    }

    // ── EP3: Voice Complaint (transcribe → match → create) ──────────────────

    @Post('voice-complaint')
    async handleVoiceComplaintPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        return this.handleVoiceComplaint(data, res)
    }

    @Get('voice-complaint')
    async handleVoiceComplaintGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        return this.handleVoiceComplaint(data, res)
    }

    /**
     * Voice Complaint handler — called by Exotel after a caller leaves a voice note.
     * Returns 200 (XML) on success, 404 if the landmark couldn't be matched.
     * A 404 response tells Exotel the input was invalid, prompting the user to retry.
     */
    private async handleVoiceComplaint(data: IvrCallbackDto, res: Response): Promise<void> {
        if (!data.RecordingUrl || !data.CallSid) {
            res.status(HttpStatus.BAD_REQUEST).json({ message: 'Missing CallSid or RecordingUrl' })
            return
        }

        // Exotel sends a callback BEFORE the recording is ready (ProcessStatus != 'ready').
        // Only process when confirmed ready to avoid fetch errors.
        if (data.ProcessStatus && data.ProcessStatus !== 'ready') {
            this.logger.log(`Recording not ready (ProcessStatus=${data.ProcessStatus}). Returning 200 to Exotel.`)
            this.sendEmptyXml(res)
            return
        }

        const ivrNumber = data.CallTo || data.To || ''
        const result = await this.voiceProcessing.processVoiceComplaint(
            data.CallSid,
            data.RecordingUrl,
            ivrNumber
        )

        if (result.status === 'not_found') {
            // 404 → Exotel knows landmark matching failed → triggers retry flow
            res.status(HttpStatus.NOT_FOUND).json({
                message: result.message || 'Landmark not matched to any pole'
            })
            return
        }

        // For completed or manual_review, return success XML so the call flow continues
        this.sendSuccessXml(res)
    }
}
