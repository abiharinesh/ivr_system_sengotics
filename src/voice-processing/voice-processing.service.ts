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

/** Minimum extraction-confidence to proceed with pole matching on attempt 1 */
const MIN_CONFIDENCE_ATTEMPT_1 = 0.3
/** Minimum extraction-confidence to proceed with pole matching on attempt 2+ */
const MIN_CONFIDENCE_ATTEMPT_2 = 0.15

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
     *   2. Determine attempt number + clean up old failures
     *   3. Create VoiceCall record
     *   4. Transcribe audio (Whisper)
     *   5. LLM extraction (landmark, landmark_english, transcript_english, complaint_type)
     *   6. Resolve panchayat from IVR number
     *   7. Confidence check
     *   8. Match pole by landmark (string match first, then AI fallback)
     *   9. Create complaint
     */
    async processVoiceComplaint(
        callSid: string,
        audioUrl: string,
        ivrNumber: string
    ): Promise<VoiceProcessingResult> {
        this.logger.log(`━━━ Voice Pipeline ━━━ CallSid: ${callSid}`)

        // ── Concurrency limiter ──────────────────────────────────────────────
        await acquireSlot()
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

            // ── Step 1b: Collect landmarks from previous attempts ────────────
            // On retry, we combine ALL landmark clues from every attempt
            // so the AI has more context to find the right pole.
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

            // ── Step 3: Transcribe audio ─────────────────────────────────────
            const transcript = await this.voiceToText.transcribeAudio(audioUrl)
            this.logger.log(`[Step 3] Transcript: "${transcript}"`)

            if (!transcript || transcript.trim() === '') {
                this.logger.warn(`[Step 3] Empty transcript — cannot proceed`)
                await this.updateVoiceCallStatus(voiceCall.id, 'not_found')
                return {
                    success: false,
                    status: 'not_found',
                    message: 'Could not transcribe audio — please try again'
                }
            }

            // ── Step 4: Resolve panchayat (before extraction for landmark context) ─
            const panchayat = await this.geoMatching.findPanchayatByIvrNumber(ivrNumber)
            let knownLandmarks: string[] = []

            if (panchayat) {
                this.logger.log(`[Step 4] Village = "${panchayat.name}" (from IVR ${ivrNumber})`)
                knownLandmarks = await this.geoMatching.getLandmarksForPanchayat(panchayat.id)
                this.logger.log(`[Step 4] Found ${knownLandmarks.length} known landmarks in DB`)
            } else {
                this.logger.warn(`[Step 4] No panchayat for IVR number: ${ivrNumber}`)
            }

            // ── Step 5: LLM extraction + translation (with DB landmark context) ─
            const extracted = await this.locationExtraction.extractLocation(transcript, knownLandmarks)
            this.logger.log(`[Step 5] Extraction: ${JSON.stringify(extracted)}`)

            if (panchayat) {
                extracted.village = panchayat.name
            }

            // ── Step 6: Save to VoiceCall ────────────────────────────────────
            await this.prisma.voiceCall.update({
                where: { id: voiceCall.id },
                data: {
                    transcript,
                    transcript_english: extracted.transcript_english,
                    ai_extracted_json: extracted as any,
                    confidence_score: extracted.confidence_score
                }
            })
            this.logger.log(`[Step 6] Saved transcript + extraction`)

            // ── Step 7: Confidence check ─────────────────────────────────────
            const minConfidence = attemptNumber === 1 ? MIN_CONFIDENCE_ATTEMPT_1 : MIN_CONFIDENCE_ATTEMPT_2

            if (extracted.confidence_score < minConfidence) {
                this.logger.warn(
                    `[Step 7] Low confidence (${extracted.confidence_score} < ${minConfidence}) attempt ${attemptNumber}`
                )

                if (attemptNumber === 1) {
                    await this.updateVoiceCallStatus(voiceCall.id, 'not_found')
                    return {
                        success: false,
                        status: 'not_found',
                        message: 'Low confidence — please try again with clearer pronunciation'
                    }
                }

                // Attempt 2+: still try matching before giving up
                this.logger.log(`[Step 7] Attempt ${attemptNumber}: trying match despite low confidence`)
            } else {
                this.logger.log(`[Step 7] ✅ Confidence OK (${extracted.confidence_score} >= ${minConfidence})`)
            }

            // ── Step 8: Match pole (with combined landmarks from all attempts) ─
            if (!panchayat) {
                return this.createManualReviewComplaint(
                    voiceCall.id, audioUrl, extracted, undefined, attemptNumber
                )
            }

            // Build the combined landmark list:
            // Current attempt's English + Tamil + all previous attempts' landmarks
            const currentLandmarks: string[] = []
            if (extracted.landmark_english) currentLandmarks.push(extracted.landmark_english)
            if (extracted.landmark) currentLandmarks.push(extracted.landmark)

            const allLandmarkHints = [...currentLandmarks, ...previousLandmarks]
            // Remove duplicates
            const uniqueHints = [...new Set(allLandmarkHints.filter(h => h.trim() !== ''))]

            this.logger.log(
                `[Step 8] Matching with ${uniqueHints.length} landmark hints: [${uniqueHints.join(' | ')}]`
            )

            const poleId = await this.geoMatching.findNearestPole(
                panchayat.id,
                uniqueHints  // pass ALL hints from all attempts
            )

            if (!poleId) {
                this.logger.warn(`[Step 8] No pole matched any of ${uniqueHints.length} hints`)

                if (attemptNumber === 1) {
                    await this.updateVoiceCallStatus(voiceCall.id, 'not_found')
                    return {
                        success: false,
                        status: 'not_found',
                        message: `Could not match landmark to any pole`
                    }
                }

                return this.createManualReviewComplaint(
                    voiceCall.id, audioUrl, extracted, panchayat.id, attemptNumber
                )
            }

            // ── Step 9: Duplicate check ───────────────────────────────────────
            const callerNumber = await this.getCallerNumber(callSid)
            if (callerNumber && poleId) {
                const dedupCutoff = new Date(Date.now() - DEDUP_WINDOW_HOURS * 60 * 60 * 1000)
                const existingComplaint = await this.prisma.complaint.findFirst({
                    where: {
                        pole_id: poleId,
                        panchayat_id: panchayat.id,
                        created_at: { gte: dedupCutoff },
                        status: { in: ['pending', 'in_progress'] }
                    },
                    select: { id: true }
                })

                if (existingComplaint) {
                    this.logger.warn(
                        `[Step 9] Duplicate detected — complaint #${existingComplaint.id} already exists ` +
                        `for pole ${poleId} within ${DEDUP_WINDOW_HOURS}h. Skipping creation.`
                    )
                    await this.updateVoiceCallStatus(voiceCall.id, 'completed')
                    await this.markPreviousAttempts(callSid, voiceCall.id)
                    return { success: true, status: 'completed', complaintId: existingComplaint.id }
                }
            }

            // ── Step 10: Create complaint ─────────────────────────────────────
            this.logger.log(`[Step 10] Creating complaint for pole ${poleId}`)

            const complaint = await this.prisma.complaint.create({
                data: {
                    voice_call_id: voiceCall.id,
                    pole_id: poleId,
                    panchayat_id: panchayat.id,
                    complaint_type: extracted.complaint_type || 'street_light',
                    description: extracted.transcript_english,
                    audio_url: audioUrl,
                    status: 'pending'
                }
            })

            await this.updateVoiceCallStatus(voiceCall.id, 'completed')
            await this.markPreviousAttempts(callSid, voiceCall.id)

            this.logger.log(
                `[Step 10] ✅ Complaint #${complaint.id} created ` +
                `(pole ${poleId}, panchayat "${panchayat.name}", attempt ${attemptNumber})`
            )
            return { success: true, status: 'completed', complaintId: complaint.id }

        } catch (error) {
            const errMessage = (error as Error).message ?? String(error)
            this.logger.error(`Pipeline failed: ${errMessage}`)

            // ── Graceful degradation ─────────────────────────────────────────
            // If AI is completely down on attempt 2+, still create a manual_review
            // complaint with just the audio URL so the admin can handle it.
            if (voiceCall) {
                try {
                    const attemptCount = await this.prisma.voiceCall.count({ where: { call_sid: callSid } })
                    if (attemptCount >= 2) {
                        this.logger.warn(`[Graceful Degradation] AI failed on attempt ${attemptCount} — creating manual_review complaint`)
                        const panchayat = await this.geoMatching.findPanchayatByIvrNumber(ivrNumber)
                        await this.prisma.complaint.create({
                            data: {
                                voice_call_id: voiceCall.id,
                                panchayat_id: panchayat?.id ?? null,
                                complaint_type: 'street_light',
                                description: `Auto-created: AI pipeline failed after ${attemptCount} attempts. Please listen to audio.`,
                                audio_url: audioUrl,
                                status: 'manual_review'
                            }
                        })
                        await this.updateVoiceCallStatus(voiceCall.id, 'manual_review')
                        return { success: true, status: 'manual_review', message: 'AI failed — flagged for manual review' }
                    }
                } catch (dbErr) {
                    this.logger.error(`Graceful degradation also failed: ${(dbErr as Error).message}`)
                }

                await this.updateVoiceCallStatus(voiceCall.id, 'failed').catch(dbErr =>
                    this.logger.error(`Failed to update VoiceCall status: ${(dbErr as Error).message}`)
                )
            }

            throw error

        } finally {
            releaseSlot()
            this.logger.log(`[Concurrency] Slot released (${activePipelines}/${MAX_CONCURRENT_PIPELINES} active)`)
        }
    }

    /**
     * Create a complaint flagged for manual_review.
     */
    private async createManualReviewComplaint(
        voiceCallId: number,
        audioUrl: string,
        extracted: ExtractedLocation,
        panchayatId: number | undefined,
        attemptNumber: number
    ): Promise<VoiceProcessingResult> {
        await this.updateVoiceCallStatus(voiceCallId, 'manual_review')

        const complaint = await this.prisma.complaint.create({
            data: {
                voice_call_id: voiceCallId,
                panchayat_id: panchayatId ?? null,
                complaint_type: extracted.complaint_type || 'street_light',
                description: extracted.transcript_english,
                audio_url: audioUrl,
                status: 'manual_review'
            }
        })

        this.logger.warn(
            `[Manual Review] Complaint #${complaint.id} (attempt ${attemptNumber}, confidence: ${extracted.confidence_score})`
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

    /** Get caller number from calls_master for dedup check. */
    private async getCallerNumber(callSid: string): Promise<string | null> {
        try {
            const call = await this.prisma.callsMaster.findUnique({
                where: { call_sid: callSid },
                select: { caller_number: true }
            })
            return call?.caller_number ?? null
        } catch {
            return null
        }
    }
}
