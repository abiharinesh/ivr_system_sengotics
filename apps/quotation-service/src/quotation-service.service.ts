import { Injectable, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common'
import { PrismaService } from '@app/shared'
import { LocalFilesService } from '@app/shared'
import type { UploadedImageFile } from '@app/shared'
import { createHash } from 'crypto'
import { ScoringService, type ScoreWeights } from './scoring.service'

@Injectable()
export class QuotationServiceService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly files: LocalFilesService,
        private readonly scoring: ScoringService,
    ) {}

    async submitQuotationByToken(token: string, input: {
        vendor_user_id?: number
        company_name: string
        contact_person: string
        mobile_number: string
        quantity: number
        price_per_light: number
        installation_cost?: number
        delivery_days: number
        warranty_months: number
        seller_rating?: number
        experience_years?: number
        notes?: string
        document?: UploadedImageFile
    }) {
        const invite = await this.resolveInviteByToken(token, 'tender_submission')
        const tender = await this.prisma.tender.findUnique({
            where: { id: invite.tender_id },
            include: { quotations: true }
        })
        if (!tender) throw new NotFoundException('Tender not found.')
        if (tender.status !== 'open_for_quotations') {
            throw new BadRequestException('Tender is not open for quotations.')
        }

        const installCost = input.installation_cost ?? 0
        const quantity = Math.max(1, input.quantity)
        const totalCost = (input.price_per_light * quantity) + installCost

        const existing = tender.quotations
        const allTotalCosts = [...existing.map((q) => q.total_cost), totalCost]
        const allDelivery = [...existing.map((q) => q.delivery_days), input.delivery_days]
        const allWarranty = [...existing.map((q) => q.warranty_months), input.warranty_months]
        const allRating = [...existing.map((q) => q.seller_rating), input.seller_rating ?? 3]
        const allExperience = [...existing.map((q) => q.experience_years), input.experience_years ?? 1]

        const scoreResult = this.scoring.scoreQuotation(
            {
                pricePerLight: input.price_per_light,
                installationCost: installCost,
                quantity,
                deliveryDays: input.delivery_days,
                warrantyMonths: input.warranty_months,
                sellerRating: input.seller_rating ?? 3,
                experienceYears: input.experience_years ?? 1,
            },
            {
                minTotalCost: Math.min(...allTotalCosts),
                maxTotalCost: Math.max(...allTotalCosts),
                minDeliveryDays: Math.min(...allDelivery),
                maxDeliveryDays: Math.max(...allDelivery),
                maxWarrantyMonths: Math.max(...allWarranty),
                maxSellerRating: Math.max(...allRating),
                maxExperienceYears: Math.max(...allExperience),
            },
            (tender.scoring_config as ScoreWeights | null) ?? this.scoring.getDefaultWeights(),
        )

        let documentUrl: string | null = null
        if (input.document?.buffer?.length) {
            documentUrl = await this.files.saveBuffer('tenders/quotations/docs', input.document.buffer, input.document.originalname)
        }

        const quotation = await this.prisma.$transaction(async (tx) => {
            const created = await tx.quotation.create({
                data: {
                    tender_id: tender.id,
                    vendor_user_id: input.vendor_user_id ?? invite.vendor_user_id ?? null,
                    company_name: input.company_name.trim(),
                    contact_person: input.contact_person.trim(),
                    mobile_number: input.mobile_number.trim(),
                    quantity,
                    price_per_light: input.price_per_light,
                    installation_cost: installCost,
                    total_cost: totalCost,
                    delivery_days: input.delivery_days,
                    warranty_months: input.warranty_months,
                    seller_rating: input.seller_rating ?? 3,
                    experience_years: input.experience_years ?? 1,
                    document_url: documentUrl,
                    notes: input.notes?.trim() || null,
                    score_breakdown: scoreResult.breakdown,
                    final_score: scoreResult.finalScore,
                    status: 'submitted',
                },
            })
            await tx.tenderInviteLink.update({
                where: { id: invite.id },
                data: { used_count: { increment: 1 } }
            })
            return created
        })

        return {
            message: 'Quotation submitted successfully.',
            quotation,
            rank_hint_score: scoreResult.finalScore,
        }
    }

    async getQuotationLeaderboard(panchayatId: number, tenderId: number) {
        await this.assertTenderScope(panchayatId, tenderId)
        const quotations = await this.prisma.quotation.findMany({
            where: { tender_id: tenderId },
            orderBy: [{ final_score: 'desc' }, { total_cost: 'asc' }, { created_at: 'asc' }],
        })
        return quotations.map((q, index) => ({
            rank: index + 1,
            quotation_id: q.id,
            company_name: q.company_name,
            total_cost: q.total_cost,
            final_score: q.final_score,
            breakdown: q.score_breakdown,
            status: q.status,
        }))
    }

    // ── Helpers ─────────────────────────────────────────
    private async assertTenderScope(panchayatId: number, tenderId: number) {
        const tender = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!tender) throw new NotFoundException('Tender not found.')
        if (tender.panchayat_id !== panchayatId) throw new ForbiddenException('Tender is outside your panchayat.')
        return tender
    }

    private async resolveInviteByToken(token: string, purpose: 'tender_submission' | 'work_upload') {
        const hash = this.hashToken(token)
        const invite = await this.prisma.tenderInviteLink.findUnique({ where: { token_hash: hash } })
        if (!invite || invite.purpose !== purpose) throw new ForbiddenException('Invalid link token.')
        if (invite.is_revoked) throw new ForbiddenException('This link has been revoked.')
        if (invite.expires_at < new Date()) throw new ForbiddenException('This link has expired.')
        if (invite.max_submissions != null && invite.used_count >= invite.max_submissions) throw new ForbiddenException('Submission limit reached.')
        return invite
    }

    private hashToken(token: string): string {
        return createHash('sha256').update(token).digest('hex')
    }
}
