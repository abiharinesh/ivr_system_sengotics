import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { IvrCallbackDto } from './dto/ivr-callback.dto'

// ── Service Map ────────────────────────────────────────────────────────────────
// Maps the digit the user presses in the main IVR menu to a complaint type.
// Add new services here without touching any other logic.
const SERVICE_MAP: Record<string, string> = {
    '1': 'street_light',
    '2': 'water',
    '3': 'garbage',
}

@Injectable()
export class IvrService {
    private readonly logger = new Logger(IvrService.name)

    constructor(private prisma: PrismaService) { }

    // ── Endpoint 1: Service Selection ─────────────────────────────────────────
    // Exotel calls this when the user presses a digit on the main menu.
    // We ONLY record which service was selected here. No complaint is created yet.
    async handleServiceSelection(data: IvrCallbackDto) {
        this.logger.log(`[EP1] Service selection for CallSid: ${data.CallSid}`)

        const cleanDigits = data.digits ? data.digits.replace(/"/g, '').trim() : null
        const serviceName = cleanDigits ? (SERVICE_MAP[cleanDigits] ?? `unknown_${cleanDigits}`) : null

        this.logger.log(`[EP1] User selected digit="${cleanDigits}" → service="${serviceName}"`)

        // Upsert calls_master
        await this.prisma.callsMaster.upsert({
            where: { call_sid: data.CallSid },
            create: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                call_to: data.CallTo,
                flow_id: data.flow_id,
                tenant_id: data.tenant_id,
                call_start_time: data.StartTime ? new Date(data.StartTime) : null,
                call_end_time: data.EndTime ? new Date(data.EndTime) : null,
                service_selected: !!cleanDigits,
            },
            update: {
                service_selected: !!cleanDigits,
                updated_at: new Date(),
            }
        })

        // Record the service selection (digit + resolved service name)
        await this.prisma.ivrServiceSelection.create({
            data: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                service_option: cleanDigits,   // raw digit, e.g. "1"
                raw_payload: { ...data as any, resolved_service: serviceName }
            }
        })

