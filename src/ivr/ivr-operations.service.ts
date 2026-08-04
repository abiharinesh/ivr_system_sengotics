import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Reads for the Voice & IVR operations screen.
 *
 * Kept apart from `IvrService`, which handles the live call: that one is
 * driven by Exotel webhooks mid-conversation and must stay fast and
 * side-effect-free of anything the office does afterwards.
 */
@Injectable()
export class IvrOperationsService {
  constructor(private readonly prisma: PrismaService) {}

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
            category: true,
            urgency_level: true,
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
          select: { call_sid: true, caller_number: true, call_start_time: true },
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
        complaint_category: complaint?.category ?? null,
        urgency: complaint?.urgency_level ?? null,
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
}
