import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

/** Maximum time (ms) to wait for audio download from Exotel. */
const AUDIO_PROXY_TIMEOUT_MS = 30_000;

/**
 * Reads for the Voice & IVR operations screen.
 *
 * Kept apart from `IvrService`, which handles the live call: that one is
 * driven by Exotel webhooks mid-conversation and must stay fast and
 * side-effect-free of anything the office does afterwards.
 */
@Injectable()
export class IvrOperationsService {
  private readonly logger = new Logger(IvrOperationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * Recorded citizen calls, newest first.
   *
   * A voice call carries the audio, the Tamil transcript and its English
   * translation. The complaint it produced is joined in because the first
   * question about any call is whether it turned into a ticket.
   */
  async listVoiceCalls(params: {
    tenantId: string;
    search?: string;
    status?: string;
    take: number;
  }) {
    const { search, status, take } = params;

    const calls = await this.prisma.voiceCall.findMany({
      where: {
        ...(status ? { processing_status: status } : {}),
        ...(search
          ? {
              OR: [
                { call_sid: { contains: search, mode: 'insensitive' } },
                { transcript: { contains: search, mode: 'insensitive' } },
                { transcript_english: { contains: search, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      orderBy: { created_at: 'desc' },
      take,
      select: {
        id: true,
        call_sid: true,
        audio_url: true,
        transcript: true,
        transcript_english: true,
        processing_status: true,
        confidence_score: true,
        attempt_number: true,
        created_at: true,
        complaints: {
          select: {
            id: true,
            status: true,
            complaint_type: true,
            category: true,
            description: true,
            urgency_level: true,
            org_unit: { select: { id: true, name: true, tenant_id: true } },
            ward: { select: { ward_number: true, name_en: true } },
          },
          take: 1,
        },
      },
    });

    // The caller's number lives on the IVR call, keyed by the same sid.
    const sids = calls.map((c) => c.call_sid).filter((s): s is string => s != null);
    const ivr = sids.length
      ? await this.prisma.ivrCall.findMany({
          where: { call_sid: { in: sids } },
          select: { call_sid: true, caller_number: true, call_to: true, call_start_time: true, tenant_id: true },
        })
      : [];
    const bySid = new Map(ivr.map((i) => [i.call_sid, i]));

    return calls.map((c) => {
      const complaint = c.complaints[0] ?? null;
      const meta = c.call_sid ? bySid.get(c.call_sid) : undefined;
      return {
        id: c.id,
        call_sid: c.call_sid,
        caller_number: meta?.caller_number ?? null,
        call_to: meta?.call_to ?? null,
        started_at: meta?.call_start_time ?? c.created_at,
        audio_url: c.audio_url,
        transcript: c.transcript,
        transcript_english: c.transcript_english,
        status: c.processing_status,
        confidence: c.confidence_score,
        attempt: c.attempt_number,
        created_at: c.created_at,
        complaint_id: complaint?.id ?? null,
        complaint_status: complaint?.status ?? null,
        complaint_category: complaint?.complaint_type ?? complaint?.category ?? null,
        complaint_description: complaint?.description ?? null,
        urgency: complaint?.urgency_level ?? null,
        org_unit_id: complaint?.org_unit?.id ?? null,
        org_unit_name: complaint?.org_unit?.name ?? null,
        ward_number: complaint?.ward?.ward_number ?? null,
        ward_name: complaint?.ward?.name_en ?? null,
        tenant_id: complaint?.org_unit?.tenant_id ?? meta?.tenant_id ?? null,
      };
    });
  }

  /**
   * The IVR interaction log: what the caller pressed and where the flow ended.
   */
  async listIvrCalls(params: { tenantId: string; search?: string; take: number }) {
    const { tenantId, search, take } = params;

    const calls = await this.prisma.ivrCall.findMany({
      where: {
        OR: [{ tenant_id: tenantId }, { tenant_id: null }],
        ...(search
          ? {
              AND: [
                {
                  OR: [
                    { call_sid: { contains: search, mode: 'insensitive' } },
                    { caller_number: { contains: search } },
                  ],
                },
              ],
            }
          : {}),
      },
      orderBy: { created_at: 'desc' },
      take,
      select: {
        call_sid: true,
        caller_number: true,
        call_to: true,
        call_start_time: true,
        call_end_time: true,
        service_selected: true,
        poll_entered: true,
        final_call_status: true,
        created_at: true,
        service_selections: {
          select: { service_option: true, received_at: true },
          orderBy: { received_at: 'asc' },
        },
      },
    });

    // Whether the call produced a ticket is tracked separately, on the state
    // machine row rather than on the call itself.
    const sids = calls.map((c) => c.call_sid);
    const states = sids.length
      ? await this.prisma.ivrCallState.findMany({
          where: { call_sid: { in: sids } },
          select: {
            call_sid: true,
            ward_id: true,
            ward_status: true,
            complaint_method: true,
            complaint_created: true,
            complaint_id: true,
            phase1_status: true,
            phase2_status: true,
            last_error: true,
          },
        })
      : [];
    const bySid = new Map(states.map((s) => [s.call_sid, s]));

    return calls.map((c) => {
      const state = bySid.get(c.call_sid);
      const seconds =
        c.call_start_time && c.call_end_time
          ? Math.max(
              0,
              Math.round(
                (c.call_end_time.getTime() - c.call_start_time.getTime()) / 1000,
              ),
            )
          : null;
      return {
        call_sid: c.call_sid,
        caller_number: c.caller_number,
        call_to: c.call_to,
        started_at: c.call_start_time ?? c.created_at,
        duration_seconds: seconds,
        service_selected: c.service_selected,
        selections: c.service_selections.map((s) => s.service_option).filter(Boolean),
        poll_entered: c.poll_entered,
        final_status: c.final_call_status,
        ward_id: state?.ward_id ?? null,
        ward_status: state?.ward_status ?? null,
        complaint_method: state?.complaint_method ?? null,
        complaint_created: state?.complaint_created ?? false,
        complaint_id: state?.complaint_id ?? null,
        phase1_status: state?.phase1_status ?? null,
        phase2_status: state?.phase2_status ?? null,
        last_error: state?.last_error ?? null,
      };
    });
  }

  /** Counters across the top of the screen. */
  async summary(tenantId: string) {
    const since = new Date(Date.now() - 30 * 86400000);

    const [total, recent, withTicket, failed, transcribed, avgConfidence] =
      await Promise.all([
        this.prisma.ivrCall.count({
          where: { OR: [{ tenant_id: tenantId }, { tenant_id: null }] },
        }),
        this.prisma.ivrCall.count({
          where: {
            OR: [{ tenant_id: tenantId }, { tenant_id: null }],
            created_at: { gte: since },
          },
        }),
        this.prisma.ivrCallState.count({ where: { complaint_created: true } }),
        this.prisma.ivrCallState.count({
          where: {
            OR: [{ phase1_status: 'failed' }, { phase2_status: 'failed' }],
          },
        }),
        this.prisma.voiceCall.count({
          where: { transcript: { not: null } },
        }),
        this.prisma.voiceCall.aggregate({ _avg: { confidence_score: true } }),
      ]);

    return {
      total_calls: total,
      calls_last_30_days: recent,
      complaints_raised: withTicket,
      // A call that reached a ticket without an agent is the number this
      // system exists to move.
      containment_pct: total === 0 ? 0 : Math.round((withTicket / total) * 100),
      failed_processing: failed,
      transcribed,
      avg_confidence: avgConfidence._avg.confidence_score
        ? Number(avgConfidence._avg.confidence_score.toFixed(2))
        : null,
    };
  }

  // ── Audio Proxy ─────────────────────────────────────────────────────────

  /**
   * Fetch the audio for a VoiceCall record, authenticating with Exotel
   * credentials if needed. Returns { buffer, contentType } so the
   * controller can stream it to the browser.
   */
  async getAudioStream(voiceCallId: number): Promise<{
    buffer: Buffer;
    contentType: string;
    audioUrl: string;
  }> {
    const vc = await this.prisma.voiceCall.findUnique({
      where: { id: voiceCallId },
      select: { audio_url: true },
    });

    if (!vc?.audio_url) {
      throw new NotFoundException(
        `VoiceCall #${voiceCallId} not found or has no audio`,
      );
    }

    const audioUrl = vc.audio_url;
    const headers: Record<string, string> = {};

    // Exotel recordings require Basic Auth
    const exotelApiKey = this.configService.get<string>('EXOTEL_API_KEY');
    const exotelApiToken = this.configService.get<string>('EXOTEL_API_TOKEN');

    if (
      exotelApiKey &&
      exotelApiToken &&
      audioUrl.includes('exotel')
    ) {
      const credentials = Buffer.from(
        `${exotelApiKey}:${exotelApiToken}`,
      ).toString('base64');
      headers['Authorization'] = `Basic ${credentials}`;
      this.logger.log(
        `[AudioProxy] Fetching with Exotel auth: ${audioUrl.slice(0, 80)}…`,
      );
    }

    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      AUDIO_PROXY_TIMEOUT_MS,
    );

    let response: Response;
    try {
      response = await fetch(audioUrl, {
        headers,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      throw new Error(
        `Audio fetch failed: HTTP ${response.status} ${response.statusText}`,
      );
    }

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    // Determine content type from response or URL
    let contentType =
      response.headers.get('content-type') || 'audio/mpeg';
    if (audioUrl.endsWith('.wav')) contentType = 'audio/wav';
    else if (audioUrl.endsWith('.ogg')) contentType = 'audio/ogg';

    return { buffer, contentType, audioUrl };
  }

  // ── Single Voice Call Detail ────────────────────────────────────────────

  async getVoiceCallDetail(voiceCallId: number) {
    const vc = await this.prisma.voiceCall.findUnique({
      where: { id: voiceCallId },
      select: {
        id: true,
        call_sid: true,
        audio_url: true,
        transcript: true,
        transcript_english: true,
        ai_extracted_json: true,
        processing_status: true,
        confidence_score: true,
        attempt_number: true,
        created_at: true,
        complaints: {
          select: {
            id: true,
            status: true,
            complaint_type: true,
            description: true,
            urgency_level: true,
            org_unit: { select: { id: true, name: true } },
          },
          take: 5,
        },
      },
    });

    if (!vc) {
      throw new NotFoundException(`VoiceCall #${voiceCallId} not found`);
    }

    // Enrich with caller info from IvrCall
    let callerNumber: string | null = null;
    let callStartTime: Date | null = null;
    if (vc.call_sid) {
      const ivrCall = await this.prisma.ivrCall.findUnique({
        where: { call_sid: vc.call_sid },
        select: { caller_number: true, call_start_time: true },
      });
      callerNumber = ivrCall?.caller_number ?? null;
      callStartTime = ivrCall?.call_start_time ?? null;
    }

    return {
      id: vc.id,
      call_sid: vc.call_sid,
      caller_number: callerNumber,
      started_at: callStartTime ?? vc.created_at,
      audio_url: vc.audio_url,
      has_audio: !!vc.audio_url,
      transcript: vc.transcript,
      transcript_english: vc.transcript_english,
      ai_extracted_json: vc.ai_extracted_json,
      status: vc.processing_status,
      confidence: vc.confidence_score,
      attempt: vc.attempt_number,
      created_at: vc.created_at,
      complaints: vc.complaints.map((c) => ({
        id: c.id,
        status: c.status,
        complaint_type: c.complaint_type,
        description: c.description,
        urgency_level: c.urgency_level,
        org_unit: c.org_unit,
      })),
    };
  }
}
