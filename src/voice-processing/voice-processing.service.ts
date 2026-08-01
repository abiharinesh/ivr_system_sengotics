import { Injectable, Logger } from '@nestjs/common';
import { PrismaService, PrismaTx } from '../prisma/prisma.service';
import { VoiceToTextService } from './voice-to-text.service';
import {
  LocationExtractionService,
  ExtractedLocation,
} from './location-extraction.service';
import { GeoMatchingService } from './geo-matching.service';

const MIN_CONFIDENCE = 0.15;
const PHASE1_WAIT_MAX_MS = 45_000;
const PHASE1_WAIT_STEP_MS = 2000;

export type VoiceProcessingStatus = 'completed' | 'manual_review' | 'not_found';

export interface VoiceProcessingResult {
  success: boolean;
  status: VoiceProcessingStatus;
  complaintId?: number;
  message?: string;
  attemptNumber?: number;
  phase?: 1 | 2;
}

type PhaseKind = 'phase1' | 'phase2';

@Injectable()
export class VoiceProcessingService {
  private readonly logger = new Logger(VoiceProcessingService.name);

  constructor(
    private prisma: PrismaService,
    private voiceToText: VoiceToTextService,
    private locationExtraction: LocationExtractionService,
    private geoMatching: GeoMatchingService,
  ) {}

  async processPhase1Voice(
    callSid: string,
    audioUrl: string,
    ivrNumber: string,
  ): Promise<VoiceProcessingResult> {
    this.logger.log(`[Phase1] Received callback CallSid=${callSid}`);
    const reg = await this.registerPhaseAttempt(callSid, audioUrl, 'phase1');

    if (reg.isDuplicate) {
      return {
        success: true,
        status: 'completed',
        attemptNumber: reg.attemptNumber,
        phase: 1,
        message: 'Duplicate phase1 callback ignored',
      };
    }

    try {
      const result = await this.runPhase1Pipeline(
        reg.voiceCallId,
        callSid,
        audioUrl,
        ivrNumber,
      );
      return { ...result, attemptNumber: reg.attemptNumber, phase: 1 };
    } catch (err) {
      await this.safeUpdateStatus(reg.voiceCallId, 'failed');
      await this.prisma.callState.update({
        where: { call_sid: callSid },
        data: { phase1_status: 'failed', last_error: (err as Error).message },
      });
      return {
        success: false,
        status: 'not_found',
        attemptNumber: reg.attemptNumber,
        phase: 1,
        message: 'Phase1 failed',
      };
    }
  }

  async acceptPhase2Llm(
    callSid: string,
    audioUrl: string,
    ivrNumber: string,
  ): Promise<VoiceProcessingResult> {
    this.logger.log(`[Phase2] Accepted callback CallSid=${callSid}`);
    const reg = await this.registerPhaseAttempt(callSid, audioUrl, 'phase2');

    if (reg.isDuplicate) {
      return {
        success: true,
        status: 'completed',
        attemptNumber: reg.attemptNumber,
        phase: 2,
        message: 'Duplicate phase2 callback ignored',
      };
    }

    this.runPhase2EnrichmentOnly(
      reg.voiceCallId,
      callSid,
      audioUrl,
      ivrNumber,
    ).catch(async (err) => {
      this.logger.error(
        `[Phase2] Background failure for ${callSid}: ${(err as Error).message}`,
      );
      await this.safeUpdateStatus(reg.voiceCallId, 'failed');
      await this.prisma.callState.update({
        where: { call_sid: callSid },
        data: { phase2_status: 'failed', last_error: (err as Error).message },
      });
    });

    return {
      success: true,
      status: 'completed',
      attemptNumber: reg.attemptNumber,
      phase: 2,
      message: 'Phase2 accepted and queued',
    };
  }

