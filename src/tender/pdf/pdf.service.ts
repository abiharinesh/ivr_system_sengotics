import {
    BadRequestException,
    ForbiddenException,
    Injectable,
    Logger,
    NotFoundException,
} from '@nestjs/common'
import * as path from 'path'
import archiver from 'archiver'
import { PrismaService } from '../../prisma/prisma.service'
import { DocumentStorageService } from '../../storage/document-storage.service'
import { TenderAuditService } from '../audit.service'
import { MilestoneService } from '../milestone.service'
import { DocumentTemplateId, validateTemplateId } from '../tender-status'
import { renderTemplate, TemplateContext } from './templates'
import { renderHtmlToPdfBuffer } from './renderer'
import { DocumentTemplateSettingsService } from './document-template-settings.service'

@Injectable()
export class TenderPdfService {
    private readonly logger = new Logger(TenderPdfService.name)
    /** Opt-in: comma-separated template ids (rfq, quotation, …). Empty = all templates editable. */
    private readonly canvasLockedTemplates = new Set<string>(
        (process.env.CANVAS_LOCKED_TEMPLATES ?? '')
            .split(',')
            .map((x) => x.trim())
            .filter((x) => x.length > 0)
    )
    constructor(
        private readonly prisma: PrismaService,
        private readonly documentStorage: DocumentStorageService,
        private readonly audit: TenderAuditService,
        private readonly milestones: MilestoneService,
        private readonly templateSettings: DocumentTemplateSettingsService,
    ) {}

    private buildStoragePath(subdir: string, filename: string): string {
        return path.posix.join('/uploads', subdir.replace(/\\/g, '/'), filename).replace(/\\/g, '/')
    }

