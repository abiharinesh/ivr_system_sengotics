import { Controller, Get, Param, ParseIntPipe, Query, Req, Res, UseGuards, Logger } from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { IvrOperationsService } from './ivr-operations.service';

interface AuthReq {
  user: { id: number; role: string; tenant_id: string; org_unit_id: number | null };
}

/**
 * The read side of Voice & IVR, for the office rather than for Exotel.
 *
 * The rest of `IvrController` is webhook surface — the endpoints the telephony
 * provider posts to mid-call. Nothing served the operations screen, so it
 * rendered rows generated from a loop counter (`IVR-${4200 + index}`) while
 * 220 real calls sat in the database unread.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(
  'super_admin',
  'panchayat_admin',
  'municipal_commissioner',
  'deputy_commissioner',
  'executive_officer',
  'i3c_staff',
)
@Controller('api/ivr-operations')
export class IvrOperationsController {
  private readonly logger = new Logger(IvrOperationsController.name);

  constructor(private readonly service: IvrOperationsService) {}

  /** GET /api/ivr-operations/voice-calls — recorded calls and their transcripts. */
  @Get('voice-calls')
  voiceCalls(
    @Req() req: AuthReq,
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('take') take?: string,
  ) {
    return this.service.listVoiceCalls({
      tenantId: req.user.tenant_id,
      search: search?.trim() || undefined,
      status: status?.trim() || undefined,
      take: Math.min(Number(take) || 50, 200),
    });
  }

  /** GET /api/ivr-operations/voice-calls/:id — single voice call with full detail. */
  @Get('voice-calls/:id')
  voiceCallDetail(@Param('id', ParseIntPipe) id: number) {
    return this.service.getVoiceCallDetail(id);
  }

  /** GET /api/ivr-operations/calls — the IVR interaction log. */
  @Get('calls')
  calls(
    @Req() req: AuthReq,
    @Query('search') search?: string,
    @Query('take') take?: string,
  ) {
    return this.service.listIvrCalls({
      tenantId: req.user.tenant_id,
      search: search?.trim() || undefined,
      take: Math.min(Number(take) || 50, 200),
    });
  }

  /** GET /api/ivr-operations/summary — the counters above both lists. */
  @Get('summary')
  summary(@Req() req: AuthReq) {
    return this.service.summary(req.user.tenant_id);
  }

  /**
   * GET /api/ivr-operations/audio-proxy/:voiceCallId
   *
   * Streams the audio recording for a VoiceCall through the backend,
   * adding Exotel Basic Auth credentials so the browser can play it
   * without needing direct access to the Exotel API.
   */
  @Get('audio-proxy/:voiceCallId')
  async audioProxy(
    @Param('voiceCallId', ParseIntPipe) voiceCallId: number,
    @Res() res: Response,
  ) {
    try {
      const { buffer, contentType } =
        await this.service.getAudioStream(voiceCallId);

      res.setHeader('Content-Type', contentType);
      res.setHeader('Content-Length', buffer.length);
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader(
        'Cache-Control',
        'private, max-age=3600',
      );
      res.send(buffer);
    } catch (err) {
      this.logger.error(
        `[AudioProxy] Error streaming audio for VoiceCall #${voiceCallId}: ${(err as Error).message}`,
      );
      if (!res.headersSent) {
        const status = (err as any)?.status ?? 500;
        res.status(status).json({
          error: 'Audio proxy failed',
          message: (err as Error).message,
        });
      }
    }
  }
}

