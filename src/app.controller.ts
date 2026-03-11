import { Controller, Get, Post, Body, Query, Res, Req, Logger } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { AppService } from './app.service';
import { PrismaService } from './prisma/prisma.service';
import { VoiceProcessingService } from './voice-processing/voice-processing.service';
import { IvrCallbackDto } from './ivr/dto/ivr-callback.dto';
import type { Request, Response } from 'express'

@Controller()
export class AppController {
  private readonly logger = new Logger(AppController.name)

  constructor(
    private readonly appService: AppService,
    private readonly prisma: PrismaService,
    private readonly voiceProcessing: VoiceProcessingService
  ) { }

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('health/db')
  async checkDatabase() {
    try {
      await this.prisma.getPool().query('SELECT 1');
      return { status: 'ok', message: 'Database Connected' };
    } catch (error) {
      return { status: 'error', message: 'Database Connection Failed', error: error.message };
    }
  }

  @SkipThrottle()
  @Get('test')
  async ivrTestGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
    return this.handleIvrTest(data, res)
  }

  @SkipThrottle()
  @Post('test')
  async ivrTestPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
    return this.handleIvrTest(data, res)
  }

  private sendSuccessXml(res: Response): void {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>உங்கள் புகார் பதிவு செய்யப்பட்டுள்ளது. நன்றி.</Say>\n</Response>`
    res.status(200).type('application/xml').send(xml)
  }

  private sendEmptyXml(res: Response): void {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response></Response>`
    res.status(200).type('application/xml').send(xml)
  }

  private normalizeRecordingUrl(data: IvrCallbackDto): string {
    return data.RecordingUrl || data.recording_url || data.recordingUrl || data.recording || ''
  }

  private async handleIvrTest(data: IvrCallbackDto, res: Response): Promise<void> {
    try {
      const callSid = data.CallSid || ''
      const recordingUrl = this.normalizeRecordingUrl(data)
      const processStatus = data.ProcessStatus
      const ivrNumber = data.CallTo || data.To || ''

      this.logger.log(`[TEST] Callback received CallSid=${callSid || 'N/A'}`)

      if (!callSid || !recordingUrl) {
        this.logger.warn('[TEST] Missing CallSid/RecordingUrl')
        this.sendEmptyXml(res)
        return
      }

      if (processStatus && processStatus !== 'ready') {
        this.logger.log(`[TEST] Recording not ready (ProcessStatus=${processStatus})`)
        this.sendEmptyXml(res)
        return
      }

      const result = await this.voiceProcessing.processVoiceComplaint(callSid, recordingUrl, ivrNumber)
      this.logger.log(`[TEST] Processed attempt=${result.attemptNumber ?? 'n/a'} phase=${result.phase ?? 'n/a'}`)
      this.sendSuccessXml(res)
    } catch (error: any) {
      this.logger.error(`[TEST] Non-fatal error: ${error?.message || String(error)}`)
      this.sendEmptyXml(res)
    }
  }

  @SkipThrottle()
  @Get('worker/process-phase2')
  async processPendingPhase2(@Query('token') token?: string, @Req() req?: Request) {
    const requiredToken = process.env.IVR_CRON_TOKEN || process.env.CRON_SECRET
    const authHeader = req?.headers?.authorization
    const bearerToken = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : undefined

    if (requiredToken && token !== requiredToken && bearerToken !== requiredToken) {
      return { ok: false, message: 'Unauthorized token' }
    }

    const result = await this.voiceProcessing.processPendingPhase2(20)
    return { ok: true, ...result }
  }
}
