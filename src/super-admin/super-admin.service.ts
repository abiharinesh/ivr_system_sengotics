import { Injectable, Logger, NotFoundException, ForbiddenException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import * as bcrypt from 'bcrypt'

@Injectable()
export class SuperAdminService {
    private readonly logger = new Logger(SuperAdminService.name)
    constructor(private prisma: PrismaService) { }

    // ── Panchayat Management ────────────────────────────────────────────────
    async createPanchayat(data: { name: string; ivr_number?: string; center_lat?: number; center_lng?: number }) {
        return this.prisma.panchayat.create({ data })
    }

    async updatePanchayat(id: number, data: { name?: string; ivr_number?: string; center_lat?: number; center_lng?: number }) {
        return this.prisma.panchayat.update({ where: { id }, data })
    }

    async deletePanchayat(id: number) {
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
        return this.prisma.panchayat.findUnique({
            where: { id },
            include: { electric_poles: true, _count: { select: { complaints: true } } }
        })
    }

    // ── User (Panchayat Admin) Management ──────────────────────────────────
    async createPanchayatAdmin(data: { email: string; password: string; panchayat_id: number }) {
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
            select: { id: true, email: true, role: true, panchayat_id: true, created_at: true, panchayat: { select: { name: true } } }
        })
    }

    async deleteUser(id: number) {
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
        return this.prisma.complaint.update({ where: { id }, data: { status } })
    }

    // ── Stats ──────────────────────────────────────────────────────────────
    async getStats() {
        const [complaints, pending, resolved, poles, panchayats, users] = await Promise.all([
            this.prisma.complaint.count(),
            this.prisma.complaint.count({ where: { status: 'pending' } }),
            this.prisma.complaint.count({ where: { status: 'resolved' } }),
            this.prisma.electricPole.count(),
            this.prisma.panchayat.count(),
            this.prisma.user.count()
        ])
        return { total_complaints: complaints, pending_complaints: pending, resolved_complaints: resolved, total_poles: poles, total_panchayats: panchayats, total_admins: users }
    }
}
