import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

/** Allowed complaint status values. */
const VALID_STATUSES = ['pending', 'in_progress', 'resolved', 'manual_review', 'rejected'] as const

@Injectable()
export class PanchayatAdminService {
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
