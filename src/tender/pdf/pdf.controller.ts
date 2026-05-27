import {
    BadRequestException,
    Body,
    Controller,
    ForbiddenException,
    Get,
    NotFoundException,
    Param,
    ParseIntPipe,
    Post,
    Query,
    Req,
    Res,
    UseGuards,
} from '@nestjs/common'
import type { Request, Response } from 'express'
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard'
import { RolesGuard } from '../../auth/guards/roles.guard'
import { Roles } from '../../auth/decorators/roles.decorator'
import { TenderPdfService } from './pdf.service'
import { TenderAuditService } from '../audit.service'
import { PrismaService } from '../../prisma/prisma.service'
import {
    SHARE_TOKEN_DEFAULT_MINUTES,
    SHARE_TOKEN_MAX_MINUTES,
    TenderShareTokenService,
} from './share-token.service'

interface AuthenticatedRequest {
    user: { id: number; email: string; role: string; panchayat_id: number | null }
}

function slugify(value: string): string {
    return value
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/-+/g, '-')
        .replace(/^-|-$/g, '')
}

function formatStamp(d: Date): string {
    const yyyy = d.getFullYear()
    const mm = String(d.getMonth() + 1).padStart(2, '0')
    const dd = String(d.getDate()).padStart(2, '0')
    const hh = String(d.getHours()).padStart(2, '0')
    const mi = String(d.getMinutes()).padStart(2, '0')
    return `${yyyy}${mm}${dd}_${hh}${mi}`
}