        this.logger.log(`[EP1] Saved service selection. Waiting for EP2 to collect details.`)
        return { success: true }
    }

    // ── Endpoint 2: Poll / Detail Input ──────────────────────────────────────
    // Exotel calls this after the user enters more detail (e.g. pole number).
    // THIS is where complaints are created, branching per service type.
    async handlePollInput(data: IvrCallbackDto): Promise<{ found: boolean }> {
        this.logger.log(`[EP2] Poll input for CallSid: ${data.CallSid}`)

        const cleanDigits = data.digits ? data.digits.replace(/"/g, '').trim() : null

        // Upsert calls_master
        await this.prisma.callsMaster.upsert({
            where: { call_sid: data.CallSid },
            create: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                call_to: data.CallTo,
                flow_id: data.flow_id,
                tenant_id: data.tenant_id,
                call_start_time: data.StartTime ? new Date(data.StartTime) : null,
                poll_entered: !!cleanDigits,
            },
            update: {
                poll_entered: !!cleanDigits,
                updated_at: new Date(),
            }
        })

        // Save the raw poll input
        await this.prisma.ivrPollInput.create({
            data: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                poll_id: cleanDigits,
                raw_payload: data as any
            }
        })

        if (!cleanDigits || !data.CallTo) {
            this.logger.warn(`[EP2] Missing digits or CallTo — skipping complaint creation`)
            return { found: false }
        }

        // ── Lookup which service was selected in EP1 ──────────────────────────
        const serviceSelection = await this.prisma.ivrServiceSelection.findFirst({
            where: { call_sid: data.CallSid },
            orderBy: { received_at: 'desc' }
        })

        if (!serviceSelection?.service_option) {
            this.logger.warn(`[EP2] No service selection found for CallSid=${data.CallSid}`)
            return { found: false }
        }

        const serviceDigit = serviceSelection.service_option
        const serviceType = SERVICE_MAP[serviceDigit] ?? `unknown_${serviceDigit}`

        this.logger.log(`[EP2] Service="${serviceType}", detail digit="${cleanDigits}"`)

        // ── Lookup Panchayat by the IVR number dialed ─────────────────────────
        const panchayat = await this.prisma.panchayat.findFirst({
            where: { ivr_number: data.CallTo }
        })

        if (!panchayat) {
            this.logger.warn(`[EP2] No panchayat found for IVR number: ${data.CallTo}`)
            return { found: false }
        }

        // ── Branch: create complaint based on service type ────────────────────
        try {
            switch (serviceType) {

                case 'street_light': {
                    // cleanDigits = the pole keypad_id the user entered
                    const pole = await this.prisma.electricPole.findFirst({
                        where: { panchayat_id: panchayat.id, keypad_id: cleanDigits }
                    })

                    if (!pole) {
                        this.logger.warn(`[EP2] No pole found with keypad_id="${cleanDigits}" in panchayat "${panchayat.name}" — returning 404`)
                        return { found: false }
                    }

                    const complaint = await this.prisma.complaint.create({
                        data: {
                            pole_id: pole.id,
                            panchayat_id: panchayat.id,
                            complaint_type: 'street_light',
                            description: `IVR street light complaint for pole ${pole.pole_number} (keypad: ${cleanDigits}) from ${data.CallFrom}`,
                            status: 'pending'
                        }
                    })
                    this.logger.log(`[EP2] ✅ Street light complaint #${complaint.id} created for pole ${pole.pole_number}`)
                    break
                }

                case 'water': {
                    // cleanDigits could be a ward number or area code in future
                    const complaint = await this.prisma.complaint.create({
                        data: {
                            panchayat_id: panchayat.id,
                            complaint_type: 'water',
                            description: `IVR water complaint from ${data.CallFrom} (input: ${cleanDigits})`,
                            status: 'pending'
                        }
                    })
                    this.logger.log(`[EP2] ✅ Water complaint #${complaint.id} created`)
                    break
                }

                case 'garbage': {
                    const complaint = await this.prisma.complaint.create({
                        data: {
                            panchayat_id: panchayat.id,
                            complaint_type: 'garbage',
                            description: `IVR garbage complaint from ${data.CallFrom} (input: ${cleanDigits})`,
                            status: 'pending'
                        }
                    })
                    this.logger.log(`[EP2] ✅ Garbage complaint #${complaint.id} created`)
                    break
                }

                default: {
                    // Unknown service — log it but don't crash
                    const complaint = await this.prisma.complaint.create({
                        data: {
                            panchayat_id: panchayat.id,
                            complaint_type: serviceType,
                            description: `IVR complaint from ${data.CallFrom} — service "${serviceType}" (input: ${cleanDigits})`,
                            status: 'pending'
                        }
                    })
                    this.logger.log(`[EP2] ✅ Generic complaint #${complaint.id} for service "${serviceType}"`)
                    break
                }
            }
        } catch (err) {
            this.logger.error(`[EP2] Failed to create complaint: ${err}`)
            return { found: false }
        }

        return { found: true }
    }

    // ── Endpoint 3: Voicemail ──────────────────────────────────────────────────
    // Exotel calls this when the user leaves a voice recording.
    async handleVoicemail(data: IvrCallbackDto) {
        this.logger.log(`[EP3] Voicemail for CallSid: ${data.CallSid}`)

        await this.prisma.callsMaster.upsert({
            where: { call_sid: data.CallSid },
            create: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                call_to: data.CallTo,
                flow_id: data.flow_id,
                tenant_id: data.tenant_id,
                call_start_time: data.StartTime ? new Date(data.StartTime) : null,
                call_end_time: data.EndTime ? new Date(data.EndTime) : null,
                voicemail_left: !!data.RecordingUrl,
            },
            update: {
                voicemail_left: !!data.RecordingUrl,
                updated_at: new Date(),
            }
        })

        await this.prisma.ivrVoicemail.create({
            data: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                recording_url: data.RecordingUrl,
                recording_available_by: data.RecordingAvailableBy ? new Date(data.RecordingAvailableBy) : null,
                raw_payload: data as any
            }
        })

        this.logger.log(`[EP3] Voicemail saved for CallSid: ${data.CallSid}`)
        return { success: true }
    }
}