    private async ensureTenderOwned(panchayatId: number, tenderId: number) {
        const t = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!t) throw new NotFoundException(`Tender #${tenderId} not found`)
        if (t.panchayat_id !== panchayatId) throw new ForbiddenException('Tender belongs to another panchayat')
        return t
    }

    /** When only one bidder exists, infer vendor for per-vendor quotation PDFs. */
    private async resolveQuotationVendorId(tenderId: number): Promise<number | null> {
        const activeQuotes = await this.prisma.tenderQuotation.findMany({
            where: { tender_id: tenderId, superseded_by_id: null },
            select: { vendor_id: true },
        })
        const fromQuotes = [
            ...new Set(
                activeQuotes
                    .map((q) => q.vendor_id)
                    .filter((id): id is number => id != null),
            ),
        ]
        if (fromQuotes.length === 1) return fromQuotes[0]

        const invites = await this.prisma.tenderVendorInvite.findMany({
            where: { tender_id: tenderId },
            select: { vendor_id: true },
        })
        const fromInvites = [...new Set(invites.map((i) => i.vendor_id))]
        if (fromInvites.length === 1) return fromInvites[0]

        return null
    }

    private normalizedCanvasLayers(input: unknown): Array<Record<string, unknown>> {
        if (!Array.isArray(input)) return []
        return input
            .filter((item) => item && typeof item === 'object')
            .map((item: any, idx) => ({
                id: String(item.id ?? `layer-${idx}`),
                text: String(item.text ?? ''),
                x: Number.isFinite(Number(item.x)) ? Number(item.x) : 0.5,
                y: Number.isFinite(Number(item.y)) ? Number(item.y) : 0.5,
                page: Number.isFinite(Number(item.page)) ? Math.max(1, Math.floor(Number(item.page))) : 1,
                fontSize: Number.isFinite(Number(item.fontSize)) ? Number(item.fontSize) : 16,
                color: item.color != null ? String(item.color) : '#111111',
            }))
    }

    private isCanvasLocked(templateId: string): boolean {
        return this.canvasLockedTemplates.has(templateId)
    }

    private withCanvasLayers(
        fieldOverrides: unknown,
        layers: Array<Record<string, unknown>>,
    ): Record<string, unknown> {
        const current = (
            fieldOverrides && typeof fieldOverrides === 'object' && !Array.isArray(fieldOverrides)
                ? { ...(fieldOverrides as Record<string, unknown>) }
                : {}
        )
        current.__canvas_layers = layers
        return current
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
        const layout = await this.templateSettings.resolveMergedLayout(
            tender.panchayat.id,
            templateId,
        )
        const mergedOverrides = await this.templateSettings.resolveMergedFieldOverrides(
            tender.panchayat.id,
            templateId,
            fieldOverrides,
        )

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
            document: {
                template_id: templateId,
                version,
                vendor_id: vendorId,
                field_overrides: mergedOverrides,
            },
            generated_at: new Date(),
            layout,
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
        let vendorId = args.vendorId ?? null
        if (tpl === 'quotation' && vendorId == null) {
            vendorId = await this.resolveQuotationVendorId(args.tenderId)
        }
        if (tpl === 'quotation' && vendorId == null) {
            throw new BadRequestException(
                'vendor_id is required for quotation template. Select a vendor or add an invite / quotation first.',
            )
        }

        const lastVersion = await this.prisma.tenderDocument.findFirst({
            where: {
                tender_id: args.tenderId,
                template_id: tpl,
                ...(tpl === 'quotation' ? { vendor_id: vendorId } : {}),
            },
            orderBy: { version: 'desc' },
            select: { version: true },
        })
        const version = (lastVersion?.version ?? 0) + 1

        const doc = await this.prisma.tenderDocument.create({
            data: {
                tender_id: args.tenderId,
                template_id: tpl,
                vendor_id: tpl === 'quotation' ? vendorId : null,
                version,
                field_overrides: (args.fieldOverrides ?? null) as any,
                generated_by_user_id: args.actorUserId,
                status: 'pending',
            },
        })

        // Run processing in-request on serverless so the invocation lifecycle
        // cannot drop the background promise and leave status stuck at "pending".
        await this.process(doc.id).catch((e) =>
            this.logger.error(`PDF job ${doc.id} failed: ${e?.message ?? e}`),
        )
        await this.audit.record({
            tenderId: args.tenderId,
            actorUserId: args.actorUserId,
            event: 'document:generate',
            payload: { template_id: tpl, version, document_id: doc.id, vendor_id: doc.vendor_id },
        })
        return this.prisma.tenderDocument.findUnique({ where: { id: doc.id } })
    }

    private async process(docId: number): Promise<void> {
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: docId } })
        if (!doc) return

        try {
            const storagePath = await this.renderAndPersistArtifacts(doc)
            await this.prisma.tenderDocument.update({
                where: { id: docId },
                data: {
                    status: 'ready',
                    storage_path: storagePath,
                    generated_at: new Date(),
                    error_message: null,
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

    private async renderAndPersistArtifacts(doc: {
        id: number
        tender_id: number
        template_id: string
        version: number
        vendor_id: number | null
        field_overrides: unknown
    }): Promise<string> {
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

        // Always persist the HTML artifact (serves as fallback if PDF fails).
        const htmlStoragePath = this.buildStoragePath(subdir, `${baseName}.html`)
        await this.documentStorage.writeUtf8(htmlStoragePath, html)

        // Attempt PDF generation — fall back to HTML if unavailable.
        const pdfBuf = await renderHtmlToPdfBuffer(html)
        if (!pdfBuf) {
            this.logger.warn(
                `PDF generation engine unavailable for doc ${doc.id}. Falling back to HTML. ` +
                `Configure GOTENBERG_URL or install a compatible local renderer for PDF output.`
            )
            return htmlStoragePath
        }
        const pdfStoragePath = this.buildStoragePath(subdir, `${baseName}.pdf`)
        await this.documentStorage.writeBuffer(pdfStoragePath, pdfBuf, 'application/pdf')
        return pdfStoragePath
    }

    private async ensureArtifactExists(doc: {
        id: number
        tender_id: number
        template_id: string
        version: number
        vendor_id: number | null
        field_overrides: unknown
        storage_path: string | null
    }): Promise<string> {
        if (!doc.storage_path) throw new BadRequestException('Document not ready')
        if (await this.documentStorage.exists(doc.storage_path)) return doc.storage_path

        // Check if an HTML fallback exists when the PDF is missing (common on
        // Vercel where /tmp is ephemeral and Supabase storage might not be set up).
        if (doc.storage_path.toLowerCase().endsWith('.pdf')) {
            const htmlFallback = doc.storage_path.replace(/\.pdf$/i, '.html')
            if (await this.documentStorage.exists(htmlFallback)) {
                this.logger.warn(`PDF missing for doc ${doc.id}, serving HTML fallback`)
                await this.prisma.tenderDocument.update({
                    where: { id: doc.id },
                    data: { storage_path: htmlFallback },
                })
                return htmlFallback
            }
        }

        // If the artifact is missing (e.g. manual cleanup or ephemeral /tmp),
        // regenerate deterministically on demand.
        this.logger.log(`Re-generating artifact for doc ${doc.id} (storage_path missing from disk/bucket)`)
        try {
            const storagePath = await this.renderAndPersistArtifacts(doc)
            await this.prisma.tenderDocument.update({
                where: { id: doc.id },
                data: {
                    status: 'ready',
                    storage_path: storagePath,
                    generated_at: new Date(),
                    error_message: null,
                },
            })
            return storagePath
        } catch (err: any) {
            this.logger.error(`Re-generation failed for doc ${doc.id}: ${err?.message ?? err}`)
            await this.prisma.tenderDocument.update({
                where: { id: doc.id },
                data: {
                    status: 'failed',
                    error_message: String(err?.message ?? err).slice(0, 2000),
                },
            }).catch(() => {})
            throw new BadRequestException(
                `Document file is temporarily unavailable. Re-generation failed: ${err?.message ?? err}`
            )
        }
    }

    /**
     * Resolve the storage path for a ready document without any panchayat
     * ownership check — used by the signed-URL public route where the token
     * itself proves authorization.
     */
    async resolveDocStoragePath(tenderId: number, docId: number): Promise<string> {
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: docId } })
        if (!doc || doc.tender_id !== tenderId) throw new NotFoundException('Document not on tender')
        if (doc.status !== 'ready' || !doc.storage_path) throw new BadRequestException('Document not ready')
        return this.ensureArtifactExists(doc)
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
            const storagePath = await this.ensureArtifactExists(d as any).catch(() => null)
            if (!storagePath) continue
            const ext = path.extname(storagePath) || '.html'
            const name = d.vendor_id != null
                ? `${d.template_id}-vendor${d.vendor_id}-v${d.version}${ext}`
                : `${d.template_id}-v${d.version}${ext}`
            const bytes = await this.documentStorage.readBuffer(storagePath).catch(() => null)
            if (!bytes) continue
            archive.append(bytes, { name })
        }
        await archive.finalize()
    }

    // Legacy flow retained for compatibility with existing call sites.
    async getDownloadStoragePath(panchayatId: number, tenderId: number, docId: number): Promise<string> {
        await this.ensureTenderOwned(panchayatId, tenderId)
        return this.resolveDocStoragePath(tenderId, docId)
    }

    async readDocumentBytes(storagePath: string): Promise<Buffer> {
        return this.documentStorage.readBuffer(storagePath)
    }

    // ── Inline editing & multi-format download ───────────────────────

    /** Fetch the HTML source of a document for inline editing. */
    async getHtmlContent(panchayatId: number, tenderId: number, docId: number): Promise<string> {
        await this.ensureTenderOwned(panchayatId, tenderId)
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: docId } })
        if (!doc || doc.tender_id !== tenderId) throw new NotFoundException('Document not on tender')
        if (doc.status !== 'ready' || !doc.storage_path) throw new BadRequestException('Document not ready')

        // Always attempt to read the .html sibling of the stored artifact
        let htmlPath = doc.storage_path
        if (htmlPath.toLowerCase().endsWith('.pdf')) {
            htmlPath = htmlPath.replace(/\.pdf$/i, '.html')
        }

        try {
            const bytes = await this.documentStorage.readBuffer(htmlPath)
            return bytes.toString('utf8')
        } catch {
            // HTML file missing — regenerate artefacts and retry
            const storagePath = await this.renderAndPersistArtifacts(doc)
            const regeneratedHtmlPath = storagePath.toLowerCase().endsWith('.pdf')
                ? storagePath.replace(/\.pdf$/i, '.html')
                : storagePath
            const bytes = await this.documentStorage.readBuffer(regeneratedHtmlPath)
            return bytes.toString('utf8')
        }
    }

    /** Persist user-edited HTML and regenerate the PDF artefact. */
    async saveEditedHtml(args: {
        panchayatId: number
        tenderId: number
        docId: number
        html: string
        actorUserId: number
    }) {
        await this.ensureTenderOwned(args.panchayatId, args.tenderId)
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: args.docId } })
        if (!doc || doc.tender_id !== args.tenderId) throw new NotFoundException('Document not on tender')

        const subdir = path.posix.join('tenders', String(doc.tender_id), doc.template_id)
        const baseName = doc.vendor_id != null ? `v${doc.version}-vendor${doc.vendor_id}` : `v${doc.version}`

        // Write the edited HTML
        const htmlStoragePath = this.buildStoragePath(subdir, `${baseName}.html`)
        await this.documentStorage.writeUtf8(htmlStoragePath, args.html)

        // Try to regenerate the PDF from the edited HTML
        let storagePath = htmlStoragePath
        const pdfBuf = await renderHtmlToPdfBuffer(args.html)
        if (pdfBuf) {
            const pdfStoragePath = this.buildStoragePath(subdir, `${baseName}.pdf`)
            await this.documentStorage.writeBuffer(pdfStoragePath, pdfBuf, 'application/pdf')
            storagePath = pdfStoragePath
        }

        await this.prisma.tenderDocument.update({
            where: { id: doc.id },
            data: {
                status: 'ready',
                storage_path: storagePath,
                generated_at: new Date(),
                error_message: null,
            },
        })

        await this.audit.record({
            tenderId: args.tenderId,
            actorUserId: args.actorUserId,
            event: 'document:content_edited',
            payload: { document_id: doc.id, template_id: doc.template_id },
        })

        return this.prisma.tenderDocument.findUnique({ where: { id: doc.id } })
    }

    /** Return document bytes in the requested format (pdf | html | docx). */
    async getDocumentInFormat(
        panchayatId: number,
        tenderId: number,
        docId: number,
        format: 'pdf' | 'html' | 'docx',
    ): Promise<{ bytes: Buffer; contentType: string; ext: string }> {
        const storagePath = await this.getDownloadStoragePath(panchayatId, tenderId, docId)

        // Derive the .html sibling path
        let htmlPath = storagePath
        if (htmlPath.toLowerCase().endsWith('.pdf')) {
            htmlPath = htmlPath.replace(/\.pdf$/i, '.html')
        }

        if (format === 'html') {
            const bytes = await this.documentStorage.readBuffer(htmlPath)
            return { bytes, contentType: 'text/html; charset=utf-8', ext: 'html' }
        }

        if (format === 'pdf') {
            // Prefer the pre-rendered PDF when available
            if (storagePath.toLowerCase().endsWith('.pdf')) {
                try {
                    const bytes = await this.documentStorage.readBuffer(storagePath)
                    return { bytes, contentType: 'application/pdf', ext: 'pdf' }
                } catch { /* fall through to on-the-fly conversion */ }
            }
            const htmlBytes = await this.documentStorage.readBuffer(htmlPath)
            const html = htmlBytes.toString('utf8')
            const pdfBuf = await renderHtmlToPdfBuffer(html)
            if (!pdfBuf) {
                throw new BadRequestException(
                    'PDF generation is not available. Configure GOTENBERG_URL for PDF output.',
                )
            }
            return { bytes: pdfBuf, contentType: 'application/pdf', ext: 'pdf' }
        }

        if (format === 'docx') {
            const htmlBytes = await this.documentStorage.readBuffer(htmlPath)
            const htmlContent = htmlBytes.toString('utf8')
            const wordHtml = this.wrapHtmlForWord(htmlContent)
            return {
                bytes: Buffer.from(wordHtml, 'utf8'),
                contentType: 'application/msword',
                ext: 'doc',
            }
        }

        throw new BadRequestException(`Unsupported format: ${format}`)
    }

    /** Wrap raw HTML in Microsoft-Word-compatible XML so it opens natively in Word. */
    private wrapHtmlForWord(htmlContent: string): string {
        const bodyMatch = htmlContent.match(/<body[^>]*>([\s\S]*?)<\/body>/i)
        const bodyContent = bodyMatch ? bodyMatch[1] : htmlContent
        const styleMatches = htmlContent.match(/<style[^>]*>[\s\S]*?<\/style>/gi)
        const styles = styleMatches ? styleMatches.join('\n') : ''

        return `<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word"
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta charset="utf-8">
<meta name="ProgId" content="Word.Document">
<meta name="Generator" content="Microsoft Word 15">
<!--[if gte mso 9]><xml>
<w:WordDocument><w:View>Print</w:View><w:Zoom>100</w:Zoom><w:DoNotOptimizeForBrowser/></w:WordDocument>
</xml><![endif]-->
${styles}
</head>
<body>
${bodyContent}
</body>
</html>`
    }

    async getCanvasState(panchayatId: number, tenderId: number, docId: number) {
        await this.ensureTenderOwned(panchayatId, tenderId)
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: docId } })
        if (!doc || doc.tender_id !== tenderId) throw new NotFoundException('Document not on tender')
        const layers = this.normalizedCanvasLayers(
            (doc.field_overrides as Record<string, unknown> | null)?.__canvas_layers
        )
        const canEdit = !this.isCanvasLocked(doc.template_id)
        return {
            doc_id: doc.id,
            tender_id: doc.tender_id,
            template_id: doc.template_id,
            version: doc.version,
            can_edit: canEdit,
            locked_reason: canEdit ? null : 'Canvas editing is locked for this document template',
            layers,
        }
    }

    async saveCanvasState(args: {
        panchayatId: number
        tenderId: number
        docId: number
        layers: Array<Record<string, unknown>>
        actorUserId?: number
    }) {
        await this.ensureTenderOwned(args.panchayatId, args.tenderId)
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: args.docId } })
        if (!doc || doc.tender_id !== args.tenderId) throw new NotFoundException('Document not on tender')
        if (this.isCanvasLocked(doc.template_id)) {
            throw new BadRequestException('Canvas editing is locked for this document template')
        }
        const layers = this.normalizedCanvasLayers(args.layers)
        const overrides = this.withCanvasLayers(doc.field_overrides, layers)
        await this.prisma.tenderDocument.update({
            where: { id: args.docId },
            data: { field_overrides: overrides as any },
        })
        await this.audit.record({
            tenderId: args.tenderId,
            actorUserId: args.actorUserId ?? null,
            event: 'document:canvas_autosave',
            payload: { document_id: doc.id, template_id: doc.template_id, layers_count: layers.length },
        })
        return {
            doc_id: doc.id,
            tender_id: doc.tender_id,
            template_id: doc.template_id,
            version: doc.version,
            layers,
        }
    }

    async mergeCanvasState(args: {
        panchayatId: number
        tenderId: number
        docId: number
        layers: Array<Record<string, unknown>>
        actorUserId?: number
    }) {
        await this.ensureTenderOwned(args.panchayatId, args.tenderId)
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: args.docId } })
        if (!doc || doc.tender_id !== args.tenderId) throw new NotFoundException('Document not on tender')
        if (this.isCanvasLocked(doc.template_id)) {
            throw new BadRequestException('Canvas editing is locked for this document template')
        }
        if (doc.status !== 'ready') throw new BadRequestException('Document not ready')
        if (!doc.storage_path || !doc.storage_path.toLowerCase().endsWith('.pdf')) {
            throw new BadRequestException('Only PDF documents support canvas merge')
        }

        const layers = this.normalizedCanvasLayers(args.layers)
        const mergedOverrides = this.withCanvasLayers(doc.field_overrides, layers)
        const storagePath = await this.renderAndPersistArtifacts({
            id: doc.id,
            tender_id: doc.tender_id,
            template_id: doc.template_id,
            version: doc.version,
            vendor_id: doc.vendor_id,
            field_overrides: mergedOverrides,
        })

        const finalOverrides = this.withCanvasLayers(doc.field_overrides, [])
        await this.prisma.tenderDocument.update({
            where: { id: doc.id },
            data: {
                status: 'ready',
                storage_path: storagePath,
                generated_at: new Date(),
                error_message: null,
                field_overrides: finalOverrides as any,
            },
        })
        await this.audit.record({
            tenderId: args.tenderId,
            actorUserId: args.actorUserId ?? null,
            event: 'document:canvas_merged',
            payload: {
                document_id: doc.id,
                template_id: doc.template_id,
                version: doc.version,
                layers_count: layers.length,
                merged_at: new Date().toISOString(),
                storage_path: storagePath,
            },
        })
        return {
            doc_id: doc.id,
            tender_id: doc.tender_id,
            template_id: doc.template_id,
            version: doc.version,
            merge_status: 'merged',
            layers_count: layers.length,
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
}
