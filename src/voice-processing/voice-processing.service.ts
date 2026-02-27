import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { VoiceToTextService } from './voice-to-text.service'
import { LocationExtractionService, ExtractedLocation } from './location-extraction.service'
import { GeoMatchingService } from './geo-matching.service'

export type VoiceProcessingStatus = 'completed' | 'manual_review' | 'not_found'

export interface VoiceProcessingResult {
    success: boolean
    status: VoiceProcessingStatus
    complaintId?: number
    message?: string
}

/** Minimum extraction-confidence to proceed with pole matching on attempt 1 */
const MIN_CONFIDENCE_ATTEMPT_1 = 0.4
/** Minimum extraction-confidence to proceed with pole matching on attempt 2+ */
const MIN_CONFIDENCE_ATTEMPT_2 = 0.25

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
     *   1. Determine attempt number + clean up old failures
     *   2. Create VoiceCall record
     *   3. Transcribe audio (Whisper → Tamil text)
     *   4. GPT extraction (landmark, landmark_english, transcript_english, complaint_type)
     *   5. Resolve panchayat from IVR number → fill village = panchayat.name
     *   6. Save everything to VoiceCall (transcript, transcript_english, ai_extracted_json)
     *   7. Confidence check → retry (404) or continue
     *   8. Match pole by landmark_english (deterministic first, then AI fallback)
     *   9. Create complaint with audio_url + English description
     */
    async processVoiceComplaint(
        callSid: string,
        audioUrl: string,
        ivrNumber: string
    ): Promise<VoiceProcessingResult> {
        this.logger.log(`━━━ Voice Complaint Pipeline ━━━ CallSid: ${callSid}`)

        let voiceCall: { id: number } | null = null

        try {
            // ── Step 1: Determine attempt + clean up old failures ─────────────
            const previousAttempts = await this.prisma.voiceCall.count({
                where: { call_sid: callSid }
            })
            const attemptNumber = previousAttempts + 1
            this.logger.log(`[Step 1] Attempt #${attemptNumber} for CallSid: ${callSid}`)

            if (attemptNumber >= 2) {
                const deleted = await this.prisma.voiceCall.deleteMany({
                    where: {
                        call_sid: callSid,
                        processing_status: 'not_found'
                    }
                })
                if (deleted.count > 0) {
                    this.logger.log(`[Step 1] Cleaned up ${deleted.count} old failed attempt(s)`)
                }
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

            // ── Step 3: Transcribe audio (Whisper → Tamil text) ──────────────
            const transcript = await this.voiceToText.transcribeAudio(audioUrl)
            this.logger.log(`[Step 3] Tamil transcript: "${transcript}"`)

            if (!transcript || transcript.trim() === '') {
                this.logger.warn(`[Step 3] [FAIL] Empty transcript — cannot proceed`)
                await this.updateVoiceCallStatus(voiceCall.id, 'not_found')
                return {
                    success: false,
                    status: 'not_found',
                    message: 'Could not transcribe audio — please try again'
                }
            }

            // ── Step 4: GPT extraction + translation ─────────────────────────
            const extracted = await this.locationExtraction.extractLocation(transcript)
            this.logger.log(`[Step 4] Extraction: ${JSON.stringify(extracted)}`)

            // ── Step 5: Resolve panchayat → fill village name ────────────────
            const panchayat = await this.geoMatching.findPanchayatByIvrNumber(ivrNumber)

            if (panchayat) {
                extracted.village = panchayat.name
                this.logger.log(`[Step 5] [PASS] Village set to "${panchayat.name}" from IVR number ${ivrNumber}`)
            } else {
                this.logger.warn(`[Step 5] [FAIL] No panchayat found for IVR number: ${ivrNumber}`)
            }

            // ── Step 6: Save everything to VoiceCall ─────────────────────────
            await this.prisma.voiceCall.update({
                where: { id: voiceCall.id },
                data: {
                    transcript,
                    transcript_english: extracted.transcript_english,
                    ai_extracted_json: extracted as any,
                    confidence_score: extracted.confidence_score
                }
            })
            this.logger.log(`[Step 6] Saved transcript (Tamil + English) and AI extraction`)

            // ── Step 7: Confidence check ─────────────────────────────────────
            // Only reject truly unintelligible transcriptions.
            // The threshold is intentionally low because:
            //   - Tamil → English translations naturally get lower confidence from the LLM
            //   - Even with moderate confidence, the landmark might match deterministically
            const minConfidence = attemptNumber === 1 ? MIN_CONFIDENCE_ATTEMPT_1 : MIN_CONFIDENCE_ATTEMPT_2

            if (extracted.confidence_score < minConfidence) {
                this.logger.warn(
                    `[Step 7] [FAIL] Low confidence (${extracted.confidence_score} < ${minConfidence}) on attempt ${attemptNumber}`
                )

                if (attemptNumber === 1) {
                    await this.updateVoiceCallStatus(voiceCall.id, 'not_found')
                    return {
                        success: false,
                        status: 'not_found',
                        message: 'Low confidence — please try again with clearer pronunciation'
                    }
                }

                // Attempt 2+: still try to match the landmark before giving up
                this.logger.log(`[Step 7] Attempt ${attemptNumber}: trying pole match despite low confidence`)
            } else {
                this.logger.log(
                    `[Step 7] [PASS] Confidence OK (${extracted.confidence_score} >= ${minConfidence})`
                )
            }

            // ── Step 8: Match pole by English landmark ───────────────────────
            if (!panchayat) {
                return this.createManualReviewComplaint(
                    voiceCall.id, audioUrl, extracted, undefined, attemptNumber
                )
            }

            const landmarkForMatching = extracted.landmark_english || extracted.landmark
            this.logger.log(`[Step 8] Matching landmark: "${landmarkForMatching}"`)

            const poleId = await this.geoMatching.findNearestPole(panchayat.id, landmarkForMatching)

            if (!poleId) {
                this.logger.warn(
                    `[Step 8] [FAIL] No pole matched "${landmarkForMatching}" in panchayat "${panchayat.name}"`
                )

                if (attemptNumber === 1) {
                    await this.updateVoiceCallStatus(voiceCall.id, 'not_found')
                    return {
                        success: false,
                        status: 'not_found',
                        message: `Could not match landmark "${landmarkForMatching}" to any pole`
                    }
                }

                return this.createManualReviewComplaint(
                    voiceCall.id, audioUrl, extracted, panchayat.id, attemptNumber
                )
            }

            // ── Step 9: Create complaint (success!) ──────────────────────────
            this.logger.log(`[Step 9] Creating complaint for pole ${poleId}`)

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

            this.logger.log(
                `[Step 9] ✅ Complaint #${complaint.id} created ` +
                `(pole ${poleId}, panchayat "${panchayat.name}", attempt ${attemptNumber})`
            )
            return { success: true, status: 'completed', complaintId: complaint.id }

        } catch (error) {
            const errMessage = (error as Error).message ?? String(error)
            this.logger.error(`Pipeline failed: ${errMessage}`)

            if (voiceCall) {
                await this.updateVoiceCallStatus(voiceCall.id, 'failed').catch(dbErr =>
                    this.logger.error(`Failed to update VoiceCall status: ${(dbErr as Error).message}`)
                )
            }

            throw error
        }
    }

    /**
     * Helper: Create a complaint flagged for manual_review.
     * Used when confidence is low on attempt 2+, or when panchayat/pole can't be matched.
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
            `[Manual Review] Complaint #${complaint.id} created ` +
            `(attempt ${attemptNumber}, confidence: ${extracted.confidence_score})`
        )

        return {
            success: true,
            status: 'manual_review',
            complaintId: complaint.id,
            message: 'Flagged for manual review'
        }
    }

    /** Thin wrapper to update VoiceCall processing_status. */
    private async updateVoiceCallStatus(voiceCallId: number, status: string): Promise<void> {
        await this.prisma.voiceCall.update({
            where: { id: voiceCallId },
            data: { processing_status: status }
        })
    }
}
