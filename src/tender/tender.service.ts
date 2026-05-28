import {
    BadRequestException,
    ForbiddenException,
    Injectable,
    NotFoundException,
} from '@nestjs/common'
import { randomBytes } from 'crypto'
import { PrismaService, PrismaTx } from '../prisma/prisma.service'
import { normalizePhoneE164 } from '../common/phone.util'
import { DEFAULT_MILESTONE_RULES, MilestoneRule } from '../common/milestone.util'
import {
    assertTransition,
    QuotationAccessMode,
    TENDER_STATUSES,
    TenderStatus,
    validateAccessMode,
} from './tender-status'
import { TenderAuditService } from './audit.service'
import { MilestoneService } from './milestone.service'

export interface TenderCreateBody {
    title_ta?: string
    title_en?: string
    narrative_ta?: string
    narrative_en?: string
    anchor_date?: string
    quotation_access_mode?: string
    milestone_rules?: MilestoneRule[]
    auto_resolve_linked_complaints?: boolean
    officer_self_inspection?: boolean
    invited_vendor_ids?: number[]
    line_items?: TenderLineItemBody[]
}

export interface TenderLineItemBody {
    seq?: number
    description_ta?: string
    description_en?: string
    quantity?: number | string
    unit?: string
    /** Raw pole number or database id from the client (preferred). */
    pole_ref?: string | number
    pole_id?: number
    complaint_id?: number
}

