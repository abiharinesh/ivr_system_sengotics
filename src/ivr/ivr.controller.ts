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

    private sendXml(res: Response): void {
        // Exotel expects a valid TwiML response. Empty <Response> tags can sometimes be treated as 404/invalid.
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>Complaint registered successfully</Say>\n</Response>`
        res.status(200).type('application/xml').send(xml)
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


    /**
     * Voice Complaint Endpoint — called by Exotel after a caller leaves a voice note.
     * The RecordingUrl is passed in the request body.
     * Returns 200 (empty XML) on success, 404 if the landmark couldn't be matched to any pole.
     * A 404 response tells Exotel the input was invalid, prompting the user to retry.
     */
    @Post('voice-complaint')
    async handleVoiceComplaintPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
        if (!data.RecordingUrl || !data.CallSid) {
            return res.status(HttpStatus.BAD_REQUEST).json({ message: 'Missing CallSid or RecordingUrl' })
        }

        // Exotel sends this callback BEFORE the recording is ready (ProcessStatus != 'ready').
        // Only process when the recording is confirmed ready to avoid fetch errors.
        if (data.ProcessStatus && data.ProcessStatus !== 'ready') {
            this.logger.log(`Recording not ready (ProcessStatus=${data.ProcessStatus}). Returning 200 to Exotel.`)
            return this.sendXml(res)
        }

        const result = await this.voiceProcessing.processVoiceComplaint(data.CallSid, data.RecordingUrl, data.To || '')

        if (result.status === 'not_found') {
            // 404 → Exotel knows landmark matching failed → triggers retry flow
            return res.status(HttpStatus.NOT_FOUND).json({ message: result.message || 'Landmark not matched to any pole' })
        }

        // For completed or manual_review, return success XML so the call flow continues
        this.sendXml(res)
    }

    @Get('voice-complaint')
    async handleVoiceComplaintGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
        if (!data.RecordingUrl || !data.CallSid) {
            return res.status(HttpStatus.BAD_REQUEST).json({ message: 'Missing CallSid or RecordingUrl' })
        }

        // Only process when recording is confirmed ready
        if (data.ProcessStatus && data.ProcessStatus !== 'ready') {
            this.logger.log(`Recording not ready (ProcessStatus=${data.ProcessStatus}). Returning 200 to Exotel.`)
            return this.sendXml(res)
        }

        const result = await this.voiceProcessing.processVoiceComplaint(data.CallSid, data.RecordingUrl, data.To || '')

        if (result.status === 'not_found') {
            return res.status(HttpStatus.NOT_FOUND).json({ message: result.message || 'Landmark not matched to any pole' })
        }

        this.sendXml(res)
    }
}
