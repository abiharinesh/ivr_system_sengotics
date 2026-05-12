import {
    BadRequestException,
    Injectable,
    NotFoundException,
} from '@nestjs/common'
import { createHash } from 'crypto'
import { PrismaService } from '../prisma/prisma.service'
import { LocalFilesService } from '../storage/local-files.service'
import { normalizePhoneE164 } from '../common/phone.util'
import { MilestoneService } from './milestone.service'
import { TenderAuditService } from './audit.service'
import { VendorService } from './vendor.service'
import type { UploadedImageFile } from '../common/upload.types'

@Injectable()
export class TenderPublicService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly storage: LocalFilesService,
        private readonly milestones: MilestoneService,
        private readonly audit: TenderAuditService,
        private readonly vendors: VendorService,
    ) {}

    private async loadByToken(token: string) {
        if (!token) throw new NotFoundException('Tender not found')
        const tender = await this.prisma.tender.findUnique({
            where: { public_token: token },
            include: { panchayat: { select: { id: true, name: true } } },
        })
        if (!tender) throw new NotFoundException('Tender not found')
        return tender
    }

    async readPublic(token: string) {
        const t = await this.loadByToken(token)
        const [lineItems, invites, timeline, mineCount] = await Promise.all([
            this.prisma.tenderLineItem.findMany({
                where: { tender_id: t.id },
                orderBy: { seq: 'asc' },
                select: {
                    id: true, seq: true, description_ta: true, description_en: true,
                    quantity: true, unit: true,
                },
            }),
            this.prisma.tenderVendorInvite.findMany({
                where: { tender_id: t.id },
                select: { vendor: { select: { name: true, place: true } } },
            }),
            this.milestones.resolveForTender(t.id),
            this.prisma.tenderQuotation.count({ where: { tender_id: t.id, superseded_by_id: null } }),
        ])
        return {
            tender: {
                id: t.id,
                title_ta: t.title_ta,
                title_en: t.title_en,
                narrative_ta: t.narrative_ta,
                narrative_en: t.narrative_en,
                status: t.status,
                anchor_date: t.anchor_date,
                quotation_access_mode: t.quotation_access_mode,
            },
            panchayat: t.panchayat,
            line_items: lineItems.map((li) => ({ ...li, quantity: li.quantity != null ? String(li.quantity) : null })),
            timeline: timeline.dates,
            invited_vendors_summary: invites.map((i) => ({
                name: i.vendor.name,
                place: i.vendor.place,
            })),
            quotations_count: mineCount,
        }
    }

    /** Public POST quotation (open or invited mode). */
    async submitQuotation(args: {
        token: string
        body: { phone?: string; name?: string; amount?: number | string; remarks?: string }
        ipAddress: string
        attachment?: UploadedImageFile | null
    }) {
        const t = await this.loadByToken(args.token)
        if (t.status !== 'published') {
            throw new BadRequestException(`Tender is not accepting quotations (status=${t.status})`)
        }

        const phone = normalizePhoneE164(args.body.phone)
        const name = (args.body.name ?? '').trim()
        if (!name) throw new BadRequestException('name is required')
        const amountStr = String(args.body.amount ?? '').trim()
        if (!amountStr || Number.isNaN(Number(amountStr)) || Number(amountStr) < 0) {
            throw new BadRequestException('amount must be a non-negative number')
        }

        let vendorId: number | null = null
        if (t.quotation_access_mode === 'invited_only') {
            const invited = await this.prisma.tenderVendorInvite.findFirst({
                where: { tender_id: t.id, vendor: { phone_e164: phone } },
                include: { vendor: true },
            })
            if (!invited) throw new BadRequestException('This tender is invite-only and your phone is not on the list')
            vendorId = invited.vendor_id
        } else {
            // open_with_phone: upsert a vendor stub.
            const stub = await this.vendors.upsertStubByPhone({
                panchayatId: t.panchayat_id,
                phoneE164: phone,
                name,
                place: null,
            })
            vendorId = stub.id
        }

        // Latest-wins on duplicate phone within tender.
        const prior = await this.prisma.tenderQuotation.findFirst({
            where: { tender_id: t.id, submitter_phone_e164: phone, superseded_by_id: null },
            orderBy: { submitted_at: 'desc' },
        })

        let attachmentUrl: string | null = null
        if (args.attachment) {
            attachmentUrl = await this.storage.saveBuffer(
                `tenders/${t.id}/attachments`,
                args.attachment.buffer,
                args.attachment.originalname,
            )
        }

        const ipHash = createHash('sha256').update(`${args.ipAddress ?? ''}|${t.id}`).digest('hex').slice(0, 24)

        const created = await this.prisma.tenderQuotation.create({
            data: {
                tender_id: t.id,
                vendor_id: vendorId,
                submitter_name: name,
                submitter_phone_e164: phone,
                amount: amountStr,
                remarks: args.body.remarks?.trim() || null,
                attachment_url: attachmentUrl,
                source: 'public_post',
                screening_outcome: 'pending',
                submitted_ip_hash: ipHash,
            },
        })

        if (prior) {
            await this.prisma.tenderQuotation.update({
                where: { id: prior.id },
                data: { superseded_by_id: created.id },
            })
        }

        await this.audit.record({
            tenderId: t.id,
            actorUserId: null,
            event: 'quotation:public_post',
            payload: {
                quotation_id: created.id,
                vendor_id: vendorId,
                superseded_prior_id: prior?.id ?? null,
                amount: amountStr,
            },
        })

        return {
            ok: true,
            quotation_id: created.id,
            superseded_prior_id: prior?.id ?? null,
        }
    }
}
