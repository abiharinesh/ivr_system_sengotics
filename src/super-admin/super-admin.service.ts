import { Injectable, Logger, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import * as bcrypt from 'bcrypt'

/** Allowed complaint status values. */
const VALID_STATUSES = ['pending', 'in_progress', 'resolved', 'manual_review', 'rejected'] as const

@Injectable()
export class SuperAdminService {
    private readonly logger = new Logger(SuperAdminService.name)
    constructor(private prisma: PrismaService) { }

    // ── Panchayat Management ────────────────────────────────────────────────

    async createPanchayat(data: { name: string; ivr_number?: string; center_lat?: number; center_lng?: number }) {
        return this.prisma.panchayat.create({ data })
    }

    async updatePanchayat(id: number, data: { name?: string; ivr_number?: string; center_lat?: number; center_lng?: number }) {
        await this.ensurePanchayatExists(id)
        return this.prisma.panchayat.update({ where: { id }, data })
    }

    async deletePanchayat(id: number) {
        await this.ensurePanchayatExists(id)
        await this.prisma.panchayat.delete({ where: { id } })
        return { success: true }
    }

    async listPanchayats() {
        return this.prisma.panchayat.findMany({
            include: {
                _count: { select: { electric_poles: true, complaints: true, users: true } }
            }
        })
    }

    async getPanchayat(id: number) {
        const panchayat = await this.prisma.panchayat.findUnique({
            where: { id },
            include: { electric_poles: true, _count: { select: { complaints: true } } }
        })
        if (!panchayat) throw new NotFoundException(`Panchayat #${id} not found`)
        return panchayat
    }

    // ── User (Panchayat Admin) Management ──────────────────────────────────

    async createPanchayatAdmin(data: { email: string; password: string; panchayat_id: number }) {
        await this.ensurePanchayatExists(data.panchayat_id)

        const existing = await this.prisma.user.findUnique({ where: { email: data.email } })
        if (existing) throw new ForbiddenException('Email already in use')

        const password_hash = await bcrypt.hash(data.password, 10)
        return this.prisma.user.create({
            data: {
                email: data.email,
                password_hash,
                role: 'panchayat_admin',
                panchayat_id: data.panchayat_id
            },
            select: { id: true, email: true, role: true, panchayat_id: true, created_at: true }
        })
    }

    async listUsers() {
        return this.prisma.user.findMany({
            select: {
                id: true, email: true, role: true, panchayat_id: true, created_at: true,
                panchayat: { select: { name: true } }
            }
        })
    }

    async deleteUser(id: number) {
        const user = await this.prisma.user.findUnique({ where: { id } })
        if (!user) throw new NotFoundException(`User #${id} not found`)

        await this.prisma.user.delete({ where: { id } })
        return { success: true }
    }

    // ── Complaints (all) ───────────────────────────────────────────────────

    async listComplaints(status?: string, panchayatId?: number) {
        return this.prisma.complaint.findMany({
            where: {
                ...(status && { status }),
                ...(panchayatId && { panchayat_id: panchayatId })
            },
            include: { pole: true, panchayat: true, voice_call: true },
            orderBy: { created_at: 'desc' }
        })
    }

    async updateComplaintStatus(id: number, status: string) {
        if (!VALID_STATUSES.includes(status as any)) {
            throw new BadRequestException(
                `Invalid status "${status}". Must be one of: ${VALID_STATUSES.join(', ')}`
            )
        }

        const complaint = await this.prisma.complaint.findUnique({ where: { id } })
        if (!complaint) throw new NotFoundException(`Complaint #${id} not found`)

        return this.prisma.complaint.update({ where: { id }, data: { status } })
    }

    // ── Stats ──────────────────────────────────────────────────────────────

    async getStats() {
        const [complaints, pending, resolved, manual_review, poles, panchayats, users] = await Promise.all([
            this.prisma.complaint.count(),
            this.prisma.complaint.count({ where: { status: 'pending' } }),
            this.prisma.complaint.count({ where: { status: 'resolved' } }),
            this.prisma.complaint.count({ where: { status: 'manual_review' } }),
            this.prisma.electricPole.count(),
            this.prisma.panchayat.count(),
            this.prisma.user.count()
        ])
        return {
            total_complaints: complaints,
            pending_complaints: pending,
            resolved_complaints: resolved,
            manual_review_complaints: manual_review,
            total_poles: poles,
            total_panchayats: panchayats,
            total_admins: users
        }
    }

    // ── Private Helpers ────────────────────────────────────────────────────

    private async ensurePanchayatExists(id: number): Promise<void> {
        const exists = await this.prisma.panchayat.findUnique({ where: { id }, select: { id: true } })
        if (!exists) throw new NotFoundException(`Panchayat #${id} not found`)
    }
}
