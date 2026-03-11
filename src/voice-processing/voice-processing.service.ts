import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { VoiceToTextService } from './voice-to-text.service'
import { LocationExtractionService, ExtractedLocation } from './location-extraction.service'
import { GeoMatchingService } from './geo-matching.service'

const DEDUP_WINDOW_HOURS = 24
const MIN_CONFIDENCE = 0.15
const PHASE1_POLL_INTERVAL_MS = 2000
const PHASE1_MAX_WAIT_MS = 45_000

export type VoiceProcessingStatus = 'completed' | 'manual_review' | 'not_found'

export interface VoiceProcessingResult {
    success: boolean
    status: VoiceProcessingStatus
    complaintId?: number
    message?: string
    attemptNumber?: number
    phase?: 1 | 2
}

@Injectable()
export class VoiceProcessingService {
    private readonly logger = new Logger(VoiceProcessingService.name)

    constructor(
        private prisma: PrismaService,
        private voiceToText: VoiceToTextService,
        private locationExtraction: LocationExtractionService,
        private geoMatching: GeoMatchingService
    ) { }

    // ═══════════════════════════════════════════════════════════════════════════
    //  PUBLIC ENTRY POINT — called by IvrController for every voice-complaint
    // ═══════════════════════════════════════════════════════════════════════════