  async processPendingPhase2Llm(
    limit = 10,
  ): Promise<{ scanned: number; processed: number; skipped: number }> {
    const states = await this.prisma.callState.findMany({
      where: {
        phase2_status: { in: ['queued', 'processing'] },
        phase2_voice_call_id: { not: null },
      },
      orderBy: { updated_at: 'asc' },
      take: limit,
    });

    let processed = 0;
    let skipped = 0;

    for (const state of states) {
      if (!state.phase2_voice_call_id) {
        skipped++;
        continue;
      }

      const phase2Row = await this.prisma.voiceCall.findUnique({
        where: { id: state.phase2_voice_call_id },
        select: {
          id: true,
          audio_url: true,
          processing_status: true,
          call_sid: true,
        },
      });

      if (!phase2Row?.audio_url || !phase2Row.call_sid) {
        skipped++;
        continue;
      }

      if (
        ['completed', 'manual_review', 'superseded'].includes(
          phase2Row.processing_status,
        )
      ) {
        skipped++;
        continue;
      }

      const ivrNumber = await this.getIvrNumberByCallSid(state.call_sid);
      try {
        await this.runPhase2EnrichmentOnly(
          phase2Row.id,
          state.call_sid,
          phase2Row.audio_url,
          ivrNumber,
        );
        processed++;
      } catch {
        skipped++;
      }
    }

    return { scanned: states.length, processed, skipped };
  }

  private async runPhase1Pipeline(
    voiceCallId: number,
    callSid: string,
    audioUrl: string,
    ivrNumber: string,
  ): Promise<VoiceProcessingResult> {
    const transcript = await this.voiceToText.transcribeAudio(audioUrl, 0);
    const transcriptEnglish = transcript
      ? await this.fastTranslateToEnglish(transcript)
      : '';

    await this.prisma.voiceCall.update({
      where: { id: voiceCallId },
      data: {
        transcript: transcript || '',
        transcript_english: transcriptEnglish || '',
      },
    });

    if (!transcript?.trim()) {
      await this.safeUpdateStatus(voiceCallId, 'not_found');
      await this.prisma.callState.update({
        where: { call_sid: callSid },
        data: { phase1_status: 'not_found' },
      });
      return {
        success: false,
        status: 'not_found',
        message: 'Phase1 empty transcript',
      };
    }

    const panchayat =
      await this.geoMatching.findPanchayatByIvrNumber(ivrNumber);
    if (!panchayat) {
      await this.safeUpdateStatus(voiceCallId, 'not_found');
      await this.prisma.callState.update({
        where: { call_sid: callSid },
        data: { phase1_status: 'not_found' },
      });
      return { success: false, status: 'not_found', message: 'No panchayat' };
    }

    let poleId: number | null = null;
    let pipelineId: number | null = null;
    const tankId: number | null = null;

    let complaintType = 'street_light';
    const lowerTrans = transcriptEnglish.toLowerCase();
    if (
      lowerTrans.includes('leak') ||
      lowerTrans.includes('pipe') ||
      lowerTrans.includes('water') ||
      lowerTrans.includes('தண்ணீர்') ||
      lowerTrans.includes('கசிவு')
    ) {
      complaintType = 'water_leak';
      pipelineId = await this.geoMatching.findNearestPipelineSegment(
        panchayat.id,
        transcriptEnglish,
      );
    } else {
      poleId = await this.geoMatching.strictMatchPole(
        panchayat.id,
        transcriptEnglish,
      );
    }

    if (!poleId && !pipelineId) {
      await this.safeUpdateStatus(voiceCallId, 'not_found');
      await this.prisma.callState.update({
        where: { call_sid: callSid },
        data: { phase1_status: 'not_found' },
      });
      return {
        success: false,
        status: 'not_found',
        message: 'No strict asset match',
      };
    }

    const extracted: ExtractedLocation = {
      village: panchayat.name,
      landmark: transcript,
      landmark_english: transcriptEnglish,
      direction: 'near',
      complaint_type: complaintType,
      call_summary: transcriptEnglish,
      caller_language: transcript !== transcriptEnglish ? 'tamil' : 'english',
      caller_emotion: 'calm',
      urgency_level: 'medium',
      confidence_score: 1,
    };

    await this.prisma.voiceCall.update({
      where: { id: voiceCallId },
      data: {
        ai_extracted_json: extracted as any,
        confidence_score: 1,
        processing_status: 'completed',
      },
    });

    const complaint = await this.finalizeComplaintFromPhase1(
      callSid,
      voiceCallId,
      poleId,
      pipelineId,
      tankId,
      panchayat.id,
      extracted,
      audioUrl,
    );

    if (!complaint) {
      return {
        success: true,
        status: 'completed',
        message: 'Complaint already finalized for call',
      };
    }

    this.enrichInBackground(
      complaint.id,
      voiceCallId,
      transcriptEnglish,
      panchayat.id,
    ).catch(() => {});
    return { success: true, status: 'completed', complaintId: complaint.id };
  }

