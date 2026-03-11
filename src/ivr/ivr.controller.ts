import { Controller, Post, Get, Body, Query, Res, UseFilters, HttpStatus, Logger } from '@nestjs/common'
import { IvrService } from './ivr.service'
import { IvrCallbackDto } from './dto/ivr-callback.dto'
import type { Response } from 'express'
import { IvrExceptionFilter } from './ivr-exception.filter'
import { VoiceProcessingService } from '../voice-processing/voice-processing.service'

/**
 * IVR Controller — all Exotel-facing endpoints.
 *
 * CRITICAL RULES (to prevent call disconnects):
 *   1. Every endpoint MUST return XML 200 by default.
 *   2. Only return 404 when the Exotel flow explicitly expects it (poll + voice-complaint).
 *   3. Never return 400/500 — the exception filter catches everything and returns XML 200.
 *   4. Every handler has its own try-catch as a final safety net.
 */
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
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>உங்கள் புகார் பதிவு செய்யப்பட்டுள்ளது. நன்றி.</Say>\n</Response>`
        res.status(200).type('application/xml').send(xml)
    }

    private normalizeRecordingUrl(data: IvrCallbackDto): string {
        return data.RecordingUrl
            || data.recording_url
            || data.recordingUrl
            || data.recording
            || ''
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //   EP1: SERVICE SELECTION  —  /api/ivr/service
    //   User presses a digit (1/2/3) to choose a service type.
    //   Always returns XML 200 so the Exotel flow continues.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @Post('service')
    async handleServiceSelectionPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        return this.handleServiceSelection(data, res)
    }

    @Get('service')
    async handleServiceSelectionGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        return this.handleServiceSelection(data, res)
    }

    private async handleServiceSelection(data: IvrCallbackDto, res: Response): Promise<void> {
        try {
            this.logger.log(`[EP1] Service selection received: CallSid=${data.CallSid ?? 'N/A'}`)
            await this.ivrService.handleServiceSelection(data)
        } catch (err) {
            this.logger.error(`[EP1] Error (non-fatal): ${(err as Error).message}`)
            // Do NOT re-throw — always return XML 200
        }
        this.sendEmptyXml(res)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //   EP2: POLL INPUT  —  /api/ivr/poll
    //   User enters a pole keypad_id. Creates a complaint if found.
    //   Always returns XML 200 so Exotel flow is not broken.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @Post('poll')
    async handlePollInputPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        return this.handlePollInput(data, res)
    }

    @Get('poll')
    async handlePollInputGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        return this.handlePollInput(data, res)
    }

    private async handlePollInput(data: IvrCallbackDto, res: Response): Promise<void> {
        try {
            this.logger.log(`[EP2] Poll input received: CallSid=${data.CallSid ?? 'N/A'}`)
            await this.ivrService.handlePollInput(data)
        } catch (err) {
            this.logger.error(`[EP2] Error (non-fatal): ${(err as Error).message}`)
            // On error, return XML 200 instead of crashing
        }
        this.sendEmptyXml(res)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //   EP3: VOICE COMPLAINT  —  /api/ivr/voice-complaint
    //   Exotel sends the recording URL after the user leaves a voice note.
    //   Transcribes → extracts landmark → matches pole → creates complaint.
    //   Always returns XML 200 (no 404) to avoid Exotel "Phase 2 URL 404" errors.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @Post('voice-complaint')
    async handleVoiceComplaintPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        return this.handleVoiceComplaint(data, res)
    }

    @Get('voice-complaint')
    async handleVoiceComplaintGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        return this.handleVoiceComplaint(data, res)
    }

    private async handleVoiceComplaint(data: IvrCallbackDto, res: Response): Promise<void> {
        try {
            this.logger.log(`[EP3] Voice complaint received: CallSid=${data.CallSid ?? 'N/A'}`)

            const recordingUrl = this.normalizeRecordingUrl(data)

            if (!recordingUrl || !data.CallSid) {
                this.logger.warn('[EP3] Missing CallSid or RecordingUrl — returning empty XML')
                this.sendEmptyXml(res)
                return
            }

            // Exotel sends a callback BEFORE the recording is ready.
            // Only process when confirmed ready to avoid fetch errors.
            if (data.ProcessStatus && data.ProcessStatus !== 'ready') {
                this.logger.log(`[EP3] Recording not ready (ProcessStatus=${data.ProcessStatus})`)
                this.sendEmptyXml(res)
                return
            }

            const ivrNumber = data.CallTo || data.To || ''

            const result = await this.voiceProcessing.processVoiceComplaint(
                data.CallSid,
                recordingUrl,
                ivrNumber
            )

            this.logger.log(
                `[EP3] Processed callback CallSid=${data.CallSid} attempt=${result.attemptNumber ?? 'n/a'} phase=${result.phase ?? 'n/a'}`
            )
            // For completed / manual_review / not_found, always return success XML.
            // Any "not_found" is treated as manual review on the backend side.
            this.sendSuccessXml(res)
            return

        } catch (err) {
            this.logger.error(`[EP3] Error (non-fatal): ${(err as Error).message}`)
            this.sendEmptyXml(res)
        }
    }
}
