import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { VoiceToTextService } from './voice-to-text.service'
import { LocationExtractionService, ExtractedLocation } from './location-extraction.service'
import { GeoMatchingService } from './geo-matching.service'

/** Dedup window — don't create duplicate complaints for same pole+caller within this period */
const DEDUP_WINDOW_HOURS = 24

export type VoiceProcessingStatus = 'completed' | 'manual_review' | 'not_found'

export interface VoiceProcessingResult {
    success: boolean
    status: VoiceProcessingStatus
    complaintId?: number
    message?: string
}

/** Minimum extraction-confidence to proceed with pole matching */
const MIN_CONFIDENCE = 0.15

/** Maximum concurrent AI pipelines (prevents Groq rate-limiting) */
const MAX_CONCURRENT_PIPELINES = 5

// Simple semaphore for concurrency control
let activePipelines = 0
const pipelineQueue: Array<() => void> = []

function acquireSlot(): Promise<void> {
    if (activePipelines < MAX_CONCURRENT_PIPELINES) {
        activePipelines++
        return Promise.resolve()
    }
    return new Promise<void>((resolve) => {
        pipelineQueue.push(() => {
            activePipelines++
            resolve()
        })
    })
}

function releaseSlot(): void {
    activePipelines--
    const next = pipelineQueue.shift()
    if (next) next()
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

    /**
     * Main voice complaint processing pipeline.
     *
     * Flow:
     *   1. Acquire concurrency slot (max 5 parallel pipelines)
     *   2. Determine attempt number + collect previous landmarks
     *   3. Create VoiceCall record
     *   4. Transcribe audio + Translate to English
     *   5. Resolve panchayat from IVR number
     *   6. Phase 2 (attempt >= 2): save transcript, fire background LLM, return 200
     *   7. Phase 1 (attempt 1): strict match with 13s timeout
     */
    async processVoiceComplaint(
        callSid: string,
        audioUrl: string,
        ivrNumber: string
    ): Promise<VoiceProcessingResult> {
        this.logger.log(`━━━ Voice Pipeline ━━━ CallSid: ${callSid}`)

        // ── Concurrency limiter ──────────────────────────────────────────────
        await acquireSlot()
        let slotReleased = false
        this.logger.log(`[Concurrency] Slot acquired (${activePipelines}/${MAX_CONCURRENT_PIPELINES} active)`)

        let voiceCall: { id: number } | null = null

        try {
            // ── Step 1: Determine attempt number ─────────────────────────────
            const previousAttempts = await this.prisma.voiceCall.findMany({
                where: { call_sid: callSid },
                orderBy: { created_at: 'asc' },
                select: {
                    id: true,
                    ai_extracted_json: true,
                    processing_status: true,
                }
            })
            const attemptNumber = previousAttempts.length + 1
            this.logger.log(`[Step 1] Attempt #${attemptNumber} for CallSid: ${callSid}`)

            // ── Step 1a: Global de-dup — if any previous attempt already created a complaint,
            //             do NOT create a second complaint for this CallSid.
            if (previousAttempts.length > 0) {
                const previousIds = previousAttempts.map(p => p.id)
                const existingComplaintForCall = await this.prisma.complaint.findFirst({
                    where: {
                        voice_call_id: { in: previousIds },
                        status: { in: ['pending', 'in_progress', 'manual_review', 'completed'] }
                    },
                    select: { id: true }
                })

                if (existingComplaintForCall) {
                    this.logger.warn(
                        `[Dedup] Existing complaint #${existingComplaintForCall.id} found for CallSid=${callSid}. ` +
                        `Skipping new complaint creation for this attempt.`
                    )
                    return {
                        success: true,
                        status: 'completed',
                        complaintId: existingComplaintForCall.id,
                        message: 'Duplicate IVR retry detected; reusing existing complaint.'
                    }
                }
            }

            // ── Step 1b: Collect landmarks from previous attempts ────────────
            const previousLandmarks: string[] = []
            if (attemptNumber >= 2) {
                for (const prev of previousAttempts) {
                    const json = prev.ai_extracted_json as any
                    if (json?.landmark) previousLandmarks.push(json.landmark)
                    if (json?.landmark_english) previousLandmarks.push(json.landmark_english)
                }
                this.logger.log(
                    `[Step 1b] Collected ${previousLandmarks.length} landmark clues from ${previousAttempts.length} previous attempt(s): ` +
                    `[${previousLandmarks.join(' | ')}]`
                )
            }

            // ── Step 2: Create VoiceCall record ──────────────────────────────
            voiceCall = await this.prisma.voiceCall.create({
                data: {
                    call_sid: callSid,
                    audio_url: audioUrl,
                    attempt_number: attemptNumber,
                    processing_status: 'processing'
                }
            })
            this.logger.log(`[Step 2] Created VoiceCall #${voiceCall.id} (attempt ${attemptNumber})`)

            // ── Step 3: Transcribe audio + Translate to English ──────────────
            const transcript = await this.voiceToText.transcribeAudio(audioUrl, attemptNumber === 1 ? 0 : 1)
            let transcriptEnglish = transcript

            if (transcript && transcript.trim() !== '') {
                transcriptEnglish = await this.fastTranslateToEnglish(transcript)
            }

            this.logger.log(`[Step 3] Transcript: "${transcript}" | English: "${transcriptEnglish}"`)

            // Save transcript to DB immediately so it's NEVER NULL regardless of what happens next
            if (transcript && transcript.trim() !== '') {
                await this.prisma.voiceCall.update({
                    where: { id: voiceCall.id },
                    data: { transcript, transcript_english: transcriptEnglish }
                })
            }

            if (!transcript || transcript.trim() === '') {
                this.logger.warn(`[Step 3] Empty transcript — flagging for manual review (no 404 to Exotel)`)
                return this.createManualReviewComplaint(
                    voiceCall.id,
                    audioUrl,
                    null,
                    undefined,
                    attemptNumber,
                    '',
                    ''
                )
            }

            // ── Step 4: Resolve panchayat ────────────────────────────────────
            const panchayat = await this.geoMatching.findPanchayatByIvrNumber(ivrNumber)

            if (!panchayat) {
                this.logger.warn(`[Step 4] No panchayat for IVR number: ${ivrNumber}. Forcing manual review.`)
                return this.createManualReviewComplaint(
                    voiceCall.id, audioUrl, null, undefined, attemptNumber, transcript, transcriptEnglish
                )
            }

            this.logger.log(`[Step 4] Village = "${panchayat.name}"`)

            // ── Phase 2 (Attempt >= 2): fully asynchronous ───────────────────
            if (attemptNumber >= 2) {
                this.logger.log(`[Attempt ${attemptNumber}] Firing background async LLM processing and returning 200 OK instantly.`)

                // Fire and forget — with safety net that updates status on failure
                const vcId = voiceCall.id
                this.runPhase2Background(
                    voiceCall, attemptNumber, previousLandmarks, transcript, transcriptEnglish,
                    panchayat, callSid, audioUrl
                ).catch(async (err) => {
                    this.logger.error(`[Phase 2 Background Error] ${(err as Error).message}`)
                    try {
                        await this.updateVoiceCallStatus(vcId, 'failed')
                        this.logger.warn(`[Phase 2] VoiceCall #${vcId} marked as 'failed' after background crash`)
                    } catch (dbErr) {
                        this.logger.error(`[Phase 2] Failed to update VoiceCall #${vcId} status: ${(dbErr as Error).message}`)
                    }
                })

                // Immediately return success so Exotel does not timeout
                return { success: true, status: 'completed', message: 'Processing in background' }
            }

            // ── Phase 1 (Attempt 1): Synchronous with 13-second timeout ──────
            const abortFlag = { aborted: false }
            const phase1Promise = this.runPhase1Match(
                voiceCall, transcript, transcriptEnglish, panchayat, callSid, audioUrl, abortFlag
            )

            let timeoutId: ReturnType<typeof setTimeout>
            const timeoutPromise = new Promise<VoiceProcessingResult>((resolve) => {
                timeoutId = setTimeout(() => {
                    resolve({
                        success: false,
                        status: 'not_found',
                        message: 'Phase 1 timeout exceeded 13s. Triggering Phase 2 retry.'
                    })
                }, 13000)
            })

            const result = await Promise.race([phase1Promise, timeoutPromise])
            clearTimeout(timeoutId!)

            if (result.status === 'not_found') {
                // Any "not_found" (timeout or match failure) is converted to manual review
                this.logger.warn(`[Step 5] Phase 1 returned not_found. Converting to manual_review (no 404 to Exotel).`)
                return this.createManualReviewComplaint(
                    voiceCall.id,
                    audioUrl,
                    null,
                    panchayat.id,
                    attemptNumber,
                    transcript,
                    transcriptEnglish
                )
            }

            return result

        } catch (error) {
            const errMessage = (error as Error).message ?? String(error)
            this.logger.error(`Pipeline failed: ${errMessage}`)

            if (voiceCall) {
                try {
                    await this.updateVoiceCallStatus(voiceCall.id, 'failed')
                } catch (dbErr) {
                    this.logger.error(`Failed to update VoiceCall status: ${(dbErr as Error).message}`)
                }
            }

            // Never propagate exception to controller — treat as manual review
            return {
                success: true,
                status: 'manual_review',
                message: 'Voice pipeline failed internally; flagged for manual review'
            }

        } finally {
            if (!slotReleased) {
                slotReleased = true
                releaseSlot()
                this.logger.log(`[Concurrency] Slot released in finally block (${activePipelines}/${MAX_CONCURRENT_PIPELINES} active)`)
            }
        }
    }

    /**
     * Synchronous Phase 1 Direct Match (Attempt 1).
     * Races against a 13-second timeout. Uses strict string matching only.
     */
    private async runPhase1Match(
        voiceCall: any,
        transcript: string,
        transcriptEnglish: string,
        panchayat: any,
        callSid: string,
        audioUrl: string,
        abortFlag: { aborted: boolean }
    ): Promise<VoiceProcessingResult> {
        try {
            if (abortFlag.aborted) {
                return { success: false, status: 'not_found', message: 'Aborted due to timeout' }
            }

            const poleId = await this.geoMatching.strictMatchPole(panchayat.id, transcriptEnglish)

            if (poleId) {
                this.logger.log(`[Step 5] Phase 1 Fast Match Successful! poleId: ${poleId}`)

                // Detect language: if transcript differs from English translation, caller spoke Tamil
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
                    where: { id: voiceCall.id },
                    data: {
                        ai_extracted_json: extracted as any, confidence_score: 1.0
                    }
                })

                // Duplicate check — runs regardless of callerNumber
                const dedupCutoff = new Date(Date.now() - DEDUP_WINDOW_HOURS * 60 * 60 * 1000)
                const existingComplaint = await this.prisma.complaint.findFirst({
                    where: {
                        pole_id: poleId, panchayat_id: panchayat.id,
                        created_at: { gte: dedupCutoff }, status: { in: ['pending', 'in_progress'] }
                    },
                    select: { id: true }
                })

                // Check abort flag right before creating complaint
                if (abortFlag.aborted) {
                    return { success: false, status: 'not_found', message: 'Aborted before complaint creation' }
                }

                if (existingComplaint) {
                    this.logger.warn(`[Phase 1] Duplicate detected — complaint #${existingComplaint.id} exists.`)
                    await this.updateVoiceCallStatus(voiceCall.id, 'completed')
                    await this.markPreviousAttempts(callSid, voiceCall.id)
                    return { success: true, status: 'completed', complaintId: existingComplaint.id }
                }

                const complaint = await this.prisma.complaint.create({
                    data: {
                        voice_call_id: voiceCall.id, pole_id: poleId, panchayat_id: panchayat.id,
                        complaint_type: extracted.complaint_type || 'street_light',
                        description: extracted.call_summary || transcriptEnglish,
                        caller_language: extracted.caller_language, caller_emotion: extracted.caller_emotion,
                        urgency_level: extracted.urgency_level, audio_url: audioUrl,
                        status: 'pending'
                    }
                })

                await this.updateVoiceCallStatus(voiceCall.id, 'completed')
                await this.markPreviousAttempts(callSid, voiceCall.id)

                // Async background task to enrich complaint with proper LLM data
                this.enrichComplaintWithSummary(complaint.id, voiceCall.id, transcript, transcriptEnglish, panchayat.id).catch(err => {
                    this.logger.error('Async enrich failed', err)
                })

                this.logger.log(`[Phase 1] ✅ Complaint #${complaint.id} created`)
                return { success: true, status: 'completed', complaintId: complaint.id }

            } else {
                this.logger.log(`[Phase 1] Match Failed. Need Phase 2.`)
                await this.updateVoiceCallStatus(voiceCall.id, 'not_found')
                return { success: false, status: 'not_found', message: 'Phase 1 Direct Match failed.' }
            }
        } catch (err) {
            this.logger.error(`[Phase 1 Error] ${(err as Error).message}`)
            try {
                await this.updateVoiceCallStatus(voiceCall.id, 'failed')
            } catch (dbErr) {
                this.logger.error(`[Phase 1] Failed to update status: ${(dbErr as Error).message}`)
            }
            return { success: false, status: 'not_found', message: 'Error in Phase 1' }
        }
    }

    /**
     * Asynchronous Phase 2 LLM Match (Attempt >= 2).
     * Runs silently in the background. Exotel is not waiting for this.
     */
    private async runPhase2Background(
        voiceCall: any,
        attemptNumber: number,
        previousLandmarks: string[],
        transcript: string,
        transcriptEnglish: string,
        panchayat: any,
        callSid: string,
        audioUrl: string
    ): Promise<void> {
        try {
            this.logger.log(`[Phase 2] Starting LLM background task for ${callSid}`)

            const knownLandmarks = await this.geoMatching.getLandmarksForPanchayat(panchayat.id)
            const combinedTranscript = previousLandmarks.length > 0
                ? `Current audio: ${transcript}. Previous audio clues: ${previousLandmarks.join(', ')}`
                : transcript

            const extracted = await this.locationExtraction.extractLocation(combinedTranscript, knownLandmarks)
            extracted.village = panchayat.name
            this.logger.log(`[Phase 2] LLM Extraction: ${JSON.stringify(extracted)}`)

            if (extracted.confidence_score < MIN_CONFIDENCE) {
                this.logger.warn(`[Phase 2] Low confidence (${extracted.confidence_score})`)
                await this.createManualReviewComplaint(voiceCall.id, audioUrl, extracted, panchayat.id, attemptNumber, transcript, transcriptEnglish)
                return
            }

            const currentLandmarks: string[] = []
            if (extracted.landmark_english) currentLandmarks.push(extracted.landmark_english)
            if (extracted.landmark) currentLandmarks.push(extracted.landmark)

            const allLandmarkHints = [...new Set([...currentLandmarks, ...previousLandmarks].filter(h => h.trim() !== ''))]

            const poleId = await this.geoMatching.findNearestPole(panchayat.id, allLandmarkHints)

            if (!poleId) {
                this.logger.warn(`[Phase 2] Match Failed. Flagging for manual review.`)
                await this.createManualReviewComplaint(voiceCall.id, audioUrl, extracted, panchayat.id, attemptNumber, transcript, transcriptEnglish)
                return
            }

            // Save LLM extraction data (transcript already saved before backgrounding)
            await this.prisma.voiceCall.update({
                where: { id: voiceCall.id },
                data: {
                    ai_extracted_json: extracted as any, confidence_score: extracted.confidence_score
                }
            })

            // Duplicate check — runs regardless of callerNumber
            const dedupCutoff = new Date(Date.now() - DEDUP_WINDOW_HOURS * 60 * 60 * 1000)
            const existingComplaint = await this.prisma.complaint.findFirst({
                where: {
                    pole_id: poleId, panchayat_id: panchayat.id,
                    created_at: { gte: dedupCutoff }, status: { in: ['pending', 'in_progress'] }
                },
                select: { id: true }
            })

            if (existingComplaint) {
                this.logger.warn(`[Phase 2] Duplicate detected — complaint #${existingComplaint.id} already exists.`)
                await this.updateVoiceCallStatus(voiceCall.id, 'completed')
                await this.markPreviousAttempts(callSid, voiceCall.id)
                return
            }

            // Create Complaint
            const complaint = await this.prisma.complaint.create({
                data: {
                    voice_call_id: voiceCall.id, pole_id: poleId, panchayat_id: panchayat.id,
                    complaint_type: extracted.complaint_type || 'street_light',
                    description: extracted.call_summary || transcriptEnglish,
                    caller_language: extracted.caller_language, caller_emotion: extracted.caller_emotion,
                    urgency_level: extracted.urgency_level, audio_url: audioUrl,
                    status: 'pending'
                }
            })

            await this.updateVoiceCallStatus(voiceCall.id, 'completed')
            await this.markPreviousAttempts(callSid, voiceCall.id)
            this.logger.log(`[Phase 2 Async] ✅ Complaint #${complaint.id} created`)

        } catch (err) {
            this.logger.error(`[Phase 2 Fatal Background Error] ${(err as Error).message}`)
            await this.createManualReviewComplaint(voiceCall.id, audioUrl, null, panchayat.id, attemptNumber, transcript, transcriptEnglish)
        }
    }

    /**
     * Background LLM extraction to enrich complaints created by Phase 1 Fast Match.
     * Updates both Complaint and VoiceCall with proper LLM-extracted data.
     */
    private async enrichComplaintWithSummary(complaintId: number, voiceCallId: number, transcript: string, transcriptEnglish: string, panchayatId: number) {
        try {
            this.logger.log(`[Async Enrich] Starting LLM summarization for Complaint #${complaintId}`)
            const knownLandmarks = await this.geoMatching.getLandmarksForPanchayat(panchayatId)
            const extracted = await this.locationExtraction.extractLocation(transcriptEnglish, knownLandmarks)

            if (extracted) {
                // Update Complaint with LLM-extracted data
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

                // Also update VoiceCall with LLM extraction JSON
                await this.prisma.voiceCall.update({
                    where: { id: voiceCallId },
                    data: {
                        ai_extracted_json: extracted as any,
                        confidence_score: extracted.confidence_score
                    }
                })

                this.logger.log(`[Async Enrich] ✅ Complaint #${complaintId} and VoiceCall #${voiceCallId} enriched`)
            }
        } catch (err) {
            this.logger.error(`[Async Enrich] Failed to enrich complaint #${complaintId}: ${(err as Error).message}`)
        }
    }

    /**
     * Fast Translation using Google Cloud Translation API.
     */
    private async fastTranslateToEnglish(text: string): Promise<string> {
        let googleKey = process.env.GOOGLE_SPEECH_API_KEY
        if (!googleKey) {
            try {
                const setting = await this.prisma.systemSettings.findUnique({ where: { key: 'google_speech_api_key' } })
                googleKey = setting?.value ?? undefined
            } catch { } // ignore
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
                return data.data.translations[0].translatedText.replace(/&#(\d+);/g, (match: string, dec: number) => {
                    return String.fromCharCode(dec)
                }).replace(/&quot;/g, '"').replace(/&amp;/g, '&')
            }
            return text
        } catch {
            return text
        } finally {
            clearTimeout(timeout)
        }
    }

    /**
     * Create a complaint flagged for manual_review.
     */
    private async createManualReviewComplaint(
        voiceCallId: number,
        audioUrl: string,
        extracted: ExtractedLocation | null,
        panchayatId: number | undefined,
        attemptNumber: number,
        transcript: string,
        transcriptEnglish: string
    ): Promise<VoiceProcessingResult> {
        // Save transcript to VoiceCall so it's never NULL
        await this.prisma.voiceCall.update({
            where: { id: voiceCallId },
            data: {
                transcript, transcript_english: transcriptEnglish,
                ai_extracted_json: extracted as any ?? undefined,
                processing_status: 'manual_review'
            }
        })

        const complaint = await this.prisma.complaint.create({
            data: {
                voice_call_id: voiceCallId,
                panchayat_id: panchayatId ?? null,
                complaint_type: extracted?.complaint_type || 'street_light',
                description: extracted?.call_summary || transcriptEnglish || 'Auto Flagged for review',
                caller_language: extracted?.caller_language || 'unknown',
                caller_emotion: extracted?.caller_emotion || 'unknown',
                urgency_level: extracted?.urgency_level || 'unknown',
                audio_url: audioUrl,
                status: 'manual_review'
            }
        })

        this.logger.warn(
            `[Manual Review] Complaint #${complaint.id} (attempt ${attemptNumber}, confidence: ${extracted?.confidence_score ?? 0})`
        )

        return {
            success: true,
            status: 'manual_review',
            complaintId: complaint.id,
            message: 'Flagged for manual review'
        }
    }

    /** Update VoiceCall processing_status. */
    private async updateVoiceCallStatus(voiceCallId: number, status: string): Promise<void> {
        await this.prisma.voiceCall.update({
            where: { id: voiceCallId },
            data: { processing_status: status }
        })
    }

    /** Mark all previous attempts for this call as 'superseded' after success. */
    private async markPreviousAttempts(callSid: string, currentVoiceCallId: number): Promise<void> {
        try {
            const updated = await this.prisma.voiceCall.updateMany({
                where: {
                    call_sid: callSid,
                    id: { not: currentVoiceCallId },
                    processing_status: { in: ['not_found', 'processing', 'failed'] }
                },
                data: { processing_status: 'superseded' }
            })
            if (updated.count > 0) {
                this.logger.log(`[Cleanup] Marked ${updated.count} previous attempt(s) as superseded`)
            }
        } catch (err) {
            this.logger.warn(`[Cleanup] Failed to mark previous attempts: ${(err as Error).message}`)
        }
    }
}
