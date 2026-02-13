import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { VoiceToTextService } from './voice-to-text.service'
import { LocationExtractionService } from './location-extraction.service'
import { GeoMatchingService } from './geo-matching.service'

@Injectable()
export class VoiceProcessingService {
    private readonly logger = new Logger(VoiceProcessingService.name)

    constructor(
        private prisma: PrismaService,
        private voiceToText: VoiceToTextService,
        private locationExtraction: LocationExtractionService,
        private geoMatching: GeoMatchingService
    ) { }

    async processVoiceComplaint(callSid: string, audioUrl: string) {
        this.logger.log(`Processing voice complaint for CallSid: ${callSid}`)

        try {
            // Step 1: Create voice call record
            const voiceCall = await this.prisma.voiceCall.create({
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

            // Step 4: Check confidence threshold
            if (extracted.confidence_score < 0.65) {
                await this.prisma.voiceCall.update({
                    where: { id: voiceCall.id },
                    data: { processing_status: 'manual_review' }
                })
                this.logger.warn(`Low confidence (${extracted.confidence_score}), flagged for manual review`)
                return { success: true, status: 'manual_review' }
            }

            // Step 5: Match panchayat
            const panchayatId = await this.geoMatching.findPanchayatByName(extracted.village)
            if (!panchayatId) {
                await this.prisma.voiceCall.update({
                    where: { id: voiceCall.id },
                    data: { processing_status: 'manual_review' }
                })
                this.logger.warn(`Village not found: ${extracted.village}`)
                return { success: true, status: 'manual_review' }
            }

            // Step 6: Find nearest pole
            const poleId = await this.geoMatching.findNearestPole(panchayatId, extracted.landmark)
            if (!poleId) {
                await this.prisma.voiceCall.update({
                    where: { id: voiceCall.id },
                    data: { processing_status: 'manual_review' }
                })
                this.logger.warn(`No pole found for panchayat: ${panchayatId}`)
                return { success: true, status: 'manual_review' }
            }

            // Step 7: Create complaint
            await this.prisma.complaint.create({
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

            this.logger.log(`Complaint created successfully for CallSid: ${callSid}`)
            return { success: true, status: 'completed' }
        } catch (error) {
            this.logger.error(`Voice processing failed: ${error.message}`)
            throw error
        }
    }
}
