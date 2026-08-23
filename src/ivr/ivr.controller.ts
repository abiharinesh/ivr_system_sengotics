import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  Res,
  UseFilters,
  Logger,
} from '@nestjs/common';
import { IvrService } from './ivr.service';
import { IvrCallbackDto } from './dto/ivr-callback.dto';
import type { Response } from 'express';
import { IvrExceptionFilter } from './ivr-exception.filter';
import { VoiceProcessingService } from '../voice-processing/voice-processing.service';
import { WardIdentificationService } from '../voice-processing/ward-identification.service';

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
  private readonly logger = new Logger(IvrController.name);

  constructor(
    private readonly ivrService: IvrService,
    private readonly voiceProcessing: VoiceProcessingService,
    private readonly wardIdentification: WardIdentificationService,
  ) {}

  // ── XML Response Helpers ────────────────────────────────────────────────

  private sendEmptyXml(res: Response): void {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response></Response>`;
    res.status(200).type('application/xml').send(xml);
  }

  private sendSuccessXml(res: Response): void {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>உங்கள் புகார் பதிவு செய்யப்பட்டுள்ளது. நன்றி.</Say>\n</Response>`;
    res.status(200).type('application/xml').send(xml);
  }

  private normalizeRecordingUrl(data: IvrCallbackDto): string {
    return (
      data.RecordingUrl ||
      data.recording_url ||
      data.recordingUrl ||
      data.recording ||
      ''
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   EP1: SERVICE SELECTION  —  /api/ivr/service
  //   User presses a digit (1/2/3) to choose a service type.
  //   Always returns XML 200 so the Exotel flow continues.
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @Post('service')
  async handleServiceSelectionPost(
    @Body() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handleServiceSelection(data, res);
  }

  @Get('service')
  async handleServiceSelectionGet(
    @Query() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handleServiceSelection(data, res);
  }

  private async handleServiceSelection(
    data: IvrCallbackDto,
    res: Response,
  ): Promise<void> {
    try {
      this.logger.log(
        `[EP1] Service selection received: CallSid=${data.CallSid ?? 'N/A'}`,
      );
      await this.ivrService.handleServiceSelection(data);
    } catch (err) {
      this.logger.error(`[EP1] Error (non-fatal): ${(err as Error).message}`);
      // Do NOT re-throw — always return XML 200
    }
    this.sendEmptyXml(res);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   EP2: POLL INPUT  —  /api/ivr/poll
  //   User enters a pole keypad_id. Creates a complaint if found.
  //   Always returns XML 200 so Exotel flow is not broken.
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @Post('poll')
  async handlePollInputPost(
    @Body() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handlePollInput(data, res);
  }

  @Get('poll')
  async handlePollInputGet(
    @Query() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handlePollInput(data, res);
  }

  private async handlePollInput(
    data: IvrCallbackDto,
    res: Response,
  ): Promise<void> {
    try {
      this.logger.log(
        `[EP2] Poll input received: CallSid=${data.CallSid ?? 'N/A'}`,
      );
      await this.ivrService.handlePollInput(data);
    } catch (err) {
      this.logger.error(`[EP2] Error (non-fatal): ${(err as Error).message}`);
      // On error, return XML 200 instead of crashing
    }
    this.sendEmptyXml(res);
  }

  @Post('voice-match')
  async handleVoicePhase1Post(
    @Body() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handleVoicePhase1(data, res);
  }

  @Get('voice-match')
  async handleVoicePhase1Get(
    @Query() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handleVoicePhase1(data, res);
  }

  private async handleVoicePhase1(
    data: IvrCallbackDto,
    res: Response,
  ): Promise<void> {
    try {
      this.logger.log(
        `[EP3-P1] Voice phase1 received: CallSid=${data.CallSid ?? 'N/A'}`,
      );

      const recordingUrl = this.normalizeRecordingUrl(data);

      if (!recordingUrl || !data.CallSid) {
        this.logger.warn(
          '[EP3-P1] Missing CallSid or RecordingUrl — returning empty XML',
        );
        this.sendEmptyXml(res);
        return;
      }

      if (data.ProcessStatus && data.ProcessStatus !== 'ready') {
        this.logger.log(
          `[EP3-P1] Recording not ready (ProcessStatus=${data.ProcessStatus})`,
        );
        this.sendEmptyXml(res);
        return;
      }

      const ivrNumber = data.CallTo || data.To || '';
      const result = await this.voiceProcessing.processPhase1Voice(
        data.CallSid,
        recordingUrl,
        ivrNumber,
      );
      this.logger.log(
        `[EP3-P1] Processed CallSid=${data.CallSid} attempt=${result.attemptNumber ?? 'n/a'}`,
      );
      this.sendSuccessXml(res);
      return;
    } catch (err) {
      this.logger.error(
        `[EP3-P1] Error (non-fatal): ${(err as Error).message}`,
      );
      this.sendEmptyXml(res);
    }
  }

  @Post('voice-llm')
  async handleVoiceLlmPost(@Body() data: IvrCallbackDto, @Res() res: Response) {
    return this.handleVoiceLlm(data, res);
  }

  @Get('voice-llm')
  async handleVoiceLlmGet(@Query() data: IvrCallbackDto, @Res() res: Response) {
    return this.handleVoiceLlm(data, res);
  }

  private async handleVoiceLlm(
    data: IvrCallbackDto,
    res: Response,
  ): Promise<void> {
    try {
      this.logger.log(
        `[EP3-P2] Voice llm received: CallSid=${data.CallSid ?? 'N/A'}`,
      );

      const recordingUrl = this.normalizeRecordingUrl(data);
      if (!recordingUrl || !data.CallSid) {
        this.logger.warn(
          '[EP3-P2] Missing CallSid or RecordingUrl — returning empty XML',
        );
        this.sendEmptyXml(res);
        return;
      }

      const ivrNumber = data.CallTo || data.To || '';
      await this.voiceProcessing.acceptPhase2Llm(
        data.CallSid,
        recordingUrl,
        ivrNumber,
      );

      // Phase2 contract: immediate success response.
      this.sendSuccessXml(res);
    } catch (err) {
      this.logger.error(
        `[EP3-P2] Error (non-fatal): ${(err as Error).message}`,
      );
      this.sendEmptyXml(res);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   EP-WARD: WARD IDENTIFICATION  —  /api/ivr/ward-identify
  //   User speaks which ward they are from. Backend transcribes and
  //   identifies the ward. Returns 200 if identified, 404 if not found
  //   (so Exotel can retry the question).
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @Post('ward-identify')
  async handleWardIdentifyPost(
    @Body() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handleWardIdentify(data, res);
  }

  @Get('ward-identify')
  async handleWardIdentifyGet(
    @Query() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handleWardIdentify(data, res);
  }

  private async handleWardIdentify(
    data: IvrCallbackDto,
    res: Response,
  ): Promise<void> {
    try {
      this.logger.log(
        `[EP-WARD] Ward identification received: CallSid=${data.CallSid ?? 'N/A'}`,
      );

      const recordingUrl = this.normalizeRecordingUrl(data);

      if (!recordingUrl || !data.CallSid) {
        this.logger.warn(
          '[EP-WARD] Missing CallSid or RecordingUrl — returning empty XML',
        );
        this.sendEmptyXml(res);
        return;
      }

      if (data.ProcessStatus && data.ProcessStatus !== 'ready') {
        this.logger.log(
          `[EP-WARD] Recording not ready (ProcessStatus=${data.ProcessStatus})`,
        );
        this.sendEmptyXml(res);
        return;
      }

      const ivrNumber = data.CallTo || data.To || '';

      // ── Timeout guard: respond before Exotel's 5s Passthru timeout ──
      const WARD_TIMEOUT_MS = 4500;
      const timeoutPromise = new Promise<null>((resolve) =>
        setTimeout(() => resolve(null), WARD_TIMEOUT_MS),
      );

      const identifyPromise = this.wardIdentification.identifyWardFromAudio(
        recordingUrl,
        ivrNumber,
      );

      const result = await Promise.race([identifyPromise, timeoutPromise]);

      if (result === null) {
        this.logger.warn(
          `[EP-WARD] ⏱️ Ward identification timed out after ${WARD_TIMEOUT_MS}ms — returning 404 to retry`,
        );
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>மன்னிக்கவும், மீண்டும் முயற்சிக்கவும்.</Say>\n</Response>`;
        res.status(404).type('application/xml').send(xml);
        return;
      }

      // Save ward identification result in IvrCallState
      await this.ivrService.handleWardIdentification(
        data.CallSid,
        result,
        data,
      );

      if (result.wardId && result.confidence >= 0.3) {
        this.logger.log(
          `[EP-WARD] ✅ Ward identified: ${result.wardNumber} (${result.wardName}) confidence=${result.confidence}`,
        );
        // 200 = ward found → Exotel continues flow
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>உங்கள் வார்டு அடையாளம் காணப்பட்டது. வார்டு எண் ${result.wardNumber}.</Say>\n</Response>`;
        res.status(200).type('application/xml').send(xml);
        return;
      } else {
        this.logger.warn(
          `[EP-WARD] Ward not identified. confidence=${result.confidence}, reason=${result.reason}`,
        );
        // 404 = ward not found → Exotel retries the question
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n    <Say>மன்னிக்கவும், வார்டை கண்டுபிடிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.</Say>\n</Response>`;
        res.status(404).type('application/xml').send(xml);
        return;
      }
    } catch (err) {
      this.logger.error(
        `[EP-WARD] Error (non-fatal): ${(err as Error).message}`,
      );
      this.sendEmptyXml(res);
    }
  }


  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //   EP-METHOD: COMPLAINT METHOD SELECTION  —  /api/ivr/complaint-method
  //   User presses 1 (keypad pole ID) or 2 (voice complaint).
  //   Always returns XML 200.
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @Post('complaint-method')
  async handleComplaintMethodPost(
    @Body() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handleComplaintMethod(data, res);
  }

  @Get('complaint-method')
  async handleComplaintMethodGet(
    @Query() data: IvrCallbackDto,
    @Res() res: Response,
  ) {
    return this.handleComplaintMethod(data, res);
  }

  private async handleComplaintMethod(
    data: IvrCallbackDto,
    res: Response,
  ): Promise<void> {
    try {
      this.logger.log(
        `[EP-METHOD] Complaint method selection: CallSid=${data.CallSid ?? 'N/A'}`,
      );
      await this.ivrService.handleComplaintMethod(data);
    } catch (err) {
      this.logger.error(
        `[EP-METHOD] Error (non-fatal): ${(err as Error).message}`,
      );
    }
    this.sendEmptyXml(res);
  }
}
