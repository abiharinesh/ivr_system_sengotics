import {
    BadRequestException,
    ForbiddenException,
    Injectable,
    Logger,
    NotFoundException,
} from '@nestjs/common'
import * as fs from 'fs/promises'
import * as fssync from 'fs'
import * as path from 'path'
import archiver from 'archiver'
import { PrismaService } from '../../prisma/prisma.service'
import { TenderAuditService } from '../audit.service'
import { MilestoneService } from '../milestone.service'
import { DocumentTemplateId, validateTemplateId } from '../tender-status'
import { renderTemplate, TemplateContext } from './templates'
import { renderHtmlToPdfBuffer } from './renderer'

@Injectable()
export class TenderPdfService {
    private readonly logger = new Logger(TenderPdfService.name)
    constructor(
        private readonly prisma: PrismaService,
        private readonly audit: TenderAuditService,
        private readonly milestones: MilestoneService,
    ) {}

    private async ensureTenderOwned(panchayatId: number, tenderId: number) {
        const t = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!t) throw new NotFoundException(`Tender #${tenderId} not found`)
        if (t.panchayat_id !== panchayatId) throw new ForbiddenException('Tender belongs to another panchayat')
        return t
    }

    /** Build the immutable rendering context for a given tender + template version. */
    private async buildContext(
        tenderId: number,
        templateId: DocumentTemplateId,
        version: number,
        vendorId: number | null,
        fieldOverrides: Record<string, unknown> | null,
    ): Promise<TemplateContext> {
        const tender = await this.prisma.tender.findUnique({
            where: { id: tenderId },
            include: { panchayat: true },
        })
        if (!tender || !tender.panchayat) throw new NotFoundException(`Tender #${tenderId} not found`)

        const [lineItems, invites, quotations] = await Promise.all([
            this.prisma.tenderLineItem.findMany({ where: { tender_id: tenderId }, orderBy: { seq: 'asc' } }),
            this.prisma.tenderVendorInvite.findMany({
                where: { tender_id: tenderId },
                include: { vendor: true },
            }),
            this.prisma.tenderQuotation.findMany({
                where: { tender_id: tenderId },
                orderBy: { submitted_at: 'asc' },
            }),
        ])
        const timeline = await this.milestones.resolveForTender(tenderId)

        return {
            panchayat: { id: tender.panchayat.id, name: tender.panchayat.name },
            tender: {
                id: tender.id,
                title_ta: tender.title_ta,
                title_en: tender.title_en,
                narrative_ta: tender.narrative_ta,
                narrative_en: tender.narrative_en,
                anchor_date: tender.anchor_date,
                work_order_date: tender.work_order_date,
                work_completed_at: tender.work_completed_at,
                public_token: tender.public_token,
                status: tender.status,
            },
            timeline: timeline.dates,
            line_items: lineItems.map((li) => ({
                id: li.id,
                seq: li.seq,
                description_ta: li.description_ta,
                description_en: li.description_en,
                quantity: li.quantity != null ? String(li.quantity) : null,
                unit: li.unit,
            })),
            invited_vendors: invites.map((inv) => ({
                id: inv.vendor.id,
                name: inv.vendor.name,
                phone_e164: inv.vendor.phone_e164,
                place: inv.vendor.place,
            })),
            quotations: quotations.map((q) => ({
                id: q.id,
                vendor_id: q.vendor_id,
                submitter_name: q.submitter_name,
                submitter_phone_e164: q.submitter_phone_e164,
                amount: String(q.amount),
                remarks: q.remarks,
                screening_outcome: q.screening_outcome,
                superseded_by_id: q.superseded_by_id,
            })),
            awarded_quotation_id: tender.awarded_quotation_id,
            payment_meta: (tender.payment_meta as Record<string, unknown> | null) ?? null,
            document: { template_id: templateId, version, vendor_id: vendorId, field_overrides: fieldOverrides },
            generated_at: new Date(),
        }
    }

    /** Generate (or regenerate) a document. Returns the new TenderDocument row. */
    async generate(args: {
        panchayatId: number
        tenderId: number
        templateId: string
        actorUserId: number
        vendorId?: number | null
        fieldOverrides?: Record<string, unknown> | null
    }) {
        const tpl = validateTemplateId(args.templateId)
        await this.ensureTenderOwned(args.panchayatId, args.tenderId)
        if (tpl === 'quotation' && args.vendorId == null) {
            throw new BadRequestException('vendor_id is required for quotation template')
        }

        const lastVersion = await this.prisma.tenderDocument.findFirst({
            where: {
                tender_id: args.tenderId,
                template_id: tpl,
                ...(tpl === 'quotation' ? { vendor_id: args.vendorId ?? null } : {}),
            },
            orderBy: { version: 'desc' },
            select: { version: true },
        })
        const version = (lastVersion?.version ?? 0) + 1

        const doc = await this.prisma.tenderDocument.create({
            data: {
                tender_id: args.tenderId,
                template_id: tpl,
                vendor_id: tpl === 'quotation' ? args.vendorId ?? null : null,
                version,
                field_overrides: (args.fieldOverrides ?? null) as any,
                generated_by_user_id: args.actorUserId,
                status: 'pending',
            },
        })

        // Fire-and-forget: same pattern as ExportJob.
        void this.process(doc.id).catch((e) =>
            this.logger.error(`PDF job ${doc.id} failed: ${e?.message ?? e}`),
        )
        await this.audit.record({
            tenderId: args.tenderId,
            actorUserId: args.actorUserId,
            event: 'document:generate',
            payload: { template_id: tpl, version, document_id: doc.id, vendor_id: doc.vendor_id },
        })
        return doc
    }

    private async process(docId: number): Promise<void> {
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: docId } })
        if (!doc) return

        try {
            const ctx = await this.buildContext(
                doc.tender_id,
                doc.template_id as DocumentTemplateId,
                doc.version,
                doc.vendor_id,
                (doc.field_overrides as Record<string, unknown> | null) ?? null,
            )
            const html = renderTemplate(doc.template_id, ctx)

            const subdir = path.posix.join('tenders', String(doc.tender_id), doc.template_id)
            const baseName = doc.vendor_id != null ? `v${doc.version}-vendor${doc.vendor_id}` : `v${doc.version}`
            const root = path.join(process.cwd(), 'uploads', subdir)
            await fs.mkdir(root, { recursive: true })

            // Always write the HTML artifact (browser-printable).
            const htmlAbs = path.join(root, `${baseName}.html`)
            await fs.writeFile(htmlAbs, html, 'utf8')
            const htmlRel = `/uploads/${subdir}/${baseName}.html`.replace(/\\/g, '/')

            // Best-effort PDF render via puppeteer if available.
            let storagePath = htmlRel
            const pdfBuf = await renderHtmlToPdfBuffer(html)
            if (pdfBuf) {
                const pdfAbs = path.join(root, `${baseName}.pdf`)
                await fs.writeFile(pdfAbs, pdfBuf)
                storagePath = `/uploads/${subdir}/${baseName}.pdf`.replace(/\\/g, '/')
            }

            await this.prisma.tenderDocument.update({
                where: { id: docId },
                data: {
                    status: 'ready',
                    storage_path: storagePath,
                    generated_at: new Date(),
                    error_message: pdfBuf ? null : 'puppeteer unavailable; HTML version produced',
                },
            })
        } catch (err: any) {
            await this.prisma.tenderDocument.update({
                where: { id: docId },
                data: {
                    status: 'failed',
                    error_message: String(err?.message ?? err).slice(0, 2000),
                },
            })
        }
    }

    list(panchayatId: number, tenderId: number) {
        return this.ensureTenderOwned(panchayatId, tenderId).then(() =>
            this.prisma.tenderDocument.findMany({
                where: { tender_id: tenderId },
                orderBy: [{ template_id: 'asc' }, { version: 'desc' }],
                include: { vendor: { select: { id: true, name: true, phone_e164: true } } },
            }),
        )
    }

    async getDownloadAbsolutePath(panchayatId: number, tenderId: number, docId: number): Promise<string> {
        await this.ensureTenderOwned(panchayatId, tenderId)
        return this.resolveDocAbsolutePath(tenderId, docId)
    }

    /**
     * Resolve the absolute path for a ready document without any panchayat
     * ownership check — used by the signed-URL public route where the token
     * itself proves authorization.
     */
    async resolveDocAbsolutePath(tenderId: number, docId: number): Promise<string> {
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: docId } })
        if (!doc || doc.tender_id !== tenderId) throw new NotFoundException('Document not on tender')
        if (doc.status !== 'ready' || !doc.storage_path) throw new BadRequestException('Document not ready')
        const rel = doc.storage_path.replace(/^\/+/, '')
        if (!rel.startsWith('uploads/tenders/')) throw new ForbiddenException('Invalid storage path')
        return path.join(process.cwd(), rel)
    }

    /** Stream a zip bundle of the latest version of every template. */
    async streamLatestZip(panchayatId: number, tenderId: number, out: NodeJS.WritableStream) {
        await this.ensureTenderOwned(panchayatId, tenderId)
        return this.streamLatestZipUnchecked(tenderId, out)
    }

    /** Same as [streamLatestZip] but without panchayat ownership check. */
    async streamLatestZipUnchecked(tenderId: number, out: NodeJS.WritableStream) {
        const docs = await this.prisma.tenderDocument.findMany({
            where: { tender_id: tenderId, status: 'ready' },
            orderBy: [{ template_id: 'asc' }, { version: 'desc' }],
        })
        const seen = new Set<string>()
        const archive = archiver('zip', { zlib: { level: 6 } })
        archive.pipe(out)

        for (const d of docs) {
            const key = `${d.template_id}:${d.vendor_id ?? 'null'}`
            if (seen.has(key)) continue
            seen.add(key)
            if (!d.storage_path) continue
            const rel = d.storage_path.replace(/^\/+/, '')
            const abs = path.join(process.cwd(), rel)
            if (!fssync.existsSync(abs)) continue
            const ext = path.extname(abs) || '.html'
            const name = d.vendor_id != null
                ? `${d.template_id}-vendor${d.vendor_id}-v${d.version}${ext}`
                : `${d.template_id}-v${d.version}${ext}`
            archive.file(abs, { name })
        }
        await archive.finalize()
    }
}
