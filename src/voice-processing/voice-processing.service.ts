import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { VoiceToTextService } from './voice-to-text.service'
import { LocationExtractionService } from './location-extraction.service'
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

    async processVoiceComplaint(callSid: string, audioUrl: string, ivrNumber: string): Promise<VoiceProcessingResult> {
        this.logger.log(`Processing voice complaint for CallSid: ${callSid}`)

        let voiceCall;
        try {
            // Step 1: Create voice call record
            voiceCall = await this.prisma.voiceCall.create({
                data: {
                    call_sid: callSid,
                    audio_url: audioUrl,
                    processing_status: 'processing'
                }
            })

            // Step 2: Transcribe audio
            const transcript = await this.voiceToText.transcribeAudio(audioUrl)
            await this.prisma.voiceCall.update({
                where: { id: voiceCall.id },
                data: { transcript }
            })

            // Step 3: Extract location and complaint info
            const extracted = await this.locationExtraction.extractLocation(transcript)
            await this.prisma.voiceCall.update({
                where: { id: voiceCall.id },
                data: {
                    ai_extracted_json: extracted as any,
                    confidence_score: extracted.confidence_score
                }
            })

            // Check how many attempts (audio files) we've processed for this session
            const attemptCount = await this.prisma.voiceCall.count({
                where: { call_sid: callSid }
            })
            this.logger.log(`CallSid ${callSid} is on attempt #${attemptCount}`);

            // Step 4: Check confidence threshold
            if (extracted.confidence_score < 0.65) {
                if (attemptCount === 1) {
                    // First attempt: return not_found -> triggers 404 in controller -> Exotel retry flow
                    await this.prisma.voiceCall.update({
                        where: { id: voiceCall.id },
                        data: { processing_status: 'not_found' }
                    })
                    this.logger.warn(`Low confidence (${extracted.confidence_score}) on attempt 1, returning 404 to prompt retry.`)
                    return { success: false, status: 'not_found', message: 'Low confidence — please try again with clearer pronunciation' }
                } else {
                    // Second attempt: accept for manual review -> returns 200 in controller
                    // but WE MUST STILL create a complaint record so admins can see it.
                    await this.prisma.voiceCall.update({
                        where: { id: voiceCall.id },
                        data: { processing_status: 'manual_review' }
                    })

                    const complaint = await this.prisma.complaint.create({
                        data: {
                            voice_call_id: voiceCall.id,
                            complaint_type: extracted.complaint_type,
                            description: transcript,
                            status: 'manual_review'
                        }
                    })

                    this.logger.warn(`Low confidence (${extracted.confidence_score}) on attempt ${attemptCount}, flagged for manual review. Created complaint #${complaint.id}`)
                    return { success: true, status: 'manual_review', complaintId: complaint.id, message: 'Low confidence — flagged for manual review' }
                }
            }

            // Step 5: Match panchayat using the IVR number dialed
            const panchayatId = await this.geoMatching.findPanchayatByIvrNumber(ivrNumber)
            if (!panchayatId) {
                await this.prisma.voiceCall.update({
                    where: { id: voiceCall.id },
                    data: { processing_status: 'manual_review' }
                })

                const complaint = await this.prisma.complaint.create({
                    data: {
                        voice_call_id: voiceCall.id,
                        complaint_type: extracted.complaint_type,
                        description: transcript,
                        status: 'manual_review'
                    }
                })

                this.logger.warn(`Panchayat not found for IVR number: ${ivrNumber}. Created complaint #${complaint.id}`)
                return { success: true, status: 'manual_review', complaintId: complaint.id, message: `Panchayat not found for IVR number: ${ivrNumber}` }
            }

            // Step 6: Find nearest pole using AI landmark matching
            const poleId = await this.geoMatching.findNearestPole(panchayatId, extracted.landmark)
            if (!poleId) {
                await this.prisma.voiceCall.update({
                    where: { id: voiceCall.id },
                    data: { processing_status: 'not_found' }
                })
                this.logger.warn(`No pole matched landmark "${extracted.landmark}" in panchayat ${panchayatId} (Attempt ${attemptCount})`)
                // Return not_found so the controller can respond 404 to Exotel
                return {
                    success: false,
                    status: 'not_found',
                    message: `Could not match landmark "${extracted.landmark}" to any pole in panchayat`
                }
            }

            // Step 7: Create complaint
            const complaint = await this.prisma.complaint.create({
                data: {
                    voice_call_id: voiceCall.id,
                    pole_id: poleId,
                    panchayat_id: panchayatId,
                    complaint_type: extracted.complaint_type,
                    description: transcript,
                    status: 'pending'
                }
            })

            // Update voice call status
            await this.prisma.voiceCall.update({
                where: { id: voiceCall.id },
                data: { processing_status: 'completed' }
            })

            this.logger.log(`Complaint #${complaint.id} created successfully for CallSid: ${callSid}`)
            return { success: true, status: 'completed', complaintId: complaint.id }

        } catch (error) {
            this.logger.error(`Voice processing failed: ${error.message}`)

            if (voiceCall) {
                try {
                    await this.prisma.voiceCall.update({
                        where: { id: voiceCall.id },
                        data: { processing_status: 'failed' }
                    })
                } catch (dbError) {
                    this.logger.error(`Failed to update voiceCall status: ${dbError.message}`)
                }
            }

            throw error
        }
    }
}
