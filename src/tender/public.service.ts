import {
    BadRequestException,
    Injectable,
    NotFoundException,
} from '@nestjs/common'
import { createHash } from 'crypto'
import { PrismaService } from '../prisma/prisma.service'
import { DocumentStorageService } from '../storage/document-storage.service'
import { normalizePhoneE164, phoneHash } from '../common/phone.util'
import { MilestoneService } from './milestone.service'
import { TenderAuditService } from './audit.service'
import { VendorService } from './vendor.service'
import type { UploadedImageFile } from '../common/upload.types'

const OPEN_IP_WINDOW_MS = 10 * 60_000
const OPEN_IP_LIMIT = 6
const OPEN_PHONE_WINDOW_MS = 30 * 60_000
const OPEN_PHONE_LIMIT = 4

@Injectable()
export class TenderPublicService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly storage: DocumentStorageService,
        private readonly milestones: MilestoneService,
        private readonly audit: TenderAuditService,
        private readonly vendors: VendorService,
    ) {}

    private async loadByPublicToken(token: string) {
        if (!token?.trim()) throw new NotFoundException('Tender not found')
        const tender = await this.prisma.tender.findUnique({
            where: { public_token: token },
            include: { panchayat: { select: { id: true, name: true } } },
        })
        if (!tender) throw new NotFoundException('Tender not found')
        return tender
    }

    private async loadActiveInviteByToken(inviteToken: string) {
        if (!inviteToken?.trim()) throw new NotFoundException('Invite not found')
        const now = new Date()
        const invite = await this.prisma.tenderVendorInvite.findFirst({
            where: {
                invite_token: inviteToken,
                invite_revoked_at: null,
                OR: [
                    { invite_expires_at: null },
                    { invite_expires_at: { gt: now } },
                ],
            },
            include: {
                vendor: true,
                tender: { include: { panchayat: { select: { id: true, name: true } } } },
            },
        })
        if (!invite) throw new NotFoundException('Invite not found or expired')
        return invite
    }

    private async readSharedTenderPayload(tenderId: number) {
        const [lineItems, timeline, quotationCount] = await Promise.all([
            this.prisma.tenderLineItem.findMany({
                where: { tender_id: tenderId },
                orderBy: { seq: 'asc' },
                select: {
                    id: true, seq: true, description_ta: true, description_en: true,
                    quantity: true, unit: true,
                },
            }),
            this.milestones.resolveForTender(tenderId),
            this.prisma.tenderQuotation.count({ where: { tender_id: tenderId, superseded_by_id: null } }),
        ])
        return { lineItems, timeline, quotationCount }
    }

    private ensureDeadlineOpen(tenderId: number, timeline: Record<string, string | null>) {
        const rawDeadline = timeline.quotation_deadline
        if (!rawDeadline) return
        const d = new Date(rawDeadline)
        if (Number.isNaN(d.getTime())) return
        if (Date.now() > d.getTime()) {
            throw new BadRequestException(`Quotation deadline passed for tender #${tenderId}`)
        }
    }

    private ensureWritableStatus(status: string) {
        if (status !== 'published') {
            throw new BadRequestException(`Tender is not accepting quotations (status=${status})`)
        }
    }

    private async enforceOpenAbuseGuards(tenderId: number, ipAddress: string, normalizedPhone: string) {
        const ipHash = createHash('sha256').update(`${ipAddress ?? ''}|${tenderId}`).digest('hex').slice(0, 24)
        const sinceIp = new Date(Date.now() - OPEN_IP_WINDOW_MS)
        const sincePhone = new Date(Date.now() - OPEN_PHONE_WINDOW_MS)

        const [ipRecent, phoneRecent] = await Promise.all([
            this.prisma.tenderQuotation.count({
                where: {
                    tender_id: tenderId,
                    source: 'public_post',
                    submitted_ip_hash: ipHash,
                    submitted_at: { gte: sinceIp },
                },
            }),
            this.prisma.tenderQuotation.count({
                where: {
                    tender_id: tenderId,
                    source: 'public_post',
                    submitter_phone_e164: normalizedPhone,
                    submitted_at: { gte: sincePhone },
                },
            }),
        ])

        if (ipRecent >= OPEN_IP_LIMIT) {
            throw new BadRequestException('Too many submissions from this network. Please retry later.')
        }
        if (phoneRecent >= OPEN_PHONE_LIMIT) {
            const bucket = phoneHash(normalizedPhone)
            throw new BadRequestException(`Too many submissions from this phone (${bucket}). Please retry later.`)
        }
    }

    private async createPublicQuotation(args: {
        tenderId: number
        vendorId: number | null
        phone: string
        name: string
        amount: string
        remarks?: string
        ipAddress: string
        attachment?: UploadedImageFile | null
        folderName: string
        auditEvent: string
    }) {
        // Latest-wins on duplicate phone within tender.
        const prior = await this.prisma.tenderQuotation.findFirst({
            where: { tender_id: args.tenderId, submitter_phone_e164: args.phone, superseded_by_id: null },
            orderBy: { submitted_at: 'desc' },
        })

        let attachmentUrl: string | null = null
        if (args.attachment) {
            attachmentUrl = await this.storage.saveImageBuffer(
                `${args.tenderId}/${args.folderName}`,
                args.attachment.buffer,
                args.attachment.originalname,
            )
        }

        const ipHash = createHash('sha256')
            .update(`${args.ipAddress ?? ''}|${args.tenderId}`)
            .digest('hex')
            .slice(0, 24)

        const created = await this.prisma.tenderQuotation.create({
            data: {
                tender_id: args.tenderId,
                vendor_id: args.vendorId,
                submitter_name: args.name,
                submitter_phone_e164: args.phone,
                amount: args.amount,
                remarks: args.remarks?.trim() || null,
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
            tenderId: args.tenderId,
            actorUserId: null,
            event: args.auditEvent,
            payload: {
                quotation_id: created.id,
                vendor_id: args.vendorId,
                superseded_prior_id: prior?.id ?? null,
                amount: args.amount,
            },
        })

        return {
            ok: true,
            quotation_id: created.id,
            superseded_prior_id: prior?.id ?? null,
        }
    }

    async readOpen(publicToken: string) {
        const t = await this.loadByPublicToken(publicToken)
        const shared = await this.readSharedTenderPayload(t.id)
        return {
            access_type: 'public_open',
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
            line_items: shared.lineItems.map((li) => ({ ...li, quantity: li.quantity != null ? String(li.quantity) : null })),
            timeline: shared.timeline.dates,
            quotations_count: shared.quotationCount,
        }
    }

    async readInvite(inviteToken: string) {
        const invite = await this.loadActiveInviteByToken(inviteToken)
        const shared = await this.readSharedTenderPayload(invite.tender_id)

        if (!invite.invite_opened_at) {
            await this.prisma.tenderVendorInvite.update({
                where: { id: invite.id },
                data: { invite_opened_at: new Date() },
            })
        }

        return {
            access_type: 'invite_only',
            invite: {
                id: invite.id,
                token: invite.invite_token,
                opened_at: invite.invite_opened_at,
                submitted_at: invite.invite_submitted_at,
                expires_at: invite.invite_expires_at,
                vendor: {
                    id: invite.vendor.id,
                    name: invite.vendor.name,
                    phone_e164: invite.vendor.phone_e164,
                    place: invite.vendor.place,
                },
            },
            tender: {
                id: invite.tender.id,
                title_ta: invite.tender.title_ta,
                title_en: invite.tender.title_en,
                narrative_ta: invite.tender.narrative_ta,
                narrative_en: invite.tender.narrative_en,
                status: invite.tender.status,
                anchor_date: invite.tender.anchor_date,
                quotation_access_mode: invite.tender.quotation_access_mode,
            },
            panchayat: invite.tender.panchayat,
            line_items: shared.lineItems.map((li) => ({ ...li, quantity: li.quantity != null ? String(li.quantity) : null })),
            timeline: shared.timeline.dates,
            quotations_count: shared.quotationCount,
        }
    }

    async submitOpenQuotation(args: {
        publicToken: string
        body: { phone?: string; name?: string; amount?: number | string; remarks?: string }
        ipAddress: string
        attachment?: UploadedImageFile | null
    }) {
        const t = await this.loadByPublicToken(args.publicToken)
        if (t.quotation_access_mode !== 'open_with_phone') {
            throw new BadRequestException('This link is for invited vendors only')
        }
        this.ensureWritableStatus(t.status)
        const timeline = await this.milestones.resolveForTender(t.id)
        this.ensureDeadlineOpen(t.id, timeline.dates as Record<string, string | null>)

        const phone = normalizePhoneE164(args.body.phone)
        const name = (args.body.name ?? '').trim()
        if (!name) throw new BadRequestException('name is required')
        const amountStr = String(args.body.amount ?? '').trim()
        if (!amountStr || Number.isNaN(Number(amountStr)) || Number(amountStr) < 0) {
            throw new BadRequestException('amount must be a non-negative number')
        }

        await this.enforceOpenAbuseGuards(t.id, args.ipAddress, phone)
        const stub = await this.vendors.upsertStubByPhone({
            panchayatId: t.panchayat_id,
            phoneE164: phone,
            name,
            place: null,
        })

        return this.createPublicQuotation({
            tenderId: t.id,
            vendorId: stub.id,
            phone,
            name,
            amount: amountStr,
            remarks: args.body.remarks,
            ipAddress: args.ipAddress,
            attachment: args.attachment,
            folderName: 'public_quotation',
            auditEvent: 'quotation:public_open_post',
        })
    }

    async submitInviteQuotation(args: {
        inviteToken: string
        body: { phone?: string; name?: string; amount?: number | string; remarks?: string }
        ipAddress: string
        attachment?: UploadedImageFile | null
    }) {
        const invite = await this.loadActiveInviteByToken(args.inviteToken)
        const t = invite.tender
        if (t.quotation_access_mode !== 'invited_only') {
            throw new BadRequestException('This invite is not valid for open tenders')
        }
        this.ensureWritableStatus(t.status)
        const timeline = await this.milestones.resolveForTender(t.id)
        this.ensureDeadlineOpen(t.id, timeline.dates as Record<string, string | null>)

        const providedPhone = args.body.phone?.trim()
        if (providedPhone) {
            const normalized = normalizePhoneE164(providedPhone)
            if (normalized !== invite.vendor.phone_e164) {
                throw new BadRequestException('This invite token is tied to a different phone number')
            }
        }

        const name = (args.body.name ?? '').trim() || invite.vendor.name
        if (!name) throw new BadRequestException('name is required')
        const amountStr = String(args.body.amount ?? '').trim()
        if (!amountStr || Number.isNaN(Number(amountStr)) || Number(amountStr) < 0) {
            throw new BadRequestException('amount must be a non-negative number')
        }

        const result = await this.createPublicQuotation({
            tenderId: t.id,
            vendorId: invite.vendor_id,
            phone: invite.vendor.phone_e164,
            name,
            amount: amountStr,
            remarks: args.body.remarks,
            ipAddress: args.ipAddress,
            attachment: args.attachment,
            folderName: 'vendors_quotation',
            auditEvent: 'quotation:invite_post',
        })
        await this.prisma.tenderVendorInvite.update({
            where: { id: invite.id },
            data: { invite_submitted_at: new Date() },
        })
        return result
    }

    // Backward compatibility for existing /public/tenders/:token routes.
    async readPublic(token: string) {
        const t = await this.loadByPublicToken(token)
        if (t.quotation_access_mode === 'open_with_phone') {
            return this.readOpen(token)
        }
        const shared = await this.readSharedTenderPayload(t.id)
        return {
            access_type: 'legacy_invited',
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
            line_items: shared.lineItems.map((li) => ({ ...li, quantity: li.quantity != null ? String(li.quantity) : null })),
            timeline: shared.timeline.dates,
            quotations_count: shared.quotationCount,
        }
    }

    async submitQuotation(args: {
        token: string
        body: { phone?: string; name?: string; amount?: number | string; remarks?: string }
        ipAddress: string
        attachment?: UploadedImageFile | null
    }) {
        const t = await this.loadByPublicToken(args.token)
        if (t.quotation_access_mode === 'open_with_phone') {
            return this.submitOpenQuotation({
                publicToken: args.token,
                body: args.body,
                ipAddress: args.ipAddress,
                attachment: args.attachment,
            })
        }
        this.ensureWritableStatus(t.status)
        const timeline = await this.milestones.resolveForTender(t.id)
        this.ensureDeadlineOpen(t.id, timeline.dates as Record<string, string | null>)
        const phone = normalizePhoneE164(args.body.phone)
        const invited = await this.prisma.tenderVendorInvite.findFirst({
            where: { tender_id: t.id, vendor: { phone_e164: phone } },
            include: { vendor: true },
        })
        if (!invited) {
            throw new BadRequestException('This tender is invite-only and your phone is not on the list')
        }
        const name = (args.body.name ?? '').trim() || invited.vendor.name
        if (!name) throw new BadRequestException('name is required')
        const amountStr = String(args.body.amount ?? '').trim()
        if (!amountStr || Number.isNaN(Number(amountStr)) || Number(amountStr) < 0) {
            throw new BadRequestException('amount must be a non-negative number')
        }
        return this.createPublicQuotation({
            tenderId: t.id,
            vendorId: invited.vendor_id,
            phone,
            name,
            amount: amountStr,
            remarks: args.body.remarks,
            ipAddress: args.ipAddress,
            attachment: args.attachment,
            folderName: 'vendors_quotation',
            auditEvent: 'quotation:legacy_invite_post',
        })
    }
}
