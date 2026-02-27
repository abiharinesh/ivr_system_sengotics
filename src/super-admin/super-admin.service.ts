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

    /**
     * Resolve a manual_review complaint by assigning it to a pole.
     * Auto-learns: saves the caller's landmark phrase to the pole's landmarks array
     * so future callers using similar language will match instantly.
     */
    async resolveComplaint(complaintId: number, poleId: number) {
        // 1. Validate complaint exists
        const complaint = await this.prisma.complaint.findUnique({
            where: { id: complaintId },
            include: { voice_call: true }
        })
        if (!complaint) throw new NotFoundException(`Complaint #${complaintId} not found`)

        // 2. Validate pole exists
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)

        // 3. Assign pole and update status
        const updated = await this.prisma.complaint.update({
            where: { id: complaintId },
            data: {
                pole_id: poleId,
                panchayat_id: pole.panchayat_id,
                status: 'pending'
            },
            include: { pole: true, panchayat: true }
        })

        // 4. Auto-learn: extract landmark from voice call and save to pole
        await this.learnLandmark(complaint, pole)

        this.logger.log(`✅ Complaint #${complaintId} resolved → pole #${poleId}`)
        return updated
    }

    /**
     * Extracts the landmark from a voice complaint and adds it to the pole's
     * landmarks array (if it's not already there). This is how the system
     * learns new ways people describe a location.
     */
    private async learnLandmark(
        complaint: { voice_call_id: number | null; voice_call: { ai_extracted_json: any } | null },
        pole: { id: number; landmarks: string[] }
    ): Promise<void> {
        if (!complaint.voice_call?.ai_extracted_json) return

        const extracted = complaint.voice_call.ai_extracted_json as Record<string, any>
        const newLandmarks: string[] = []

        // Collect both English and original landmark phrases
        if (extracted.landmark_english && typeof extracted.landmark_english === 'string') {
            newLandmarks.push(extracted.landmark_english.trim())
        }
        if (extracted.landmark && typeof extracted.landmark === 'string') {
            newLandmarks.push(extracted.landmark.trim())
        }

        if (newLandmarks.length === 0) return

        // Filter out landmarks that already exist (case-insensitive)
        const existingLower = pole.landmarks.map(l => l.toLowerCase())
        const uniqueNew = newLandmarks.filter(
            l => l.length > 0 && !existingLower.includes(l.toLowerCase())
        )

        if (uniqueNew.length === 0) {
            this.logger.log(`[Learn] No new landmarks to add for pole #${pole.id}`)
            return
        }

        // Append new landmarks to pole
        await this.prisma.electricPole.update({
            where: { id: pole.id },
            data: { landmarks: [...pole.landmarks, ...uniqueNew] }
        })

        this.logger.log(
            `[Learn] ✅ Added ${uniqueNew.length} new landmark(s) to pole #${pole.id}: ${uniqueNew.join(', ')}`
        )
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