function resolveOrigin(req: Request): string {
    const xfProto = (req.headers['x-forwarded-proto'] as string | undefined)?.split(',')[0]?.trim()
    const xfHost = (req.headers['x-forwarded-host'] as string | undefined)?.split(',')[0]?.trim()
    const host = xfHost ?? req.get('host') ?? 'localhost:3000'
    const proto = xfProto ?? (req.protocol || 'http')
    return `${proto}://${host}`
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin')
@Controller('api/admin/tenders')
export class TenderPdfController {
    constructor(
        private readonly service: TenderPdfService,
        private readonly shareTokens: TenderShareTokenService,
        private readonly audit: TenderAuditService,
        private readonly prisma: PrismaService,
    ) {}

    private getPanchayatId(req: AuthenticatedRequest): number {
        if (!req.user.panchayat_id) throw new ForbiddenException('Account is not associated with a panchayat')
        return req.user.panchayat_id
    }

    private clampTtl(raw: unknown): number {
        if (raw == null) return SHARE_TOKEN_DEFAULT_MINUTES
        const n = typeof raw === 'number' ? raw : Number(raw)
        if (!Number.isFinite(n) || n <= 0) {
            throw new BadRequestException('ttl_minutes must be a positive number')
        }
        return Math.min(SHARE_TOKEN_MAX_MINUTES, Math.max(1, Math.floor(n)))
    }

    @Post(':id/documents/:templateId/generate')
    generate(
        @Req() req: AuthenticatedRequest,
        @Param('id', ParseIntPipe) id: number,
        @Param('templateId') templateId: string,
        @Body() body: { vendor_id?: number; field_overrides?: Record<string, unknown> } = {}
    ) {
        return this.service.generate({
            panchayatId: this.getPanchayatId(req),
            tenderId: id,
            templateId,
            actorUserId: req.user.id,
            vendorId: body.vendor_id ?? null,
            fieldOverrides: body.field_overrides ?? null,
        })
    }

    @Get(':id/documents')
    list(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
        return this.service.list(this.getPanchayatId(req), id)
    }

    @Get(':id/documents/:docId/preview')
    async preview(
        @Req() req: AuthenticatedRequest,
        @Res() res: Response,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number
    ) {
        try {
            const storagePath = await this.service.getDownloadStoragePath(this.getPanchayatId(req), id, docId)
            const ext = storagePath.toLowerCase().endsWith('.html') ? 'html' : 'pdf'
            const bytes = await this.service.readDocumentBytes(storagePath)
            res.setHeader('Content-Type', ext === 'html' ? 'text/html; charset=utf-8' : 'application/pdf')
            res.setHeader('Content-Disposition', ext === 'html' ? 'inline' : 'inline; filename="preview.pdf"')
            res.send(bytes)
        } catch (err: any) {
            if (!res.headersSent) {
                res.status(err?.status ?? 500).json({
                    error: 'Document preview failed',
                    message: err?.message ?? 'Unknown error',
                    hint: 'Try regenerating the document. If this persists, check that SUPABASE_SERVICE_ROLE_KEY and GOTENBERG_URL are set in environment variables.',
                })
            }
        }
    }

    @Get(':id/documents/:docId/download')
    async download(
        @Req() req: AuthenticatedRequest,
        @Res() res: Response,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number,
        @Query('format') format?: string,
    ) {
        try {
            const panchayatId = this.getPanchayatId(req)
            const doc = await this.prisma.tenderDocument.findUnique({ where: { id: docId } })
            const tender = await this.prisma.tender.findUnique({
                where: { id },
                include: { panchayat: { select: { name: true } } },
            })
            const panchayat = slugify(tender?.panchayat?.name ?? 'panchayat')
            const template = slugify(doc?.template_id ?? 'document')
            const version = doc?.version ?? 1
            const stamp = formatStamp((doc?.generated_at ?? new Date()))

            // Format-specific download (pdf | html | docx)
            if (format === 'pdf' || format === 'html' || format === 'docx') {
                const result = await this.service.getDocumentInFormat(panchayatId, id, docId, format)
                const filename = `${panchayat}-${id}-${template}-v${version}-${stamp}.${result.ext}`
                res.setHeader('Content-Type', result.contentType)
                res.setHeader('Content-Disposition', `attachment; filename="${filename}"`)
                res.send(result.bytes)
                return
            }

            // Default: auto-detect from storage path
            const storagePath = await this.service.getDownloadStoragePath(panchayatId, id, docId)
            const ext = storagePath.toLowerCase().endsWith('.html') ? 'html' : 'pdf'
            const filename = `${panchayat}-${id}-${template}-v${version}-${stamp}.${ext}`
            const bytes = await this.service.readDocumentBytes(storagePath)
            res.setHeader('Content-Type', ext === 'html' ? 'text/html; charset=utf-8' : 'application/pdf')
            res.setHeader('Content-Disposition', `attachment; filename="${filename}"`)
            res.send(bytes)
        } catch (err: any) {
            if (!res.headersSent) {
                res.status(err?.status ?? 500).json({
                    error: 'Document download failed',
                    message: err?.message ?? 'Unknown error',
                    hint: 'Try regenerating the document.',
                })
            }
        }
    }

    /** Return the HTML source of a document for inline editing. */
    @Get(':id/documents/:docId/html-content')
    async getHtmlContent(
        @Req() req: AuthenticatedRequest,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number,
    ) {
        const html = await this.service.getHtmlContent(this.getPanchayatId(req), id, docId)
        return { html }
    }

    /** Save user-edited HTML content back to storage. */
    @Post(':id/documents/:docId/content')
    async saveContent(
        @Req() req: AuthenticatedRequest,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number,
        @Body() body: { html: string },
    ) {
        if (!body?.html || typeof body.html !== 'string') {
            throw new BadRequestException('html field is required')
        }
        return this.service.saveEditedHtml({
            panchayatId: this.getPanchayatId(req),
            tenderId: id,
            docId,
            html: body.html,
            actorUserId: req.user.id,
        })
    }

    @Get(':id/documents/:docId/canvas')
    getCanvasState(
        @Req() req: AuthenticatedRequest,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number
    ) {
        return this.service.getCanvasState(this.getPanchayatId(req), id, docId)
    }

    @Post(':id/documents/:docId/canvas')
    saveCanvasState(
        @Req() req: AuthenticatedRequest,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number,
        @Body() body: { layers?: Array<Record<string, unknown>> } = {}
    ) {
        return this.service.saveCanvasState({
            panchayatId: this.getPanchayatId(req),
            tenderId: id,
            docId,
            layers: body.layers ?? [],
            actorUserId: req.user.id,
        })
    }

    @Post(':id/documents/:docId/canvas/merge')
    async mergeCanvasState(
        @Req() req: AuthenticatedRequest,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number,
        @Body() body: { layers?: Array<Record<string, unknown>> } = {}
    ) {
        return this.service.mergeCanvasState({
            panchayatId: this.getPanchayatId(req),
            tenderId: id,
            docId,
            layers: body.layers ?? [],
            actorUserId: req.user.id,
        })
    }

    @Get(':id/documents.zip')
    async zipBundle(
        @Req() req: AuthenticatedRequest,
        @Res() res: Response,
        @Param('id', ParseIntPipe) id: number
    ) {
        const pid = this.getPanchayatId(req)
        const tender = await this.prisma.tender.findUnique({
            where: { id },
            include: { panchayat: { select: { name: true } } },
        })
        const panchayat = slugify(tender?.panchayat?.name ?? 'panchayat')
        const stamp = formatStamp(new Date())
        const zipName = `${panchayat}-${id}-documents-${stamp}.zip`
        res.setHeader('Content-Type', 'application/zip')
        res.setHeader('Content-Disposition', `attachment; filename="${zipName}"`)
        await this.service.streamLatestZip(pid, id, res)
    }

    @Post(':id/documents/:docId/share-link')
    async mintDocShareLink(
        @Req() req: AuthenticatedRequest & { protocol: string; headers: any; get: any },
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number,
        @Body() body: { ttl_minutes?: number } = {},
    ) {
        const panchayatId = this.getPanchayatId(req)

        // Verify ownership + readiness via the existing checked path resolver
        // (it throws Not Found / Forbidden / BadRequest in the right places).
        await this.service.getDownloadStoragePath(panchayatId, id, docId)

        const ttl = this.clampTtl(body?.ttl_minutes)
        const { token, expiresAt } = this.shareTokens.sign(
            { kind: 'doc', tenderId: id, docId },
            ttl,
        )
        const origin = resolveOrigin(req as unknown as Request)
        const url = `${origin}/public/tenders/${id}/documents/${docId}/download?sig=${encodeURIComponent(token)}`
        await this.audit.record({
            tenderId: id,
            actorUserId: req.user.id,
            event: 'doc:share_link_minted',
            payload: { kind: 'doc', doc_id: docId, ttl_minutes: ttl, expires_at: expiresAt.toISOString() },
        })
        return { url, expires_at: expiresAt.toISOString(), ttl_minutes: ttl }
    }

    @Post(':id/documents.zip/share-link')
    async mintZipShareLink(
        @Req() req: AuthenticatedRequest & { protocol: string; headers: any; get: any },
        @Param('id', ParseIntPipe) id: number,
        @Body() body: { ttl_minutes?: number } = {},
    ) {
        const panchayatId = this.getPanchayatId(req)

        // Ensure tender ownership before minting a zip link. Reuse `list`
        // which calls `ensureTenderOwned` internally.
        const tender = await this.prisma.tender.findUnique({ where: { id } })
        if (!tender) throw new NotFoundException('Tender not found')
        if (tender.panchayat_id !== panchayatId) {
            throw new ForbiddenException('Tender belongs to another panchayat')
        }

        const ttl = this.clampTtl(body?.ttl_minutes)
        const { token, expiresAt } = this.shareTokens.sign(
            { kind: 'zip', tenderId: id },
            ttl,
        )
        const origin = resolveOrigin(req as unknown as Request)
        const url = `${origin}/public/tenders/${id}/documents.zip?sig=${encodeURIComponent(token)}`
        await this.audit.record({
            tenderId: id,
            actorUserId: req.user.id,
            event: 'doc:share_link_minted',
            payload: { kind: 'zip', ttl_minutes: ttl, expires_at: expiresAt.toISOString() },
        })
        return { url, expires_at: expiresAt.toISOString(), ttl_minutes: ttl }
    }
}
