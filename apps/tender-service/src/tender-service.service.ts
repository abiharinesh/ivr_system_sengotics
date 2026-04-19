import { Injectable, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common'
import { PrismaService } from '@app/shared'
import { createHash, randomBytes } from 'crypto'
import { Prisma } from '@prisma/client'

const OPEN_COMPLAINT_STATUSES = [
    'pending', 'assigned', 'in_progress',
    'resolved_pending_confirmation', 'reassign_required', 'manual_review',
]

@Injectable()
export class TenderServiceService {
    constructor(private readonly prisma: PrismaService) {}

    async createTender(panchayatId: number, userId: number, input: {
        complaint_ids: number[]; required_quantity?: number; light_type?: string;
        work_type: string; submission_deadline: string;
    }) {
        const complaintIds = [...new Set(input.complaint_ids ?? [])]
        if (complaintIds.length < 2 || complaintIds.length > 5) {
            throw new BadRequestException('Tender requires 2 to 5 complaints.')
        }

        const complaints = await this.prisma.complaint.findMany({
            where: { id: { in: complaintIds }, panchayat_id: panchayatId, status: { in: OPEN_COMPLAINT_STATUSES }, pole_id: { not: null } },
            select: { id: true, pole_id: true },
        })
        if (complaints.length !== complaintIds.length) {
            throw new BadRequestException('Some complaints are invalid, out of scope, already closed, or missing pole mapping.')
        }

        const uniquePoles = new Set(complaints.map((c) => c.pole_id))
        const requiredQty = input.required_quantity && input.required_quantity > 0 ? input.required_quantity : uniquePoles.size

        const deadline = new Date(input.submission_deadline)
        if (Number.isNaN(deadline.getTime()) || deadline <= new Date()) {
            throw new BadRequestException('submission_deadline must be a future datetime.')
        }

        const tenderCode = await this.generateTenderCode()
        const scoringConfig = { price: 40, warranty: 20, delivery: 15, rating: 15, experience: 10 }
        const link = this.generateTokenPayload()

        const tender = await this.prisma.$transaction(async (tx) => {
            const created = await tx.tender.create({
                data: {
                    tender_code: tenderCode, panchayat_id: panchayatId,
                    complaint_count: complaintIds.length, required_quantity: requiredQty,
                    light_type: input.light_type?.trim() || null,
                    work_type: input.work_type?.trim() || 'replace_light',
                    submission_deadline: deadline,
                    scoring_config: scoringConfig as unknown as Prisma.InputJsonValue,
                    status: 'open_for_quotations', created_by_user_id: userId,
                    complaint_links: { createMany: { data: complaintIds.map((id) => ({ complaint_id: id })) } },
                },
                include: { complaint_links: true },
            })
            await tx.tenderInviteLink.create({
                data: {
                    tender_id: created.id, purpose: 'tender_submission',
                    token_hash: link.hash, token_hint: link.hint,
                    expires_at: deadline, max_submissions: 50,
                },
            })
            return created
        })

        return {
            tender, scoring_config: scoringConfig,
            submission_link: `/api/procurement/public/tender-submit/${link.token}`,
        }
    }

    async listTenders(panchayatId: number) {
        return this.prisma.tender.findMany({
            where: { panchayat_id: panchayatId },
            include: { _count: { select: { quotations: true, complaint_links: true, work_orders: true } } },
            orderBy: { created_at: 'desc' },
        })
    }

    async listTenderLinks(panchayatId: number, tenderId: number) {
        await this.assertTenderScope(panchayatId, tenderId)
        return this.prisma.tenderInviteLink.findMany({
            where: { tender_id: tenderId },
            select: {
                id: true, purpose: true, token_hint: true, expires_at: true,
                max_submissions: true, used_count: true, is_revoked: true,
                vendor_user_id: true, work_order_id: true, created_at: true,
            },
            orderBy: { created_at: 'desc' },
        })
    }

    async revokeInviteLink(panchayatId: number, linkId: number) {
        const link = await this.prisma.tenderInviteLink.findUnique({
            where: { id: linkId }, include: { tender: { select: { panchayat_id: true } } },
        })
        if (!link) throw new NotFoundException('Invite link not found.')
        if (link.tender.panchayat_id !== panchayatId) throw new ForbiddenException('Outside your panchayat.')
        return this.prisma.tenderInviteLink.update({
            where: { id: linkId }, data: { is_revoked: true },
            select: { id: true, purpose: true, expires_at: true, max_submissions: true, used_count: true, is_revoked: true },
        })
    }

    async exportTenderLifecycle(panchayatId: number, tenderId: number) {
        const tender = await this.prisma.tender.findFirst({
            where: { id: tenderId, panchayat_id: panchayatId },
            include: {
                complaint_links: { include: { complaint: { select: { id: true, status: true, pole_id: true, complaint_type: true, created_at: true, resolved_at: true } } } },
                quotations: { orderBy: [{ final_score: 'desc' }, { total_cost: 'asc' }], select: { id: true, company_name: true, total_cost: true, final_score: true, status: true, created_at: true } },
                work_orders: { include: { items: true, proofs: { select: { id: true, complaint_id: true, pole_id: true, status: true, distance_meters: true, adaptive_radius_meters: true, match_confidence: true, uploaded_at: true } } } },
                invite_links: { select: { id: true, purpose: true, expires_at: true, used_count: true, is_revoked: true, created_at: true } },
            },
        })
        if (!tender) throw new NotFoundException('Tender not found.')
        const auditRows = await this.prisma.complaintResolutionAudit.findMany({
            where: { complaint_id: { in: tender.complaint_links.map((l) => l.complaint_id) } },
            orderBy: { created_at: 'asc' },
        })
        return { generated_at: new Date().toISOString(), tender, audit: auditRows }
    }

    // ── Helpers ─────────────────────────────────────────
    async assertTenderScope(panchayatId: number, tenderId: number) {
        const tender = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!tender) throw new NotFoundException('Tender not found.')
        if (tender.panchayat_id !== panchayatId) throw new ForbiddenException('Tender outside your panchayat.')
        return tender
    }

    resolveInviteByToken(token: string, purpose: 'tender_submission' | 'work_upload') {
        return this._resolveInvite(token, purpose)
    }

    private async _resolveInvite(token: string, purpose: string) {
        const hash = this.hashToken(token)
        const invite = await this.prisma.tenderInviteLink.findUnique({ where: { token_hash: hash } })
        if (!invite || invite.purpose !== purpose) throw new ForbiddenException('Invalid link token.')
        if (invite.is_revoked) throw new ForbiddenException('This link has been revoked.')
        if (invite.expires_at < new Date()) throw new ForbiddenException('This link has expired.')
        if (invite.max_submissions != null && invite.used_count >= invite.max_submissions) throw new ForbiddenException('Submission limit reached.')
        return invite
    }

    hashToken(token: string) { return createHash('sha256').update(token).digest('hex') }

    generateTokenPayload() {
        const token = randomBytes(24).toString('hex')
        return { token, hash: this.hashToken(token), hint: token.slice(0, 6) }
    }

    private async generateTenderCode() {
        const year = new Date().getUTCFullYear()
        const count = await this.prisma.tender.count()
        return `TSK-${year}-${String(count + 1).padStart(3, '0')}`
    }
}
