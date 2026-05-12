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

    @Get(':id/documents/:docId/download')
    async download(
        @Req() req: AuthenticatedRequest,
        @Res() res: Response,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number
    ) {
        const abs = await this.service.getDownloadAbsolutePath(this.getPanchayatId(req), id, docId)
        const filename = abs.split(/[\\/]/).pop() ?? 'tender-doc'
        res.download(abs, filename)
    }

    @Get(':id/documents.zip')
    async zipBundle(
        @Req() req: AuthenticatedRequest,
        @Res() res: Response,
        @Param('id', ParseIntPipe) id: number
    ) {
        const pid = this.getPanchayatId(req)
        res.setHeader('Content-Type', 'application/zip')
        res.setHeader('Content-Disposition', `attachment; filename="tender-${id}-bundle.zip"`)
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
        await this.service.getDownloadAbsolutePath(panchayatId, id, docId)

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
