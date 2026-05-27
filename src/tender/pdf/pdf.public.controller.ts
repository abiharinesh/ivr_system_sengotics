import {
    BadRequestException,
    Controller,
    Get,
    Param,
    ParseIntPipe,
    Query,
    Req,
    Res,
    UnauthorizedException,
} from '@nestjs/common'
import { Throttle } from '@nestjs/throttler'
import type { Request, Response } from 'express'
import { TenderPdfService } from './pdf.service'
import { TenderShareTokenService } from './share-token.service'
import { TenderAuditService } from '../audit.service'
import { PrismaService } from '../../prisma/prisma.service'

/**
 * Public, no-auth document download routes. Authorization is proven by the
 * single-use signed `sig` query token minted by an officer at
 * POST /api/admin/tenders/:id/documents/:docId/share-link.
 *
 * The route prefix `public/tenders/:id/documents/...` does not overlap with
 * the existing `/public/tenders/:token` seller controller because that
 * controller only handles 2-segment paths, while these have 4+ segments.
 */
@Controller('public/tenders')
export class TenderPdfPublicController {
    constructor(
        private readonly service: TenderPdfService,
        private readonly tokens: TenderShareTokenService,
        private readonly audit: TenderAuditService,
        private readonly prisma: PrismaService,
    ) {}

    private slugify(value: string): string {
        return value
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/-+/g, '-')
            .replace(/^-|-$/g, '')
    }

    private stamp(d: Date): string {
        const yyyy = d.getFullYear()
        const mm = String(d.getMonth() + 1).padStart(2, '0')
        const dd = String(d.getDate()).padStart(2, '0')
        const hh = String(d.getHours()).padStart(2, '0')
        const mi = String(d.getMinutes()).padStart(2, '0')
        return `${yyyy}${mm}${dd}_${hh}${mi}`
    }

    private clientIp(req: Request): string {
        const xf = (req.headers['x-forwarded-for'] as string | undefined)?.split(',')[0]?.trim()
        return xf || req.ip || 'unknown'
    }

    @Get(':id/documents/:docId/download')
    @Throttle({ default: { limit: 30, ttl: 60_000 } })
    async downloadDoc(
        @Req() req: Request,
        @Res() res: Response,
        @Param('id', ParseIntPipe) id: number,
        @Param('docId', ParseIntPipe) docId: number,
        @Query('sig') sig?: string,
    ) {
        if (!sig) throw new UnauthorizedException('Missing share token')
        const payload = this.tokens.verify(sig)
        if (payload.kind !== 'doc') {
            throw new UnauthorizedException('Wrong token type')
        }
        if (payload.tenderId !== id || payload.docId !== docId) {
            throw new UnauthorizedException('Token does not match this resource')
        }
        const storagePath = await this.service.resolveDocStoragePath(id, docId)
        const doc = await this.prisma.tenderDocument.findUnique({ where: { id: docId } })
        const tender = await this.prisma.tender.findUnique({
            where: { id },
            include: { panchayat: { select: { name: true } } },
        })
        const ext = storagePath.toLowerCase().endsWith('.html') ? 'html' : 'pdf'
        const panchayat = this.slugify(tender?.panchayat?.name ?? 'panchayat')
        const template = this.slugify(doc?.template_id ?? 'document')
        const version = doc?.version ?? 1
        const filename = `${panchayat}-${id}-${template}-v${version}-${this.stamp(doc?.generated_at ?? new Date())}.${ext}`
        await this.audit.record({
            tenderId: id,
            event: 'doc:share_link_used',
            payload: { kind: 'doc', doc_id: docId, ip: this.clientIp(req) },
        })
        const bytes = await this.service.readDocumentBytes(storagePath)
        res.setHeader('Content-Type', ext === 'html' ? 'text/html; charset=utf-8' : 'application/pdf')
        res.setHeader('Content-Disposition', `attachment; filename="${filename}"`)
        res.send(bytes)
    }

    @Get(':id/documents.zip')
    @Throttle({ default: { limit: 30, ttl: 60_000 } })
    async downloadZip(
        @Req() req: Request,
        @Res() res: Response,
        @Param('id', ParseIntPipe) id: number,
        @Query('sig') sig?: string,
    ) {
        if (!sig) throw new UnauthorizedException('Missing share token')
        const payload = this.tokens.verify(sig)
        if (payload.kind !== 'zip') {
            throw new UnauthorizedException('Wrong token type')
        }
        if (payload.tenderId !== id) {
            throw new UnauthorizedException('Token does not match this tender')
        }
        // Sanity: docId must not be present on zip tokens.
        if (payload.docId != null) {
            throw new BadRequestException('Malformed token payload')
        }
        const tender = await this.prisma.tender.findUnique({
            where: { id },
            include: { panchayat: { select: { name: true } } },
        })
        const panchayat = this.slugify(tender?.panchayat?.name ?? 'panchayat')
        res.setHeader('Content-Type', 'application/zip')
        res.setHeader('Content-Disposition', `attachment; filename="${panchayat}-${id}-documents-${this.stamp(new Date())}.zip"`)
        await this.audit.record({
            tenderId: id,
            event: 'doc:share_link_used',
            payload: { kind: 'zip', ip: this.clientIp(req) },
        })
        await this.service.streamLatestZipUnchecked(id, res)
    }
}