  private async runPhase2EnrichmentOnly(
    voiceCallId: number,
    callSid: string,
    audioUrl: string,
    ivrNumber: string,
  ): Promise<void> {
    await this.safeUpdateStatus(voiceCallId, 'processing');
    await this.prisma.callState.update({
      where: { call_sid: callSid },
      data: { phase2_status: 'processing' },
    });

    const transcript = await this.voiceToText.transcribeAudio(audioUrl, 0);
    const transcriptEnglish = transcript
      ? await this.fastTranslateToEnglish(transcript)
      : '';

    await this.prisma.voiceCall.update({
      where: { id: voiceCallId },
      data: {
        transcript: transcript || '',
        transcript_english: transcriptEnglish || '',
      },
    });

    const state = await this.prisma.callState.findUnique({
      where: { call_sid: callSid },
    });
    if (!state) return;

    if (state.complaint_created && state.complaint_id) {
      if (transcriptEnglish.trim()) {
        await this.enrichExistingComplaintWithPhase2(
          state.complaint_id,
          transcript,
          transcriptEnglish,
        );
      }
      await this.safeUpdateStatus(voiceCallId, 'completed');
      await this.prisma.callState.update({
        where: { call_sid: callSid },
        data: { phase2_status: 'enriched' },
      });
      return;
    }

    const phase1Data = await this.waitForPhase1VoiceCall(
      state.phase1_voice_call_id,
      callSid,
    );
    const panchayat =
      await this.geoMatching.findPanchayatByIvrNumber(ivrNumber);

    if (!panchayat) {
      await this.createManualReviewComplaint(
        callSid,
        voiceCallId,
        audioUrl,
        undefined,
        transcript,
        transcriptEnglish,
      );
      return;
    }

    const combinedText = [
      phase1Data?.transcript,
      phase1Data?.transcript_english,
      transcript,
      transcriptEnglish,
    ]
      .filter(Boolean)
      .join('. ')
      .trim();

    if (!combinedText) {
      await this.createManualReviewComplaint(
        callSid,
        voiceCallId,
        audioUrl,
        panchayat.id,
        transcript,
        transcriptEnglish,
      );
      return;
    }

    const knownLandmarks = await this.geoMatching.getLandmarksForPanchayat(
      panchayat.id,
    );
    const extractedRaw = await this.locationExtraction.extractLocation(
      combinedText,
      knownLandmarks,
    );
    const extracted = this.withRequiredFields(extractedRaw, {
      village: panchayat.name,
      complaintType: 'street_light',
      callSummary: transcriptEnglish || combinedText,
    });

    await this.prisma.voiceCall.update({
      where: { id: voiceCallId },
      data: {
        ai_extracted_json: extracted as any,
        confidence_score: extracted.confidence_score,
      },
    });

    if (extracted.confidence_score < MIN_CONFIDENCE) {
      await this.createManualReviewComplaint(
        callSid,
        voiceCallId,
        audioUrl,
        panchayat.id,
        transcript,
        transcriptEnglish,
      );
      return;
    }

    const hints = [extracted.landmark_english, extracted.landmark].filter(
      Boolean,
    );
    let poleId: number | null = null;
    let pipelineId: number | null = null;
    let tankId: number | null = null;

    if (extracted.complaint_type === 'water_leak') {
      pipelineId = await this.geoMatching.findNearestPipelineSegment(
        panchayat.id,
        hints,
      );
    } else if (extracted.complaint_type === 'water_supply_shortage') {
      tankId = await this.geoMatching.findNearestWaterTank(panchayat.id, hints);
    } else {
      poleId = await this.geoMatching.findNearestPole(panchayat.id, hints);
    }

    if (!poleId && !pipelineId && !tankId) {
      await this.createManualReviewComplaint(
        callSid,
        voiceCallId,
        audioUrl,
        panchayat.id,
        transcript,
        transcriptEnglish,
      );
      return;
    }

    await this.finalizeComplaintFromPhase2(
      callSid,
      voiceCallId,
      poleId,
      pipelineId,
      tankId,
      panchayat.id,
      extracted,
      audioUrl,
    );
  }

