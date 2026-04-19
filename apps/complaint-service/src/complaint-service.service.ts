import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common'
import { PrismaService, validateComplaintStatus } from '@app/shared'

const OPEN_COMPLAINT_STATUSES = [
    'pending', 'assigned', 'in_progress',
    'resolved_pending_confirmation', 'reassign_required', 'manual_review',
]

@Injectable()
export class ComplaintServiceService {
    constructor(private readonly prisma: PrismaService) {}

    async listComplaints(panchayatId: number | null, status?: string) {
        return this.prisma.complaint.findMany({
            where: {
                ...(panchayatId ? { panchayat_id: panchayatId } : {}),
                ...(status ? { status } : {}),
            },
            include: {
                pole: true,
                panchayat: { select: { id: true, name: true } },
                voice_call: { select: { id: true, transcript: true, transcript_english: true } },
            },
            orderBy: { created_at: 'desc' },
        })
    }

    async createComplaint(input: {
        pole_id: number
        panchayat_id?: number
        complaint_type?: string
        description?: string
        urgency_level?: string
        caller_language?: string
        caller_emotion?: string
    }) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: input.pole_id } })
        if (!pole) throw new NotFoundException('Pole not found')

        return this.prisma.complaint.create({
            data: {
                pole_id: input.pole_id,
                panchayat_id: input.panchayat_id ?? pole.panchayat_id,
                complaint_type: input.complaint_type ?? 'street_light_defect',
                description: input.description,
                urgency_level: input.urgency_level,
                caller_language: input.caller_language,
                caller_emotion: input.caller_emotion,
                status: 'pending',
            },
            include: { pole: true, panchayat: { select: { id: true, name: true } } },
        })
    }

    async updateStatus(complaintId: number, status: string) {
        validateComplaintStatus(status)
        return this.prisma.complaint.update({
            where: { id: complaintId },
            data: { status, ...(status === 'resolved' ? { resolved_at: new Date() } : {}) },
            include: { pole: true },
        })
    }

    async resolveComplaint(complaintId: number, poleId: number) {
        return this.prisma.complaint.update({
            where: { id: complaintId },
            data: { pole_id: poleId, status: 'resolved', resolved_at: new Date() },
            include: { pole: true },
        })
    }

    async assignElectrician(complaintId: number, electricianUserId: number) {
        return this.prisma.complaint.update({
            where: { id: complaintId },
            data: {
                assigned_electrician_id: electricianUserId,
                assigned_at: new Date(),
                status: 'assigned',
            },
            include: { pole: true },
        })
    }

    async getComplaintClustersForTender(panchayatId?: number) {
        const complaints = await this.prisma.complaint.findMany({
            where: {
                ...(panchayatId ? { panchayat_id: panchayatId } : {}),
                status: { in: OPEN_COMPLAINT_STATUSES },
                pole_id: { not: null },
                panchayat_id: { not: null },
            },
            select: {
                id: true, pole_id: true, complaint_type: true,
                status: true, created_at: true, panchayat_id: true,
                panchayat: { select: { id: true, name: true } },
            },
            orderBy: { created_at: 'asc' },
        })

        const clusters: Record<number, {
            panchayatId: number; panchayatName: string;
            complaintIds: number[]; uniquePoleIds: Set<number>;
        }> = {}

        for (const c of complaints) {
            if (!c.panchayat_id) continue
            if (!clusters[c.panchayat_id]) {
                clusters[c.panchayat_id] = {
                    panchayatId: c.panchayat_id,
                    panchayatName: c.panchayat?.name ?? '',
                    complaintIds: [], uniquePoleIds: new Set(),
                }
            }
            clusters[c.panchayat_id].complaintIds.push(c.id)
            if (c.pole_id) clusters[c.panchayat_id].uniquePoleIds.add(c.pole_id)
        }

        return Object.values(clusters).map((cl) => ({
            panchayatId: cl.panchayatId,
            panchayatName: cl.panchayatName,
            complaintCount: cl.complaintIds.length,
            complaintIds: cl.complaintIds,
            requiredQuantity: cl.uniquePoleIds.size,
            eligibleForTender: cl.complaintIds.length >= 2,
        }))
    }
}
