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
     *   7. Confidence check → retry (404) or manual_review
     *   8. Match pole by landmark_english
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

            // ── Step 4: GPT extraction + translation ─────────────────────────
            // Returns: landmark (Tamil), landmark_english, transcript_english,
            //          village (may be empty), complaint_type, confidence_score
            const extracted = await this.locationExtraction.extractLocation(transcript)
            this.logger.log(`[Step 4] Extraction: ${JSON.stringify(extracted)}`)

            // ── Step 5: Resolve panchayat → fill village name ────────────────
            // The IVR number maps to a panchayat. The panchayat name IS the village.
            // This is more reliable than GPT extracting it from the transcript.
            const panchayat = await this.geoMatching.findPanchayatByIvrNumber(ivrNumber)

            if (panchayat) {
                // Fill the village from the panchayat name (authoritative source)
                extracted.village = panchayat.name
                this.logger.log(`[Step 5] Village set to "${panchayat.name}" from IVR number ${ivrNumber}`)
            } else {
                this.logger.warn(`[Step 5] No panchayat found for IVR number: ${ivrNumber}`)
            }

            // ── Step 6: Save everything to VoiceCall ─────────────────────────
            // One consolidated DB call: transcript + English translation + AI JSON
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
            if (extracted.confidence_score < 0.65) {
                if (attemptNumber === 1) {
                    await this.prisma.voiceCall.update({
                        where: { id: voiceCall.id },
                        data: { processing_status: 'not_found' }
                    })
                    this.logger.warn(
                        `[Step 7] Low confidence (${extracted.confidence_score}) on attempt 1 → 404 for retry`
                    )
                    return {
                        success: false,
                        status: 'not_found',
                        message: 'Low confidence — please try again with clearer pronunciation'
                    }
                } else {
                    return this.createManualReviewComplaint(
                        voiceCall.id, audioUrl, extracted, panchayat?.id, attemptNumber
                    )
                }
            }

            // ── Step 8: Match pole by English landmark ───────────────────────
            if (!panchayat) {
                // No panchayat → can't match pole → manual review
                return this.createManualReviewComplaint(
                    voiceCall.id, audioUrl, extracted, undefined, attemptNumber
                )
            }

            const landmarkForMatching = extracted.landmark_english || extracted.landmark
            const poleId = await this.geoMatching.findNearestPole(panchayat.id, landmarkForMatching)

            if (!poleId) {
                this.logger.warn(
                    `[Step 8] No pole matched "${landmarkForMatching}" in panchayat "${panchayat.name}"`
                )

                if (attemptNumber === 1) {
                    await this.prisma.voiceCall.update({
                        where: { id: voiceCall.id },
                        data: { processing_status: 'not_found' }
                    })
                    return {
                        success: false,
                        status: 'not_found',
                        message: `Could not match landmark "${landmarkForMatching}" to any pole`
                    }
                } else {
                    return this.createManualReviewComplaint(
                        voiceCall.id, audioUrl, extracted, panchayat.id, attemptNumber
                    )
                }
            }

            // ── Step 9: Create complaint (success!) ──────────────────────────
            const complaint = await this.prisma.complaint.create({
                data: {
                    voice_call_id: voiceCall.id,
                    pole_id: poleId,
                    panchayat_id: panchayat.id,
                    complaint_type: extracted.complaint_type,
                    description: extracted.transcript_english,   // English for admin dashboard
                    audio_url: audioUrl,
                    status: 'pending'
                }
            })

            await this.prisma.voiceCall.update({
                where: { id: voiceCall.id },
                data: { processing_status: 'completed' }
            })

            this.logger.log(
                `[Step 9] ✅ Complaint #${complaint.id} created ` +
                `(pole ${poleId}, panchayat "${panchayat.name}", attempt ${attemptNumber})`
            )
            return { success: true, status: 'completed', complaintId: complaint.id }

        } catch (error) {
            this.logger.error(`Pipeline failed: ${error.message}`)

            if (voiceCall) {
                try {
                    await this.prisma.voiceCall.update({
                        where: { id: voiceCall.id },
                        data: { processing_status: 'failed' }
                    })
                } catch (dbError) {
                    this.logger.error(`Failed to update VoiceCall status: ${dbError.message}`)
                }
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
        await this.prisma.voiceCall.update({
            where: { id: voiceCallId },
            data: { processing_status: 'manual_review' }
        })

        const complaint = await this.prisma.complaint.create({
            data: {
                voice_call_id: voiceCallId,
                panchayat_id: panchayatId ?? null,
                complaint_type: extracted.complaint_type,
                description: extracted.transcript_english,   // English for admin dashboard
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
}
