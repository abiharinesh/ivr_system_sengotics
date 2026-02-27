import { Injectable, Logger, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

/** Allowed complaint status values. */
const VALID_STATUSES = ['pending', 'in_progress', 'resolved', 'manual_review', 'rejected'] as const

@Injectable()
export class PanchayatAdminService {
    private readonly logger = new Logger(PanchayatAdminService.name)
    constructor(private prisma: PrismaService) { }

    // ── Profile ────────────────────────────────────────────────────────────

    async getMe(userId: number) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, email: true, role: true, panchayat_id: true, panchayat: true }
        })
        if (!user) throw new NotFoundException('User not found')
        return user
    }

    // ── Pole Management (scoped to their panchayat) ────────────────────────

    async createPole(panchayatId: number, data: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) {
        const pole = await this.prisma.electricPole.create({
            data: {
                pole_number: data.pole_number,
                keypad_id: data.keypad_id,
                latitude: data.latitude,
                longitude: data.longitude,
                landmarks: data.landmarks ?? [],
                panchayat_id: panchayatId
            }
        })

        // Set PostGIS geometry if coordinates are provided
        if (data.latitude && data.longitude) {
            await this.prisma.$executeRaw`
                UPDATE electric_poles
                SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)
                WHERE id = ${pole.id}
            `
        }
        return pole
    }

    async listPoles(panchayatId: number) {
        return this.prisma.electricPole.findMany({
            where: { panchayat_id: panchayatId },
            include: { _count: { select: { complaints: true } } }
        })
    }

    async updatePole(panchayatId: number, poleId: number, data: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })

        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)
        if (pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — pole belongs to another panchayat')

        const updated = await this.prisma.electricPole.update({ where: { id: poleId }, data })

        // Update PostGIS geometry if coordinates changed
        if (data.latitude && data.longitude) {
            await this.prisma.$executeRaw`
                UPDATE electric_poles
                SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)
                WHERE id = ${poleId}
            `
        }

        return updated
    }

    async deletePole(panchayatId: number, poleId: number) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })

        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)
        if (pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — pole belongs to another panchayat')

        await this.prisma.electricPole.delete({ where: { id: poleId } })
        return { success: true }
    }

    // ── Complaint Management (scoped to their panchayat) ──────────────────

    async listComplaints(panchayatId: number, status?: string) {
        return this.prisma.complaint.findMany({
            where: { panchayat_id: panchayatId, ...(status && { status }) },
            include: { pole: true, voice_call: true },
            orderBy: { created_at: 'desc' }
        })
    }

    async updateComplaintStatus(panchayatId: number, complaintId: number, status: string) {
        if (!VALID_STATUSES.includes(status as any)) {
            throw new BadRequestException(
                `Invalid status "${status}". Must be one of: ${VALID_STATUSES.join(', ')}`
            )
        }

        const complaint = await this.prisma.complaint.findUnique({ where: { id: complaintId } })

        if (!complaint) throw new NotFoundException(`Complaint #${complaintId} not found`)
        if (complaint.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — complaint belongs to another panchayat')

        return this.prisma.complaint.update({ where: { id: complaintId }, data: { status } })
    }

    /**
     * Resolve a manual_review complaint by assigning it to a pole.
     * Scoped: pole must belong to this admin's panchayat.
     * Auto-learns: saves the caller's landmark phrase to the pole.
     */
    async resolveComplaint(panchayatId: number, complaintId: number, poleId: number) {
        // 1. Validate complaint
        const complaint = await this.prisma.complaint.findUnique({
            where: { id: complaintId },
            include: { voice_call: true }
        })
        if (!complaint) throw new NotFoundException(`Complaint #${complaintId} not found`)
        if (complaint.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — complaint belongs to another panchayat')

        // 2. Validate pole belongs to this panchayat
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)
        if (pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — pole belongs to another panchayat')

        // 3. Assign pole and update status
        const updated = await this.prisma.complaint.update({
            where: { id: complaintId },
            data: { pole_id: poleId, status: 'pending' },
            include: { pole: true }
        })

        // 4. Auto-learn landmark
        await this.learnLandmark(complaint, pole)

        this.logger.log(`✅ Complaint #${complaintId} resolved → pole #${poleId}`)
        return updated
    }

    /** Learn new landmark phrases from resolved voice complaints. */
    private async learnLandmark(
        complaint: { voice_call_id: number | null; voice_call: { ai_extracted_json: any } | null },
        pole: { id: number; landmarks: string[] }
    ): Promise<void> {
        if (!complaint.voice_call?.ai_extracted_json) return

        const extracted = complaint.voice_call.ai_extracted_json as Record<string, any>
        const newLandmarks: string[] = []

        if (extracted.landmark_english && typeof extracted.landmark_english === 'string') {
            newLandmarks.push(extracted.landmark_english.trim())
        }
        if (extracted.landmark && typeof extracted.landmark === 'string') {
            newLandmarks.push(extracted.landmark.trim())
        }

        if (newLandmarks.length === 0) return

        const existingLower = pole.landmarks.map(l => l.toLowerCase())
        const uniqueNew = newLandmarks.filter(
            l => l.length > 0 && !existingLower.includes(l.toLowerCase())
        )

        if (uniqueNew.length === 0) return

        await this.prisma.electricPole.update({
            where: { id: pole.id },
            data: { landmarks: [...pole.landmarks, ...uniqueNew] }
        })

        this.logger.log(
            `[Learn] ✅ Added ${uniqueNew.length} new landmark(s) to pole #${pole.id}: ${uniqueNew.join(', ')}`
        )
    }

    // ── Stats (scoped to their panchayat) ─────────────────────────────────

    async getStats(panchayatId: number) {
        const [total, pending, resolved, manual_review, poles] = await Promise.all([
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId } }),
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId, status: 'pending' } }),
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId, status: 'resolved' } }),
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId, status: 'manual_review' } }),
            this.prisma.electricPole.count({ where: { panchayat_id: panchayatId } })
        ])
        return {
            total_complaints: total,
            pending_complaints: pending,
            resolved_complaints: resolved,
            manual_review_complaints: manual_review,
            total_poles: poles
        }
    }
}