  private async registerPhaseAttempt(
    callSid: string,
    audioUrl: string,
    phase: PhaseKind,
  ): Promise<{
    voiceCallId: number;
    attemptNumber: number;
    isDuplicate: boolean;
  }> {
    return this.prisma.$transaction(
      async (rawTx) => {
        const tx = rawTx as PrismaTx;
        const duplicate = await tx.voiceCall.findFirst({
          where: { call_sid: callSid, audio_url: audioUrl },
          orderBy: { id: 'desc' },
          select: { id: true, attempt_number: true },
        });

        if (duplicate) {
          return {
            voiceCallId: duplicate.id,
            attemptNumber: duplicate.attempt_number,
            isDuplicate: true,
          };
        }

        const latest = await tx.voiceCall.findFirst({
          where: { call_sid: callSid },
          orderBy: { attempt_number: 'desc' },
          select: { attempt_number: true },
        });
        const attemptNumber = (latest?.attempt_number ?? 0) + 1;

        const voiceCall = await tx.voiceCall.create({
          data: {
            call_sid: callSid,
            audio_url: audioUrl,
            attempt_number: attemptNumber,
            processing_status: phase === 'phase2' ? 'queued' : 'processing',
          },
          select: { id: true },
        });

        await tx.callState.upsert({
          where: { call_sid: callSid },
          create: {
            call_sid: callSid,
            phase1_status: phase === 'phase1' ? 'processing' : 'pending',
            phase2_status: phase === 'phase2' ? 'queued' : 'pending',
            phase1_voice_call_id: phase === 'phase1' ? voiceCall.id : null,
            phase2_voice_call_id: phase === 'phase2' ? voiceCall.id : null,
          },
          update:
            phase === 'phase1'
              ? {
                  phase1_status: 'processing',
                  phase1_voice_call_id: voiceCall.id,
                }
              : { phase2_status: 'queued', phase2_voice_call_id: voiceCall.id },
        });

        return { voiceCallId: voiceCall.id, attemptNumber, isDuplicate: false };
      },
      { isolationLevel: 'Serializable' },
    );
  }

  private async finalizeComplaintFromPhase1(
    callSid: string,
    voiceCallId: number,
    poleId: number | null,
    pipelineId: number | null,
    tankId: number | null,
    panchayatId: number,
    extracted: ExtractedLocation,
    audioUrl: string,
  ): Promise<{ id: number } | null> {
    return this.prisma.$transaction(async (rawTx) => {
      const tx = rawTx as PrismaTx;
      const state = await tx.callState.findUnique({
        where: { call_sid: callSid },
      });
      if (state?.complaint_created) {
        await tx.voiceCall.update({
          where: { id: voiceCallId },
          data: { processing_status: 'superseded' },
        });
        return null;
      }

      const complaint = await tx.complaint.create({
        data: {
          voice_call_id: voiceCallId,
          pole_id: poleId,
          pipeline_id: pipelineId,
          tank_id: tankId,
          panchayat_id: panchayatId,
          complaint_type: extracted.complaint_type || 'street_light',
          description:
            extracted.call_summary ||
            extracted.landmark_english ||
            'Voice complaint',
          caller_language: extracted.caller_language,
          caller_emotion: extracted.caller_emotion,
          urgency_level: extracted.urgency_level,
          audio_url: audioUrl,
          status: 'pending',
        },
        select: { id: true },
      });

      await tx.callState.update({
        where: { call_sid: callSid },
        data: {
          complaint_created: true,
          complaint_id: complaint.id,
          phase1_status: 'completed',
          phase2_status: 'skipped',
          finalized_at: new Date(),
        },
      });

      await tx.voiceCall.update({
        where: { id: voiceCallId },
        data: { processing_status: 'completed' },
      });
      return complaint;
    });
  }

