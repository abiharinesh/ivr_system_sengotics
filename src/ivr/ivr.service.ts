import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { IvrCallbackDto } from './dto/ivr-callback.dto'

// ── Service Map ────────────────────────────────────────────────────────────────
// Maps the digit the user presses in the main IVR menu to a complaint type.
const SERVICE_MAP: Record<string, string> = {
    '1': 'street_light',
    '2': 'water',
    '3': 'garbage',
}

export interface PollInputResult {
    found: boolean
    complaintId?: number
}

@Injectable()
export class IvrService {
    private readonly logger = new Logger(IvrService.name)

    constructor(private prisma: PrismaService) { }

    // ── EP1: Service Selection ────────────────────────────────────────────────
    async handleServiceSelection(data: IvrCallbackDto): Promise<{ success: boolean }> {
        const callSid = data.CallSid || `UNKNOWN_${Date.now()}`
        this.logger.log(`[EP1] Service selection for CallSid: ${callSid}`)

        const cleanDigits = this.cleanDigits(data.digits)
        const serviceName = cleanDigits ? (SERVICE_MAP[cleanDigits] ?? `unknown_${cleanDigits}`) : null

        this.logger.log(`[EP1] User selected digit="${cleanDigits}" → service="${serviceName}"`)

        try {
            // Upsert calls_master
            await this.prisma.callsMaster.upsert({
                where: { call_sid: callSid },
                create: {
                    call_sid: callSid,
                    caller_number: data.CallFrom ?? data.From,
                    call_to: data.CallTo ?? data.To,
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

            // Record the service selection
            await this.prisma.ivrServiceSelection.create({
                data: {
                    call_sid: callSid,
                    caller_number: data.CallFrom ?? data.From,
                    service_option: cleanDigits,
                    raw_payload: { ...data as any, resolved_service: serviceName }
                }
            })

            this.logger.log(`[EP1] ✅ Saved service selection.`)
        } catch (err) {
            this.logger.error(`[EP1] DB error (non-fatal): ${(err as Error).message}`)
            // Don't re-throw — EP1 must never fail the response
        }

        return { success: true }
    }

    // ── EP2: Poll / Detail Input ─────────────────────────────────────────────
    async handlePollInput(data: IvrCallbackDto): Promise<PollInputResult> {
        const callSid = data.CallSid || `UNKNOWN_${Date.now()}`
        this.logger.log(`[EP2] Poll input for CallSid: ${callSid}`)

        const cleanDigits = this.cleanDigits(data.digits)

        try {
            // Upsert calls_master
            await this.prisma.callsMaster.upsert({
                where: { call_sid: callSid },
                create: {
                    call_sid: callSid,
                    caller_number: data.CallFrom ?? data.From,
                    call_to: data.CallTo ?? data.To,
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
                    call_sid: callSid,
                    caller_number: data.CallFrom ?? data.From,
                    poll_id: cleanDigits,
                    raw_payload: data as any
                }
            })
        } catch (err) {
            this.logger.error(`[EP2] DB recording error (non-fatal): ${(err as Error).message}`)
            // Continue — we still try to create the complaint
        }

        const callTo = data.CallTo ?? data.To
        if (!cleanDigits || !callTo) {
            this.logger.warn(`[EP2] Missing digits or CallTo — skipping complaint creation`)
            return { found: false }
        }

        // ── Lookup which service was selected in EP1 ──────────────────────────
        let serviceSelection: { service_option: string | null } | null = null
        try {
            serviceSelection = await this.prisma.ivrServiceSelection.findFirst({
                where: { call_sid: callSid },
                orderBy: { received_at: 'desc' }
            })
        } catch (err) {
            this.logger.error(`[EP2] Service lookup failed: ${(err as Error).message}`)
        }

        if (!serviceSelection?.service_option) {
            this.logger.warn(`[EP2] No service selection found for CallSid=${callSid}`)
            return { found: false }
        }

        const serviceDigit = serviceSelection.service_option
        const serviceType = SERVICE_MAP[serviceDigit] ?? `unknown_${serviceDigit}`

        this.logger.log(`[EP2] Service="${serviceType}", detail digit="${cleanDigits}"`)

        // ── Lookup Panchayat by the IVR number dialed ─────────────────────────
        const panchayat = await this.prisma.panchayat.findFirst({
            where: { ivr_number: callTo }
        })

        if (!panchayat) {
            this.logger.warn(`[EP2] No panchayat found for IVR number: ${callTo}`)
            return { found: false }
        }

        // ── Create complaint based on service type ────────────────────────────
        try {
            const complaint = await this.createServiceComplaint(
                serviceType, cleanDigits, panchayat.id, data.CallFrom ?? data.From ?? 'unknown'
            )
            return { found: true, complaintId: complaint.id }
        } catch (err) {
            this.logger.error(`[EP2] Failed to create complaint: ${(err as Error).message}`)
            return { found: false }
        }
    }

    // ── Private Helpers ─────────────────────────────────────────────────────────

    /** Clean and normalize digits from Exotel (strip quotes and whitespace). */
    private cleanDigits(raw?: string): string | null {
        if (!raw) return null
        const cleaned = raw.replace(/"/g, '').trim()
        return cleaned || null
    }

    /** Create a complaint for the given service type. */
    private async createServiceComplaint(
        serviceType: string,
        detail: string,
        panchayatId: number,
        callerNumber: string
    ): Promise<{ id: number }> {
        // For street_light, look up the specific pole
        if (serviceType === 'street_light') {
            const pole = await this.prisma.electricPole.findFirst({
                where: { panchayat_id: panchayatId, keypad_id: detail }
            })

            if (!pole) {
                this.logger.warn(
                    `[EP2] No pole found with keypad_id="${detail}" in panchayat ${panchayatId}`
                )
                throw new Error(`Pole with keypad_id="${detail}" not found`)
            }

            const complaint = await this.prisma.complaint.create({
                data: {
                    pole_id: pole.id,
                    panchayat_id: panchayatId,
                    complaint_type: 'street_light',
                    description: `IVR street light complaint for pole ${pole.pole_number} (keypad: ${detail}) from ${callerNumber}`,
                    status: 'pending'
                }
            })
            this.logger.log(`[EP2] ✅ Street light complaint #${complaint.id} created for pole ${pole.pole_number}`)
            return complaint
        }

        // For all other services, create a generic complaint
        const complaint = await this.prisma.complaint.create({
            data: {
                panchayat_id: panchayatId,
                complaint_type: serviceType,
                description: `IVR ${serviceType} complaint from ${callerNumber} (input: ${detail})`,
                status: 'pending'
            }
        })
        this.logger.log(`[EP2] ✅ ${serviceType} complaint #${complaint.id} created`)
        return complaint
    }
}
