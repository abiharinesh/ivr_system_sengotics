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
    ) {}

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
        const abs = await this.service.resolveDocAbsolutePath(id, docId)
        const filename = abs.split(/[\\/]/).pop() ?? 'tender-doc'
        await this.audit.record({
            tenderId: id,
            event: 'doc:share_link_used',
            payload: { kind: 'doc', doc_id: docId, ip: this.clientIp(req) },
        })
        res.download(abs, filename)
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
        res.setHeader('Content-Type', 'application/zip')
        res.setHeader('Content-Disposition', `attachment; filename="tender-${id}-bundle.zip"`)
        await this.audit.record({
            tenderId: id,
            event: 'doc:share_link_used',
            payload: { kind: 'zip', ip: this.clientIp(req) },
        })
        await this.service.streamLatestZipUnchecked(id, res)
    }
}