  private async finalizeComplaintFromPhase2(
    callSid: string,
    voiceCallId: number,
    poleId: number | null,
    pipelineId: number | null,
    tankId: number | null,
    panchayatId: number,
    extracted: ExtractedLocation,
    audioUrl: string,
  ): Promise<void> {
    await this.prisma.$transaction(async (rawTx) => {
      const tx = rawTx as PrismaTx;
      const state = await tx.callState.findUnique({
        where: { call_sid: callSid },
      });
      if (state?.complaint_created) {
        await tx.voiceCall.update({
          where: { id: voiceCallId },
          data: { processing_status: 'completed' },
        });
        await tx.callState.update({
          where: { call_sid: callSid },
          data: { phase2_status: 'enriched' },
        });
        return;
      }

      const complaint = await tx.complaint.create({
        data: {
          voice_call_id: voiceCallId,
          pole_id: poleId,
          pipeline_id: pipelineId,
          tank_id: tankId,
          panchayat_id: panchayatId,
          complaint_type: extracted.complaint_type || 'street_light',
          description:
            extracted.call_summary ||
            extracted.landmark_english ||
            'Voice complaint',
          caller_language: extracted.caller_language,
          caller_emotion: extracted.caller_emotion,
          urgency_level: extracted.urgency_level,
          audio_url: audioUrl,
          status: 'pending',
        },
        select: { id: true },
      });

      await tx.callState.update({
        where: { call_sid: callSid },
        data: {
          complaint_created: true,
          complaint_id: complaint.id,
          phase2_status: 'completed',
          finalized_at: new Date(),
        },
      });
      await tx.voiceCall.update({
        where: { id: voiceCallId },
        data: { processing_status: 'completed' },
      });
    });
  }

  private async createManualReviewComplaint(
    callSid: string,
    voiceCallId: number,
    audioUrl: string,
    panchayatId: number | undefined,
    transcript: string,
    transcriptEnglish: string,
  ): Promise<void> {
    await this.prisma.$transaction(async (rawTx) => {
      const tx = rawTx as PrismaTx;
      await tx.voiceCall.update({
        where: { id: voiceCallId },
        data: {
          transcript: transcript || undefined,
          transcript_english: transcriptEnglish || undefined,
          processing_status: 'manual_review',
        },
      });

      const state = await tx.callState.findUnique({
        where: { call_sid: callSid },
      });
      if (state?.complaint_created) {
        await tx.callState.update({
          where: { call_sid: callSid },
          data: { phase2_status: 'enriched' },
        });
        return;
      }

      const complaint = await tx.complaint.create({
        data: {
          voice_call_id: voiceCallId,
          panchayat_id: panchayatId ?? null,
          complaint_type: 'street_light',
          description:
            transcriptEnglish || transcript || 'Auto flagged for review',
          caller_language: 'unknown',
          caller_emotion: 'unknown',
          urgency_level: 'unknown',
          audio_url: audioUrl,
          status: 'manual_review',
        },
        select: { id: true },
      });

      await tx.callState.update({
        where: { call_sid: callSid },
        data: {
          complaint_created: true,
          complaint_id: complaint.id,
          phase2_status: 'failed',
          finalized_at: new Date(),
        },
      });
    });
  }

  private async waitForPhase1VoiceCall(
    phase1VoiceCallId: number | null,
    callSid: string,
  ) {
    const start = Date.now();

    while (Date.now() - start < PHASE1_WAIT_MAX_MS) {
      const row = phase1VoiceCallId
        ? await this.prisma.voiceCall.findUnique({
            where: { id: phase1VoiceCallId },
            select: {
              transcript: true,
              transcript_english: true,
              processing_status: true,
            },
          })
        : await this.prisma.voiceCall.findFirst({
            where: { call_sid: callSid, attempt_number: 1 },
            select: {
              transcript: true,
              transcript_english: true,
              processing_status: true,
            },
          });

      if (!row) {
        await new Promise((r) => setTimeout(r, PHASE1_WAIT_STEP_MS));
        continue;
      }
      if (row.processing_status !== 'processing') return row;
      await new Promise((r) => setTimeout(r, PHASE1_WAIT_STEP_MS));
    }

    return phase1VoiceCallId
      ? this.prisma.voiceCall.findUnique({
          where: { id: phase1VoiceCallId },
          select: {
            transcript: true,
            transcript_english: true,
            processing_status: true,
          },
        })
      : this.prisma.voiceCall.findFirst({
          where: { call_sid: callSid, attempt_number: 1 },
          select: {
            transcript: true,
            transcript_english: true,
            processing_status: true,
          },
        });
  }