@Injectable()
export class TenderService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly audit: TenderAuditService,
        private readonly milestones: MilestoneService,
    ) {}

    // ── helpers ──────────────────────────────────────────────────────────
    private mintInviteToken() {
        return randomBytes(24).toString('hex')
    }

    /** Mint missing per-vendor invite tokens (does not clear revocation). */
    private async ensureInviteTokens(tx: PrismaTx, tenderId: number) {
        const invites = await tx.tenderVendorInvite.findMany({
            where: { tender_id: tenderId },
            select: { id: true, invite_token: true },
        })
        for (const invite of invites) {
            if (invite.invite_token) continue
            await tx.tenderVendorInvite.update({
                where: { id: invite.id },
                data: { invite_token: this.mintInviteToken() },
            })
        }
    }

    /** Backfill tokens for tenders published before invite links were added. */
    private async backfillInviteTokensIfNeeded(tenderId: number, status: string) {
        if (status === 'draft') return
        await this.prisma.$transaction(async (rawTx) => {
            await this.ensureInviteTokens(rawTx as PrismaTx, tenderId)
        })
    }

    private async resolvePoleId(
        db: PrismaTx,
        panchayatId: number,
        ref?: string | number | null,
    ): Promise<number | null> {
        if (ref == null) return null
        const refStr = String(ref).trim()
        if (!refStr) return null

        const byNumber = await db.electricPole.findFirst({
            where: { panchayat_id: panchayatId, pole_number: refStr },
        })
        if (byNumber) return byNumber.id

        const asInt = Number(refStr)
        if (Number.isInteger(asInt) && asInt > 0 && String(asInt) === refStr) {
            const byId = await db.electricPole.findFirst({
                where: { id: asInt, panchayat_id: panchayatId },
            })
            if (byId) return byId.id
        }

        throw new BadRequestException(
            `Pole "${refStr}" was not found in this panchayat. Use an existing pole number or database ID.`,
        )
    }

    private async resolveComplaintId(
        db: PrismaTx,
        panchayatId: number,
        complaintId?: number | null,
    ): Promise<number | null> {
        if (complaintId == null) return null
        const complaint = await db.complaint.findFirst({
            where: { id: complaintId, panchayat_id: panchayatId },
        })
        if (!complaint) {
            throw new BadRequestException(
                `Complaint #${complaintId} was not found in this panchayat.`,
            )
        }
        return complaint.id
    }

    private async resolveLineItemRefs(
        db: PrismaTx,
        panchayatId: number,
        body: TenderLineItemBody,
    ): Promise<{ pole_id: number | null; complaint_id: number | null }> {
        const poleRef = body.pole_ref ?? body.pole_id
        const pole_id = await this.resolvePoleId(db, panchayatId, poleRef)
        const complaint_id = await this.resolveComplaintId(db, panchayatId, body.complaint_id)
        return { pole_id, complaint_id }
    }

    private async loadOwned(panchayatId: number, tenderId: number) {
        const tender = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!tender) throw new NotFoundException(`Tender #${tenderId} not found`)
        if (tender.panchayat_id !== panchayatId) {
            throw new ForbiddenException('Tender belongs to another panchayat')
        }
        return tender
    }

    private async setStatus(tenderId: number, next: TenderStatus, actorUserId: number, payload?: Record<string, unknown>) {
        const t = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!t) throw new NotFoundException(`Tender #${tenderId} not found`)
        if (t.status !== next) {
            assertTransition(t.status, next)
        }
        const updated = await this.prisma.tender.update({
            where: { id: tenderId },
            data: { status: next },
        })
        await this.audit.record({
            tenderId,
            actorUserId,
            event: `status:${t.status}->${next}`,
            payload: payload ?? null,
        })
        return updated
    }

    // ── tender CRUD ──────────────────────────────────────────────────────

    async list(panchayatId?: number, opts: { status?: string } = {}) {
        const tenders = await this.prisma.tender.findMany({
            where: {
                ...(panchayatId ? { panchayat_id: panchayatId } : {}),
                ...(opts.status && TENDER_STATUSES.includes(opts.status as TenderStatus)
                    ? { status: opts.status }
                    : {}),
            },
            orderBy: { id: 'desc' },
            include: {
                _count: { select: { line_items: true, quotations: true, documents: true, invites: true } },
                awarded_quotation: { select: { id: true, vendor_id: true, submitter_name: true, amount: true } },
                panchayat: { select: { id: true, name: true } },
            },
        })

        const fvIds = tenders.filter((t) => t.status === 'field_verification').map((t) => t.id)
        const progressByTender = new Map<number, { done: number; total: number }>()
        if (fvIds.length > 0) {
            const rows = await this.prisma.tenderFieldChecklistItem.groupBy({
                by: ['tender_id'],
                where: { tender_id: { in: fvIds } },
                _count: { _all: true },
            })
            const doneRows = await this.prisma.tenderFieldChecklistItem.groupBy({
                by: ['tender_id'],
                where: { tender_id: { in: fvIds }, is_done: true },
                _count: { _all: true },
            })
            const doneMap = new Map(doneRows.map((r) => [r.tender_id, r._count._all]))
            for (const row of rows) {
                progressByTender.set(row.tender_id, {
                    total: row._count._all,
                    done: doneMap.get(row.tender_id) ?? 0,
                })
            }
        }

        return tenders.map((t) => ({
            ...t,
            verification_progress:
                t.status === 'field_verification' ? progressByTender.get(t.id) ?? { done: 0, total: 0 } : null,
        }))
    }

    async getDetail(panchayatId: number, tenderId: number) {
        const tender = await this.loadOwned(panchayatId, tenderId)
        await this.backfillInviteTokensIfNeeded(tenderId, tender.status)
        const [lineItems, quotations, invites, documents, sessions] = await Promise.all([
            this.prisma.tenderLineItem.findMany({
                where: { tender_id: tenderId },
                orderBy: { seq: 'asc' },
                include: { pole: true, complaint: true },
            }),
            this.prisma.tenderQuotation.findMany({
                where: { tender_id: tenderId },
                orderBy: { submitted_at: 'asc' },
                include: { vendor: true },
            }),
            this.prisma.tenderVendorInvite.findMany({
                where: { tender_id: tenderId },
                include: { vendor: true },
            }),
            this.prisma.tenderDocument.findMany({
                where: { tender_id: tenderId },
                orderBy: [{ template_id: 'asc' }, { version: 'desc' }],
            }),
            this.prisma.fieldVerificationSession.findMany({
                where: { tender_id: tenderId },
                orderBy: { id: 'desc' },
                include: { _count: { select: { uploads: true } } },
            }),
        ])
        const timeline = await this.milestones.resolveForTender(tenderId)
        return { tender, line_items: lineItems, quotations, invites, documents, verification_sessions: sessions, timeline }
    }

    async create(panchayatId: number, actorUserId: number, body: TenderCreateBody) {
        const accessMode: QuotationAccessMode = validateAccessMode(body.quotation_access_mode ?? 'invited_only')
        const anchor = body.anchor_date ? new Date(body.anchor_date) : null
        if (anchor && Number.isNaN(anchor.getTime())) {
            throw new BadRequestException('anchor_date must be a valid ISO 8601 date')
        }
        const rules = (body.milestone_rules && body.milestone_rules.length > 0)
            ? body.milestone_rules
            : DEFAULT_MILESTONE_RULES

        const result = await this.prisma.$transaction(async (rawTx) => {
            const tx = rawTx as PrismaTx
            const tender = await tx.tender.create({
                data: {
                    panchayat_id: panchayatId,
                    status: 'draft',
                    title_ta: body.title_ta?.trim() || null,
                    title_en: body.title_en?.trim() || null,
                    narrative_ta: body.narrative_ta?.trim() || null,
                    narrative_en: body.narrative_en?.trim() || null,
                    anchor_date: anchor,
                    milestone_rules: rules as any,
                    quotation_access_mode: accessMode,
                    auto_resolve_linked_complaints: !!body.auto_resolve_linked_complaints,
                    officer_self_inspection: !!body.officer_self_inspection,
                    created_by_user_id: actorUserId,
                },
            })

            if (body.line_items?.length) {
                let seq = 1
                for (const li of body.line_items) {
                    const refs = await this.resolveLineItemRefs(tx, panchayatId, li)
                    await tx.tenderLineItem.create({
                        data: {
                            tender_id: tender.id,
                            seq: li.seq ?? seq++,
                            description_ta: li.description_ta?.trim() || null,
                            description_en: li.description_en?.trim() || null,
                            quantity: li.quantity != null ? String(li.quantity) : null,
                            unit: li.unit?.trim() || null,
                            pole_id: refs.pole_id,
                            complaint_id: refs.complaint_id,
                        },
                    })
                }
            }

            if (body.invited_vendor_ids?.length) {
                for (const vid of body.invited_vendor_ids) {
                    const v = await tx.vendor.findUnique({ where: { id: vid } })
                    if (!v || v.panchayat_id !== panchayatId) {
                        throw new BadRequestException(`Vendor #${vid} not in panchayat`)
                    }
                    await tx.tenderVendorInvite.upsert({
                        where: { tender_id_vendor_id: { tender_id: tender.id, vendor_id: vid } },
                        create: {
                            tender_id: tender.id,
                            vendor_id: vid,
                            invite_token: this.mintInviteToken(),
                            invite_revoked_at: null,
                        },
                        update: {},
                    })
                }
            }
            await this.ensureInviteTokens(tx, tender.id)
            return tender
        })

        await this.audit.record({
            tenderId: result.id,
            actorUserId,
            event: 'created',
            payload: { line_items: body.line_items?.length ?? 0, invited: body.invited_vendor_ids?.length ?? 0 },
        })
        return result
    }

    async patch(panchayatId: number, tenderId: number, actorUserId: number, body: Partial<TenderCreateBody>) {
        const existing = await this.loadOwned(panchayatId, tenderId)
        if (existing.status !== 'draft' && existing.status !== 'published') {
            throw new BadRequestException('Tender can only be edited while draft or published')
        }
        const data: Record<string, unknown> = {}
        if (body.title_ta !== undefined) data.title_ta = body.title_ta?.trim() || null
        if (body.title_en !== undefined) data.title_en = body.title_en?.trim() || null
        if (body.narrative_ta !== undefined) data.narrative_ta = body.narrative_ta?.trim() || null
        if (body.narrative_en !== undefined) data.narrative_en = body.narrative_en?.trim() || null
        if (body.anchor_date !== undefined) {
            const d = body.anchor_date ? new Date(body.anchor_date) : null
            if (d && Number.isNaN(d.getTime())) throw new BadRequestException('anchor_date invalid')
            data.anchor_date = d
        }
        if (body.milestone_rules !== undefined) data.milestone_rules = body.milestone_rules as any
        if (body.quotation_access_mode !== undefined) data.quotation_access_mode = validateAccessMode(body.quotation_access_mode)
        if (body.auto_resolve_linked_complaints !== undefined) data.auto_resolve_linked_complaints = !!body.auto_resolve_linked_complaints
        if (body.officer_self_inspection !== undefined) data.officer_self_inspection = !!body.officer_self_inspection
        const updated = await this.prisma.tender.update({ where: { id: tenderId }, data })
        await this.audit.record({ tenderId, actorUserId, event: 'patched', payload: { keys: Object.keys(data) } })
        return updated
    }

    /** Change who may submit via the public tender link (any non-closed status). */
    async setQuotationAccessMode(
        panchayatId: number,
        tenderId: number,
        actorUserId: number,
        mode: string,
    ) {
        const existing = await this.loadOwned(panchayatId, tenderId)
        if (existing.status === 'closed') {
            throw new BadRequestException('Cannot change quotation access mode on a closed tender')
        }
        const validated = validateAccessMode(mode)
        if (validated === existing.quotation_access_mode) {
            return existing
        }
        const updated = await this.prisma.tender.update({
            where: { id: tenderId },
            data: { quotation_access_mode: validated },
        })
        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'quotation_access_mode:set',
            payload: { from: existing.quotation_access_mode, to: validated },
        })
        return updated
    }

    // ── line items ───────────────────────────────────────────────────────

    async addLineItem(panchayatId: number, tenderId: number, actorUserId: number, body: TenderLineItemBody) {
        const t = await this.loadOwned(panchayatId, tenderId)
        if (t.status === 'closed') throw new BadRequestException('Cannot edit a closed tender')
        const last = await this.prisma.tenderLineItem.findFirst({
            where: { tender_id: tenderId },
            orderBy: { seq: 'desc' },
        })
        const refs = await this.resolveLineItemRefs(this.prisma as unknown as PrismaTx, panchayatId, body)
        const created = await this.prisma.tenderLineItem.create({
            data: {
                tender_id: tenderId,
                seq: body.seq ?? (last?.seq ?? 0) + 1,
                description_ta: body.description_ta?.trim() || null,
                description_en: body.description_en?.trim() || null,
                quantity: body.quantity != null ? String(body.quantity) : null,
                unit: body.unit?.trim() || null,
                pole_id: refs.pole_id,
                complaint_id: refs.complaint_id,
            },
        })
        await this.audit.record({ tenderId, actorUserId, event: 'line_item:add', payload: { line_item_id: created.id } })
        return created
    }

    async updateLineItem(panchayatId: number, tenderId: number, lineItemId: number, actorUserId: number, body: TenderLineItemBody) {
        await this.loadOwned(panchayatId, tenderId)
        const li = await this.prisma.tenderLineItem.findUnique({ where: { id: lineItemId } })
        if (!li || li.tender_id !== tenderId) throw new NotFoundException(`Line item #${lineItemId} not on this tender`)
        const data: Record<string, unknown> = {}
        if (body.seq !== undefined) data.seq = body.seq
        if (body.description_ta !== undefined) data.description_ta = body.description_ta?.trim() || null
        if (body.description_en !== undefined) data.description_en = body.description_en?.trim() || null
        if (body.quantity !== undefined) data.quantity = body.quantity != null ? String(body.quantity) : null
        if (body.unit !== undefined) data.unit = body.unit?.trim() || null
        const db = this.prisma as unknown as PrismaTx
        if (body.pole_ref !== undefined || body.pole_id !== undefined) {
            data.pole_id = await this.resolvePoleId(db, panchayatId, body.pole_ref ?? body.pole_id)
        }
        if (body.complaint_id !== undefined) {
            data.complaint_id = await this.resolveComplaintId(db, panchayatId, body.complaint_id)
        }
        const updated = await this.prisma.tenderLineItem.update({ where: { id: lineItemId }, data })
        await this.audit.record({ tenderId, actorUserId, event: 'line_item:update', payload: { line_item_id: lineItemId } })
        return updated
    }

    async deleteLineItem(panchayatId: number, tenderId: number, lineItemId: number, actorUserId: number) {
        await this.loadOwned(panchayatId, tenderId)
        const li = await this.prisma.tenderLineItem.findUnique({ where: { id: lineItemId } })
        if (!li || li.tender_id !== tenderId) throw new NotFoundException(`Line item #${lineItemId} not on this tender`)
        await this.prisma.tenderLineItem.delete({ where: { id: lineItemId } })
        await this.audit.record({ tenderId, actorUserId, event: 'line_item:delete', payload: { line_item_id: lineItemId } })
        return { ok: true }
    }

    // ── invites ──────────────────────────────────────────────────────────

    async setInvites(panchayatId: number, tenderId: number, actorUserId: number, vendorIds: number[]) {
        const t = await this.loadOwned(panchayatId, tenderId)
        if (t.status === 'closed') throw new BadRequestException('Cannot edit a closed tender')
        const ids = Array.from(new Set(vendorIds.filter((n) => Number.isInteger(n) && n > 0)))
        const vendors = await this.prisma.vendor.findMany({ where: { id: { in: ids } } })
        for (const v of vendors) {
            if (v.panchayat_id !== panchayatId) {
                throw new BadRequestException(`Vendor #${v.id} not in this panchayat`)
            }
        }
        await this.prisma.$transaction([
            this.prisma.tenderVendorInvite.deleteMany({ where: { tender_id: tenderId } }),
            ...ids.map((vid) =>
                this.prisma.tenderVendorInvite.create({
                    data: {
                        tender_id: tenderId,
                        vendor_id: vid,
                        invite_token: this.mintInviteToken(),
                        invite_revoked_at: null,
                        invite_opened_at: null,
                        invite_submitted_at: null,
                    },
                }),
            ),
        ])
        if (t.status !== 'draft') {
            await this.backfillInviteTokensIfNeeded(tenderId, t.status)
        }
        await this.audit.record({ tenderId, actorUserId, event: 'invites:set', payload: { vendor_ids: ids } })
        return this.prisma.tenderVendorInvite.findMany({
            where: { tender_id: tenderId },
            include: { vendor: true },
        })
    }

    // ── publish / status ─────────────────────────────────────────────────

    async publish(panchayatId: number, tenderId: number, actorUserId: number) {
        const t = await this.loadOwned(panchayatId, tenderId)
        if (t.status !== 'draft') {
            throw new BadRequestException(`Cannot publish from status ${t.status}`)
        }
        const lineItemCount = await this.prisma.tenderLineItem.count({ where: { tender_id: tenderId } })
        if (lineItemCount === 0) throw new BadRequestException('Tender needs at least one line item before publishing')
        if (t.quotation_access_mode === 'invited_only') {
            const inviteCount = await this.prisma.tenderVendorInvite.count({ where: { tender_id: tenderId } })
            if (inviteCount === 0) {
                throw new BadRequestException('Invited-only tenders need at least one vendor invite')
            }
        }
        const token = randomBytes(24).toString('hex')
        const updated = await this.prisma.$transaction(async (rawTx) => {
            const tx = rawTx as PrismaTx
            const out = await tx.tender.update({
                where: { id: tenderId },
                data: {
                    status: 'published',
                    public_token: token,
                    anchor_date: t.anchor_date ?? new Date(),
                },
            })
            await this.ensureInviteTokens(tx, tenderId)
            await tx.tenderVendorInvite.updateMany({
                where: { tender_id: tenderId, invite_revoked_at: { not: null } },
                data: { invite_revoked_at: null },
            })
            return out
        })
        await this.audit.record({ tenderId, actorUserId, event: 'published', payload: { token_set: true } })
        return updated
    }

    async closeQuotations(panchayatId: number, tenderId: number, actorUserId: number) {
        await this.loadOwned(panchayatId, tenderId)
        await this.setStatus(tenderId, 'quotations_closed', actorUserId)
        await this.prisma.tenderVendorInvite.updateMany({
            where: { tender_id: tenderId, invite_revoked_at: null },
            data: { invite_revoked_at: new Date() },
        })
        return this.prisma.tender.findUniqueOrThrow({ where: { id: tenderId } })
    }

    async award(panchayatId: number, tenderId: number, actorUserId: number, quotationId: number) {
        const t = await this.loadOwned(panchayatId, tenderId)
        if (t.status !== 'quotations_closed' && t.status !== 'vendor_selected') {
            throw new BadRequestException('Tender must be in quotations_closed (or vendor_selected to re-award) to award')
        }
        const q = await this.prisma.tenderQuotation.findUnique({ where: { id: quotationId } })
        if (!q || q.tender_id !== tenderId) throw new BadRequestException(`Quotation #${quotationId} not on this tender`)
        if (q.superseded_by_id != null) throw new BadRequestException('Cannot award a superseded quotation')
        const updated = await this.prisma.tender.update({
            where: { id: tenderId },
            data: {
                awarded_quotation_id: quotationId,
                status: 'vendor_selected',
                work_order_date: t.work_order_date ?? new Date(),
            },
        })
        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'awarded',
            payload: { quotation_id: quotationId, amount: String(q.amount), vendor_id: q.vendor_id },
        })
        return updated
    }

    async recordWorkCompletion(
        panchayatId: number,
        tenderId: number,
        actorUserId: number,
        body: { work_completed_at?: string; inspection_notes?: string }
    ) {
        const t = await this.loadOwned(panchayatId, tenderId)
        if (!['vendor_selected', 'field_verification'].includes(t.status)) {
            throw new BadRequestException('Tender must be vendor_selected or in field_verification to record completion')
        }
        const completedAt = body.work_completed_at ? new Date(body.work_completed_at) : new Date()
        if (Number.isNaN(completedAt.getTime())) throw new BadRequestException('work_completed_at invalid')
        const updated = await this.prisma.tender.update({
            where: { id: tenderId },
            data: {
                work_completed_at: completedAt,
                inspection_notes: body.inspection_notes?.trim() || t.inspection_notes,
                status: t.status === 'vendor_selected' ? 'field_verification' : t.status,
            },
        })
        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'work_completion',
            payload: { work_completed_at: completedAt.toISOString() },
        })
        return updated
    }

    async recordPayment(
        panchayatId: number,
        tenderId: number,
        actorUserId: number,
        body: { payment_meta: Record<string, unknown>; close?: boolean }
    ) {
        const t = await this.loadOwned(panchayatId, tenderId)
        if (!['field_verification', 'vendor_selected', 'closed'].includes(t.status)) {
            throw new BadRequestException('Tender must be at or after vendor_selected to record payment')
        }
        if (!body.payment_meta || typeof body.payment_meta !== 'object') {
            throw new BadRequestException('payment_meta required')
        }

        const meta = { ...(t.payment_meta as Record<string, unknown> | null ?? {}), ...body.payment_meta }

        // Auto-fill voucher_serial when missing.
        if (!meta.voucher_serial) {
            meta.voucher_serial = await this.nextVoucherSerial(panchayatId)
        }

        const data: Record<string, unknown> = { payment_meta: meta }
        if (body.close && t.status !== 'closed') {
            data.status = 'closed'
            data.public_token = null
        }
        const updated = await this.prisma.tender.update({ where: { id: tenderId }, data })
        if (body.close) {
            await this.prisma.tenderVendorInvite.updateMany({
                where: { tender_id: tenderId, invite_revoked_at: null },
                data: { invite_revoked_at: new Date() },
            })
        }
        await this.audit.record({
            tenderId,
            actorUserId,
            event: body.close ? 'payment:close' : 'payment:update',
            payload: { voucher_serial: meta.voucher_serial },
        })
        return updated
    }

    /** Fiscal-year-aware voucher serial: `<count_in_panchayat_in_fy>/<fyShort>-<fyShortNext>`. */
    private async nextVoucherSerial(panchayatId: number): Promise<string> {
        const now = new Date()
        // Indian FY starts April 1.
        const month = now.getUTCMonth() + 1
        const yearStart = month >= 4 ? now.getUTCFullYear() : now.getUTCFullYear() - 1
        const fyStart = new Date(Date.UTC(yearStart, 3, 1))
        const fyEnd = new Date(Date.UTC(yearStart + 1, 3, 1))
        const used = await this.prisma.tender.count({
            where: {
                panchayat_id: panchayatId,
                payment_meta: { not: null as any },
                updated_at: { gte: fyStart, lt: fyEnd },
            },
        })
        const counter = used + 1
        const short = String(yearStart).slice(-2)
        const next = String(yearStart + 1).slice(-2)
        return `${counter}/${short}-${next}`
    }

    // ── officer offline quotation entry ──────────────────────────────────

    async addOfficerQuotation(
        panchayatId: number,
        tenderId: number,
        actorUserId: number,
        body: { vendor_id?: number; submitter_name?: string; phone?: string; amount: number | string; remarks?: string; screening_outcome?: string }
    ) {
        const t = await this.loadOwned(panchayatId, tenderId)
        if (t.status === 'closed') throw new BadRequestException('Cannot add quotations to a closed tender')

        let vendorId: number | null = null
        let name = body.submitter_name?.trim() || ''
        let phone = body.phone ? normalizePhoneE164(body.phone) : ''
        if (body.vendor_id) {
            const v = await this.prisma.vendor.findUnique({ where: { id: body.vendor_id } })
            if (!v || v.panchayat_id !== panchayatId) throw new BadRequestException(`Vendor #${body.vendor_id} not in panchayat`)
            vendorId = v.id
            if (!name) name = v.name
            if (!phone) phone = v.phone_e164
        }
        if (!name) throw new BadRequestException('submitter_name or vendor_id required')
        if (!phone) throw new BadRequestException('phone or vendor_id required')

        const amountStr = String(body.amount).trim()
        if (!amountStr || Number.isNaN(Number(amountStr)) || Number(amountStr) < 0) {
            throw new BadRequestException('amount must be a non-negative number')
        }

        // Latest-wins on duplicate phone within tender (officer entries also obey rule).
        const prior = await this.prisma.tenderQuotation.findFirst({
            where: {
                tender_id: tenderId,
                submitter_phone_e164: phone,
                superseded_by_id: null,
            },
            orderBy: { submitted_at: 'desc' },
        })

        const created = await this.prisma.tenderQuotation.create({
            data: {
                tender_id: tenderId,
                vendor_id: vendorId,
                submitter_name: name,
                submitter_phone_e164: phone,
                amount: amountStr,
                remarks: body.remarks?.trim() || null,
                source: 'officer_entry',
                screening_outcome: body.screening_outcome?.trim() || 'pending',
            },
        })
        if (prior) {
            await this.prisma.tenderQuotation.update({
                where: { id: prior.id },
                data: { superseded_by_id: created.id },
            })
        }
        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'quotation:officer_entry',
            payload: { quotation_id: created.id, vendor_id: vendorId, amount: amountStr, prior_id: prior?.id ?? null },
        })
        return created
    }
}