    async processVoiceComplaint(
        callSid: string,
        audioUrl: string,
        ivrNumber: string
    ): Promise<VoiceProcessingResult> {
        this.logger.log(`━━━ Voice Pipeline ━━━ CallSid: ${callSid}`)

        const attempt = await this.registerAttempt(callSid, audioUrl)
        const attemptNumber = attempt.attemptNumber
        this.logger.log(`[Entry] Attempt #${attemptNumber} for CallSid: ${callSid}`)

        if (attempt.isDuplicate) {
            this.logger.log(`[Entry] Duplicate callback replay detected. voiceCallId=${attempt.voiceCallId}`)
            return {
                success: true,
                status: 'completed',
                attemptNumber,
                phase: attemptNumber >= 2 ? 2 : 1,
                message: 'Duplicate callback ignored.'
            }
        }

        const voiceCallId = attempt.voiceCallId
        this.logger.log(`[Entry] Created VoiceCall #${voiceCallId}`)

        // ══════════════════════════════════════════════════════════════════
        //  PHASE 2 (attempt >= 2): RESPOND 200 INSTANTLY, process in bg
        // ══════════════════════════════════════════════════════════════════
        if (attemptNumber >= 2) {
            this.logger.log(`[Phase 2] Returning 200 IMMEDIATELY. All processing is background.`)

            this.runPhase2Pipeline(voiceCallId, callSid, audioUrl, ivrNumber).catch(err => {
                this.logger.error(`[Phase 2 bg crash] ${(err as Error).message}`)
                this.safeUpdateStatus(voiceCallId, 'failed')
            })

            return {
                success: true,
                status: 'completed',
                attemptNumber,
                phase: 2,
                message: 'Phase 2 accepted. Processing in background.'
            }
        }

        // ══════════════════════════════════════════════════════════════════
        //  PHASE 1 (attempt 1): Process synchronously, Exotel may timeout
        // ══════════════════════════════════════════════════════════════════
        this.logger.log(`[Phase 1] Starting synchronous processing (Exotel may timeout — that's OK)`)

        try {
            const phase1 = await this.runPhase1Pipeline(voiceCallId, callSid, audioUrl, ivrNumber)
            return { ...phase1, attemptNumber, phase: 1 }
        } catch (err) {
            this.logger.error(`[Phase 1] Pipeline error: ${(err as Error).message}`)
            await this.safeUpdateStatus(voiceCallId, 'failed')
            return { success: false, status: 'not_found', attemptNumber, phase: 1, message: 'Phase 1 processing error' }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  PHASE 1 PIPELINE — runs synchronously on attempt 1
    //  Exotel may timeout before this finishes — that's by design.
    //  If it finishes in time, controller sends 200. If not, Exotel retries.
    //  Either way, the data (transcript, match) is saved to voice_calls.
    // ═══════════════════════════════════════════════════════════════════════════

    private async runPhase1Pipeline(
        voiceCallId: number,
        callSid: string,
        audioUrl: string,
        ivrNumber: string
    ): Promise<VoiceProcessingResult> {
        // Step 1: Transcribe
        const transcript = await this.voiceToText.transcribeAudio(audioUrl, 0)
        const transcriptEnglish = transcript ? await this.fastTranslateToEnglish(transcript) : ''

        this.logger.log(`[Phase 1] Transcript: "${transcript}" | English: "${transcriptEnglish}"`)

        await this.prisma.voiceCall.update({
            where: { id: voiceCallId },
            data: { transcript: transcript || '', transcript_english: transcriptEnglish || '' }
        })

        if (!transcript || transcript.trim() === '') {
            this.logger.warn(`[Phase 1] Empty transcript. Saving status, NOT creating complaint yet (Phase 2 will handle).`)
            await this.safeUpdateStatus(voiceCallId, 'not_found')
            return { success: false, status: 'not_found', message: 'Empty transcript' }
        }

        // Step 2: Resolve panchayat
        const panchayat = await this.geoMatching.findPanchayatByIvrNumber(ivrNumber)
        if (!panchayat) {
            this.logger.warn(`[Phase 1] No panchayat for IVR: ${ivrNumber}`)
            await this.safeUpdateStatus(voiceCallId, 'not_found')
            return { success: false, status: 'not_found', message: 'No panchayat found' }
        }

        // Step 3: Strict (fast) pole match — no AI, just keyword matching
        const poleId = await this.geoMatching.strictMatchPole(panchayat.id, transcriptEnglish)

        if (!poleId) {
            this.logger.log(`[Phase 1] No strict match. Saving data for Phase 2 to use.`)
            await this.safeUpdateStatus(voiceCallId, 'not_found')
            return { success: false, status: 'not_found', message: 'No strict pole match' }
        }

        // Step 4: Match found → create complaint
        this.logger.log(`[Phase 1] Strict match! poleId=${poleId}`)

        const detectedLanguage = transcript !== transcriptEnglish ? 'tamil' : 'english'
        const extracted: ExtractedLocation = {
            village: panchayat.name,
            landmark: transcript,
            landmark_english: transcriptEnglish,
            direction: 'near',
            complaint_type: 'street_light',
            call_summary: transcriptEnglish,
            caller_language: detectedLanguage,
            caller_emotion: 'calm',
            urgency_level: 'medium',
            confidence_score: 1.0
        }

        await this.prisma.voiceCall.update({
            where: { id: voiceCallId },
            data: { ai_extracted_json: extracted as any, confidence_score: 1.0, processing_status: 'completed' }
        })

        const complaint = await this.createComplaintIfNotDuplicate(
            voiceCallId, poleId, panchayat.id, extracted, audioUrl, callSid
        )

        if (complaint) {
            this.enrichInBackground(complaint.id, voiceCallId, transcript, transcriptEnglish, panchayat.id)
            return { success: true, status: 'completed', complaintId: complaint.id }
        }

        return { success: true, status: 'completed', message: 'Duplicate complaint exists' }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  PHASE 2 PIPELINE — runs entirely in background after instant 200
    //
    //  1. Transcribe Phase 2 audio
    //  2. Wait for Phase 1 to finish processing
    //  3. Check if Phase 1 already created a complaint → done
    //  4. If not, combine Phase 1 + Phase 2 data, run LLM extraction + AI match
    //  5. Create exactly ONE complaint
    // ═══════════════════════════════════════════════════════════════════════════

    private async runPhase2Pipeline(
        voiceCallId: number,
        callSid: string,
        audioUrl: string,
        ivrNumber: string
    ): Promise<void> {
        this.logger.log(`[Phase 2 bg] Starting for CallSid: ${callSid}`)

        // ── Step A: Transcribe Phase 2 audio ─────────────────────────────
        let transcript = ''
        let transcriptEnglish = ''
        try {
            transcript = await this.voiceToText.transcribeAudio(audioUrl, 0)
            transcriptEnglish = transcript ? await this.fastTranslateToEnglish(transcript) : ''
        } catch (err) {
            this.logger.error(`[Phase 2 bg] Transcription failed: ${(err as Error).message}`)
        }

        this.logger.log(`[Phase 2 bg] Transcript: "${transcript}" | English: "${transcriptEnglish}"`)

        await this.prisma.voiceCall.update({
            where: { id: voiceCallId },
            data: { transcript: transcript || '', transcript_english: transcriptEnglish || '' }
        })

        // ── Step B: Wait for Phase 1 to finish ──────────────────────────
        const phase1Data = await this.waitForPhase1(callSid, voiceCallId)
        this.logger.log(`[Phase 2 bg] Phase 1 status: ${phase1Data?.processing_status ?? 'not found'}`)

        // ── Step C: Check if Phase 1 already created a complaint ────────
        const existingComplaint = await this.findExistingComplaintForCall(callSid)
        if (existingComplaint) {
            this.logger.log(`[Phase 2 bg] Phase 1 already created complaint #${existingComplaint.id}. Enriching with Phase 2 data.`)
            await this.safeUpdateStatus(voiceCallId, 'completed')

            if (transcript && transcriptEnglish) {
                this.enrichExistingComplaintWithPhase2(existingComplaint.id, transcript, transcriptEnglish).catch(err =>
                    this.logger.error(`[Phase 2 enrich] ${(err as Error).message}`)
                )
            }
            return
        }

        // ── Step D: No complaint yet. Resolve panchayat. ────────────────
        const panchayat = await this.geoMatching.findPanchayatByIvrNumber(ivrNumber)
        if (!panchayat) {
            this.logger.warn(`[Phase 2 bg] No panchayat for IVR: ${ivrNumber}. Creating manual review.`)
            await this.createManualReviewComplaint(voiceCallId, audioUrl, null, undefined, transcript, transcriptEnglish)
            return
        }

        // ── Step E: Gather all data from Phase 1 + Phase 2 ─────────────
        const allTranscripts: string[] = []
        const allLandmarks: string[] = []

        if (phase1Data) {
            if (phase1Data.transcript) allTranscripts.push(phase1Data.transcript)
            if (phase1Data.transcript_english) allTranscripts.push(phase1Data.transcript_english)
            const json = phase1Data.ai_extracted_json as any
            if (json?.landmark) allLandmarks.push(json.landmark)
            if (json?.landmark_english) allLandmarks.push(json.landmark_english)
        }
        if (transcript) allTranscripts.push(transcript)
        if (transcriptEnglish) allTranscripts.push(transcriptEnglish)

        const combinedTranscript = allTranscripts.filter(t => t && t.trim()).join('. ')

        if (!combinedTranscript) {
            this.logger.warn(`[Phase 2 bg] No usable transcript from either phase. Creating manual review.`)
            await this.createManualReviewComplaint(voiceCallId, audioUrl, null, panchayat.id, '', '')
            return
        }

        // ── Step F: LLM extraction ──────────────────────────────────────
        const knownLandmarks = await this.geoMatching.getLandmarksForPanchayat(panchayat.id)
        const extracted = await this.locationExtraction.extractLocation(combinedTranscript, knownLandmarks)
        extracted.village = panchayat.name

        this.logger.log(`[Phase 2 bg] LLM extraction: ${JSON.stringify(extracted)}`)

        await this.prisma.voiceCall.update({
            where: { id: voiceCallId },
            data: { ai_extracted_json: extracted as any, confidence_score: extracted.confidence_score }
        })

        if (extracted.confidence_score < MIN_CONFIDENCE) {
            this.logger.warn(`[Phase 2 bg] Low confidence (${extracted.confidence_score}). Manual review.`)
            await this.createManualReviewComplaint(voiceCallId, audioUrl, extracted, panchayat.id, transcript, transcriptEnglish)
            return
        }

        // ── Step G: AI pole matching (uses combined landmarks) ──────────
        const currentLandmarks: string[] = []
        if (extracted.landmark_english) currentLandmarks.push(extracted.landmark_english)
        if (extracted.landmark) currentLandmarks.push(extracted.landmark)

        const allHints = [...new Set([...currentLandmarks, ...allLandmarks].filter(h => h && h.trim()))]

        const poleId = await this.geoMatching.findNearestPole(panchayat.id, allHints)

        if (!poleId) {
            this.logger.warn(`[Phase 2 bg] AI match failed. Manual review.`)
            await this.createManualReviewComplaint(voiceCallId, audioUrl, extracted, panchayat.id, transcript, transcriptEnglish)
            return
        }

        // ── Step H: Create complaint ────────────────────────────────────
        // Double-check dedup one more time (Phase 1 might have finished between Step C and now)
        const lateCheck = await this.findExistingComplaintForCall(callSid)
        if (lateCheck) {
            this.logger.log(`[Phase 2 bg] Late dedup: complaint #${lateCheck.id} appeared. Skipping.`)
            await this.safeUpdateStatus(voiceCallId, 'completed')
            return
        }

        const complaint = await this.createComplaintIfNotDuplicate(
            voiceCallId, poleId, panchayat.id, extracted, audioUrl, callSid
        )

        if (complaint) {
            this.logger.log(`[Phase 2 bg] ✅ Complaint #${complaint.id} created`)
        } else {
            this.logger.log(`[Phase 2 bg] Pole-level duplicate exists. No new complaint.`)
            await this.safeUpdateStatus(voiceCallId, 'completed')
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    private async waitForPhase1(
        callSid: string,
        currentVoiceCallId: number
    ): Promise<{
        id: number
        transcript: string | null
        transcript_english: string | null
        ai_extracted_json: any
        processing_status: string
    } | null> {
        const startTime = Date.now()

        while (Date.now() - startTime < PHASE1_MAX_WAIT_MS) {
            const phase1 = await this.prisma.voiceCall.findFirst({
                where: {
                    call_sid: callSid,
                    id: { not: currentVoiceCallId },
                    attempt_number: 1
                },
                select: {
                    id: true,
                    transcript: true,
                    transcript_english: true,
                    ai_extracted_json: true,
                    processing_status: true
                }
            })

            if (!phase1) {
                this.logger.log(`[waitForPhase1] No Phase 1 voice_call found yet. Waiting ${PHASE1_POLL_INTERVAL_MS}ms`)
                await new Promise(r => setTimeout(r, PHASE1_POLL_INTERVAL_MS))
                continue
            }

            if (phase1.processing_status !== 'processing') {
                this.logger.log(`[waitForPhase1] Phase 1 finished with status: ${phase1.processing_status}`)
                return phase1
            }

            this.logger.log(`[waitForPhase1] Phase 1 still processing... waiting ${PHASE1_POLL_INTERVAL_MS}ms`)
            await new Promise(r => setTimeout(r, PHASE1_POLL_INTERVAL_MS))
        }

        this.logger.warn(`[waitForPhase1] Timed out after ${PHASE1_MAX_WAIT_MS}ms. Proceeding with whatever data exists.`)

        const phase1 = await this.prisma.voiceCall.findFirst({
            where: { call_sid: callSid, id: { not: currentVoiceCallId }, attempt_number: 1 },
            select: { id: true, transcript: true, transcript_english: true, ai_extracted_json: true, processing_status: true }
        })
        return phase1
    }

    private async findExistingComplaintForCall(callSid: string): Promise<{ id: number } | null> {
        const voiceCalls = await this.prisma.voiceCall.findMany({
            where: { call_sid: callSid },
            select: { id: true }
        })

        if (voiceCalls.length === 0) return null

        return this.prisma.complaint.findFirst({
            where: {
                voice_call_id: { in: voiceCalls.map(v => v.id) },
                status: { in: ['pending', 'in_progress', 'manual_review', 'completed'] }
            },
            select: { id: true }
        })
    }

    private async createComplaintIfNotDuplicate(
        voiceCallId: number,
        poleId: number,
        panchayatId: number,
        extracted: ExtractedLocation,
        audioUrl: string,
        callSid: string
    ): Promise<{ id: number } | null> {
        const dedupCutoff = new Date(Date.now() - DEDUP_WINDOW_HOURS * 60 * 60 * 1000)
        return this.prisma.$transaction(async (tx) => {
            const alreadyFinalizedForCall = await tx.complaint.findFirst({
                where: {
                    voice_call: { is: { call_sid: callSid } },
                    status: { in: ['pending', 'in_progress', 'manual_review', 'completed'] }
                },
                select: { id: true }
            })

            if (alreadyFinalizedForCall) {
                this.logger.warn(`[Dedup] CallSid-level duplicate — complaint #${alreadyFinalizedForCall.id} already exists`)
                await tx.voiceCall.update({
                    where: { id: voiceCallId },
                    data: { processing_status: 'superseded' }
                })
                return null
            }

            const poleExisting = await tx.complaint.findFirst({
                where: {
                    pole_id: poleId,
                    panchayat_id: panchayatId,
                    created_at: { gte: dedupCutoff },
                    status: { in: ['pending', 'in_progress'] }
                },
                select: { id: true }
            })

            if (poleExisting) {
                this.logger.warn(`[Dedup] Pole-level duplicate — complaint #${poleExisting.id} exists`)
                await tx.voiceCall.update({
                    where: { id: voiceCallId },
                    data: { processing_status: 'completed' }
                })
                return null
            }

            const complaint = await tx.complaint.create({
                data: {
                    voice_call_id: voiceCallId,
                    pole_id: poleId,
                    panchayat_id: panchayatId,
                    complaint_type: extracted.complaint_type || 'street_light',
                    description: extracted.call_summary || extracted.landmark_english || 'Voice complaint',
                    caller_language: extracted.caller_language,
                    caller_emotion: extracted.caller_emotion,
                    urgency_level: extracted.urgency_level,
                    audio_url: audioUrl,
                    status: 'pending'
                }
            })

            await tx.voiceCall.update({
                where: { id: voiceCallId },
                data: { processing_status: 'completed' }
            })
            await tx.voiceCall.updateMany({
                where: {
                    call_sid: callSid,
                    id: { not: voiceCallId },
                    processing_status: { in: ['not_found', 'processing', 'failed'] }
                },
                data: { processing_status: 'superseded' }
            })

            return complaint
        })
    }

    private async createManualReviewComplaint(
        voiceCallId: number,
        audioUrl: string,
        extracted: ExtractedLocation | null,
        panchayatId: number | undefined,
        transcript: string,
        transcriptEnglish: string
    ): Promise<void> {
        const currentVoiceCall = await this.prisma.voiceCall.findUnique({
            where: { id: voiceCallId },
            select: { call_sid: true }
        })
        const callSid = currentVoiceCall?.call_sid ?? null

        await this.prisma.$transaction(async (tx) => {
            await tx.voiceCall.update({
                where: { id: voiceCallId },
                data: {
                    transcript: transcript || undefined,
                    transcript_english: transcriptEnglish || undefined,
                    ai_extracted_json: (extracted as any) ?? undefined,
                    processing_status: 'manual_review'
                }
            })

            if (callSid) {
                const existing = await tx.complaint.findFirst({
                    where: {
                        voice_call: { is: { call_sid: callSid } },
                        status: { in: ['pending', 'in_progress', 'manual_review', 'completed'] }
                    },
                    select: { id: true }
                })
                if (existing) {
                    this.logger.warn(`[Manual Review] CallSid-level duplicate manual complaint skipped. Existing #${existing.id}`)
                    return
                }
            }

            await tx.complaint.create({
                data: {
                    voice_call_id: voiceCallId,
                    panchayat_id: panchayatId ?? null,
                    complaint_type: extracted?.complaint_type || 'street_light',
                    description: extracted?.call_summary || transcriptEnglish || 'Auto flagged for review',
                    caller_language: extracted?.caller_language || 'unknown',
                    caller_emotion: extracted?.caller_emotion || 'unknown',
                    urgency_level: extracted?.urgency_level || 'unknown',
                    audio_url: audioUrl,
                    status: 'manual_review'
                }
            })
        })

        this.logger.warn(`[Manual Review] Complaint created for VoiceCall #${voiceCallId}`)
    }

    private async registerAttempt(
        callSid: string,
        audioUrl: string
    ): Promise<{ voiceCallId: number, attemptNumber: number, isDuplicate: boolean }> {
        return this.prisma.$transaction(async (tx) => {
            const duplicate = await tx.voiceCall.findFirst({
                where: { call_sid: callSid, audio_url: audioUrl },
                orderBy: { id: 'desc' },
                select: { id: true, attempt_number: true }
            })

            if (duplicate) {
                return {
                    voiceCallId: duplicate.id,
                    attemptNumber: duplicate.attempt_number,
                    isDuplicate: true
                }
            }

            const latestAttempt = await tx.voiceCall.findFirst({
                where: { call_sid: callSid },
                orderBy: { attempt_number: 'desc' },
                select: { attempt_number: true }
            })
            const attemptNumber = (latestAttempt?.attempt_number ?? 0) + 1

            const voiceCall = await tx.voiceCall.create({
                data: {
                    call_sid: callSid,
                    audio_url: audioUrl,
                    attempt_number: attemptNumber,
                    processing_status: 'processing'
                },
                select: { id: true }
            })

            return { voiceCallId: voiceCall.id, attemptNumber, isDuplicate: false }
        }, { isolationLevel: 'Serializable' })
    }

    private async enrichInBackground(complaintId: number, voiceCallId: number, transcript: string, transcriptEnglish: string, panchayatId: number) {
        try {
            const knownLandmarks = await this.geoMatching.getLandmarksForPanchayat(panchayatId)
            const extracted = await this.locationExtraction.extractLocation(transcriptEnglish, knownLandmarks)

            if (extracted) {
                await this.prisma.complaint.update({
                    where: { id: complaintId },
                    data: {
                        complaint_type: extracted.complaint_type || 'street_light',
                        description: extracted.call_summary || transcriptEnglish,
                        caller_language: extracted.caller_language,
                        caller_emotion: extracted.caller_emotion,
                        urgency_level: extracted.urgency_level,
                    }
                })
                await this.prisma.voiceCall.update({
                    where: { id: voiceCallId },
                    data: { ai_extracted_json: extracted as any, confidence_score: extracted.confidence_score }
                })
            }
        } catch (err) {
            this.logger.error(`[Enrich] Failed: ${(err as Error).message}`)
        }
    }

    private async enrichExistingComplaintWithPhase2(complaintId: number, transcript: string, transcriptEnglish: string) {
        const current = await this.prisma.complaint.findUnique({ where: { id: complaintId }, select: { description: true } })
        if (current && (!current.description || current.description.length < transcriptEnglish.length)) {
            await this.prisma.complaint.update({
                where: { id: complaintId },
                data: { description: transcriptEnglish }
            })
            this.logger.log(`[Phase 2 enrich] Updated complaint #${complaintId} description with Phase 2 data`)
        }
    }

    private async fastTranslateToEnglish(text: string): Promise<string> {
        let googleKey = process.env.GOOGLE_SPEECH_API_KEY
        if (!googleKey) {
            try {
                const setting = await this.prisma.systemSettings.findUnique({ where: { key: 'google_speech_api_key' } })
                googleKey = setting?.value ?? undefined
            } catch { }
        }

        if (!googleKey) return text

        const url = `https://translation.googleapis.com/language/translate/v2?key=${googleKey}`
        const controller = new AbortController()
        const timeout = setTimeout(() => controller.abort(), 5000)

        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ q: text, target: 'en' }),
                signal: controller.signal
            })
            if (!response.ok) return text
            const data = await response.json()
            if (data?.data?.translations?.[0]?.translatedText) {
                return data.data.translations[0].translatedText
                    .replace(/&#(\d+);/g, (_: string, dec: number) => String.fromCharCode(dec))
                    .replace(/&quot;/g, '"')
                    .replace(/&amp;/g, '&')
            }
            return text
        } catch {
            return text
        } finally {
            clearTimeout(timeout)
        }
    }

    private async safeUpdateStatus(voiceCallId: number, status: string): Promise<void> {
        try {
            await this.prisma.voiceCall.update({
                where: { id: voiceCallId },
                data: { processing_status: status }
            })
        } catch (err) {
            this.logger.error(`[DB] Failed to update VoiceCall #${voiceCallId} status: ${(err as Error).message}`)
        }
    }

    private async markPreviousAttempts(callSid: string, currentVoiceCallId: number): Promise<void> {
        try {
            await this.prisma.voiceCall.updateMany({
                where: {
                    call_sid: callSid,
                    id: { not: currentVoiceCallId },
                    processing_status: { in: ['not_found', 'processing', 'failed'] }
                },
                data: { processing_status: 'superseded' }
            })
        } catch (err) {
            this.logger.warn(`[Cleanup] ${(err as Error).message}`)
        }
    }
}
