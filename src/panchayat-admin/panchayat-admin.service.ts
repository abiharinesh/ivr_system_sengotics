import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

@Injectable()
export class PanchayatAdminService {
    constructor(private prisma: PrismaService) { }

    // ── Profile ────────────────────────────────────────────────────────────
    async getMe(userId: number) {
        return this.prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, email: true, role: true, panchayat_id: true, panchayat: true }
        })
    }

    // ── Pole Management (scoped to their panchayat) ────────────────────────
    async createPole(panchayatId: number, data: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number }) {
        const pole = await this.prisma.electricPole.create({
            data: { ...data, panchayat_id: panchayatId }
        })
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

    async updatePole(panchayatId: number, poleId: number, data: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number }) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole || pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied')
        return this.prisma.electricPole.update({ where: { id: poleId }, data })
    }

    async deletePole(panchayatId: number, poleId: number) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole || pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied')
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
        const complaint = await this.prisma.complaint.findUnique({ where: { id: complaintId } })
        if (!complaint || complaint.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied')
        return this.prisma.complaint.update({ where: { id: complaintId }, data: { status } })
    }

    // ── Stats (scoped to their panchayat) ─────────────────────────────────
    async getStats(panchayatId: number) {
        const [total, pending, resolved, poles] = await Promise.all([
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId } }),
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId, status: 'pending' } }),
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId, status: 'resolved' } }),
            this.prisma.electricPole.count({ where: { panchayat_id: panchayatId } })
        ])
        return { total_complaints: total, pending_complaints: pending, resolved_complaints: resolved, total_poles: poles }
    }
}