  private async enrichInBackground(
    complaintId: number,
    voiceCallId: number,
    transcriptEnglish: string,
    panchayatId: number,
  ): Promise<void> {
    try {
      const knownLandmarks =
        await this.geoMatching.getLandmarksForPanchayat(panchayatId);
      const panchayat = await this.prisma.orgUnit.findUnique({
        where: { id: panchayatId },
        select: { name: true },
      });
      const extractedRaw = await this.locationExtraction.extractLocation(
        transcriptEnglish,
        knownLandmarks,
      );
      const extracted = this.withRequiredFields(extractedRaw, {
        village: panchayat?.name ?? '',
        complaintType: 'street_light',
        callSummary: transcriptEnglish,
      });
      await this.prisma.complaint.update({
        where: { id: complaintId },
        data: {
          complaint_type: extracted.complaint_type || 'street_light',
          description: extracted.call_summary || transcriptEnglish,
          caller_language: extracted.caller_language,
          caller_emotion: extracted.caller_emotion,
          urgency_level: extracted.urgency_level,
        },
      });
      await this.prisma.voiceCall.update({
        where: { id: voiceCallId },
        data: {
          ai_extracted_json: extracted as any,
          confidence_score: extracted.confidence_score,
        },
      });
    } catch (err) {
      this.logger.error(`[Phase1 enrich] ${(err as Error).message}`);
    }
  }

  private async enrichExistingComplaintWithPhase2(
    complaintId: number,
    transcript: string,
    transcriptEnglish: string,
  ): Promise<void> {
    const current = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
      select: { description: true },
    });

    if (
      !current?.description ||
      current.description.length < transcriptEnglish.length
    ) {
      await this.prisma.complaint.update({
        where: { id: complaintId },
        data: {
          description:
            transcriptEnglish ||
            transcript ||
            current?.description ||
            undefined,
        },
      });
    }
  }

  private async fastTranslateToEnglish(text: string): Promise<string> {
    let googleKey = process.env.GOOGLE_SPEECH_API_KEY;
    if (!googleKey) {
      try {
        const setting = await this.prisma.systemSettings.findUnique({
          where: { key: 'google_speech_api_key' },
        });
        googleKey = setting?.value ?? undefined;
      } catch {}
    }
    if (!googleKey) return text;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    try {
      const response = await fetch(
        `https://translation.googleapis.com/language/translate/v2?key=${googleKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ q: text, target: 'en' }),
          signal: controller.signal,
        },
      );
      if (!response.ok) return text;
      const data = await response.json();
      return (
        data?.data?.translations?.[0]?.translatedText
          ?.replace(/&#(\d+);/g, (_: string, dec: number) =>
            String.fromCharCode(dec),
          )
          ?.replace(/&quot;/g, '"')
          ?.replace(/&amp;/g, '&') || text
      );
    } catch {
      return text;
    } finally {
      clearTimeout(timeout);
    }
  }

  private async safeUpdateStatus(
    voiceCallId: number,
    status: string,
  ): Promise<void> {
    try {
      await this.prisma.voiceCall.update({
        where: { id: voiceCallId },
        data: { processing_status: status },
      });
    } catch (err) {
      this.logger.error(
        `[DB] Failed to update VoiceCall #${voiceCallId}: ${(err as Error).message}`,
      );
    }
  }

  private async getIvrNumberByCallSid(callSid: string): Promise<string> {
    try {
      const call = await this.prisma.callsMaster.findUnique({
        where: { call_sid: callSid },
        select: { call_to: true },
      });
      return call?.call_to ?? '';
    } catch {
      return '';
    }
  }

  private withRequiredFields(
    extracted: ExtractedLocation,
    opts: { village: string; complaintType: string; callSummary: string },
  ): ExtractedLocation {
    return {
      ...extracted,
      village: (extracted.village || opts.village || '').trim(),
      complaint_type: (
        extracted.complaint_type ||
        opts.complaintType ||
        'street_light'
      ).trim(),
      call_summary: (extracted.call_summary || opts.callSummary || '').trim(),
      landmark: (extracted.landmark || '').trim(),
      landmark_english: (
        extracted.landmark_english ||
        extracted.landmark ||
        opts.callSummary ||
        ''
      ).trim(),
      direction: (extracted.direction || 'near').trim(),
      caller_language: (extracted.caller_language || 'unknown').trim(),
      caller_emotion: (extracted.caller_emotion || 'unknown').trim(),
      urgency_level: (extracted.urgency_level || 'medium').trim(),
      confidence_score:
        typeof extracted.confidence_score === 'number'
          ? extracted.confidence_score
          : 0.5,
    };
  }
}
