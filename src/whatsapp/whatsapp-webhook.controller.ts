import { Controller, Get, Post, Req, Res, Query, Logger, HttpCode } from '@nestjs/common'
import { SkipThrottle } from '@nestjs/throttler'
import type { Request, Response } from 'express'
import exifr from 'exifr'
import { WhatsAppService } from './whatsapp.service'
import { ElectricianOpsService } from '../field-ops/field-ops.service'
import { PrismaService } from '../prisma/prisma.service'

/** Meta / WhatsApp Cloud API webhooks (no JWT). */
@SkipThrottle()
@Controller('api/webhooks/whatsapp')
export class WhatsAppWebhookController {
    private readonly logger = new Logger(WhatsAppWebhookController.name)

    constructor(
        private readonly whatsapp: WhatsAppService,
        private readonly electricianOps: ElectricianOpsService,
        private readonly prisma: PrismaService
    ) { }

    @Get()
    verify(
        @Query('hub.mode') mode: string,
        @Query('hub.verify_token') token: string,
        @Query('hub.challenge') challenge: string,
        @Res() res: Response
    ) {
        const ok = this.whatsapp.verifyWebhookToken(token)
        if (mode === 'subscribe' && ok) {
            return res.status(200).send(challenge)
        }
        return res.status(403).send('Forbidden')
    }

    @Post()
    @HttpCode(200)
    async receive(@Req() req: Request & { rawBody?: Buffer }, @Res() res: Response) {
        const rawBody = req.rawBody
        const sig = (req.headers['x-hub-signature-256'] as string) || ''
        if (rawBody && !this.whatsapp.verifySignature(rawBody, sig)) {
            this.logger.warn('Invalid WhatsApp webhook signature')
            return res.status(401).send('Invalid signature')
        }

        try {
            const body = JSON.parse(rawBody?.toString('utf8') || '{}')
            await this.handlePayload(body)
        } catch (e: any) {
            this.logger.warn(`Webhook parse error: ${e?.message}`)
        }
        return res.status(200).send('EVENT_RECEIVED')
    }

    private async handlePayload(body: unknown): Promise<void> {
        if (!body || typeof body !== 'object') return
        const entries = (body as any).entry as any[] | undefined
        if (!entries?.length) return

        for (const ent of entries) {
            const changes = ent?.changes as any[] | undefined
            if (!changes?.length) continue
            for (const ch of changes) {
                const messages = ch?.value?.messages as any[] | undefined
                if (!messages?.length) continue
                for (const msg of messages) {
                    await this.handleMessage(msg)
                }
            }
        }
    }

    private async handleMessage(msg: any): Promise<void> {
        const fromRaw = String(msg?.from ?? '')
        if (!fromRaw) return

        const user = await this.findUserByWaPhone(fromRaw)
        if (!user || user.role !== 'electrician') {
            this.logger.debug(`No electrician user for WhatsApp sender ${fromRaw}`)
            return
        }

        const type = String(msg?.type ?? '')

        if (type === 'interactive') {
            const bid = msg?.interactive?.button_reply?.id || msg?.interactive?.list_reply?.id
            if (typeof bid === 'string' && bid.startsWith('done_')) {
                const cid = parseInt(bid.slice('done_'.length), 10)
                if (!Number.isNaN(cid)) {
                    await this.electricianOps.markWhatsAppDoneAck(cid, user.id)
                }
            }
            return
        }

        if (type === 'text') {
            const text = String(msg?.text?.body ?? '').trim().toUpperCase()
            if (text === 'DONE' || text.startsWith('DONE ')) {
                const parts = text.split(/\s+/)
                const idPart = parts.length > 1 ? parseInt(parts[1], 10) : NaN
                if (!Number.isNaN(idPart)) {
                    await this.electricianOps.markWhatsAppDoneAck(idPart, user.id)
                }
            }
            return
        }

        if (type === 'image') {
            const mediaId = msg?.image?.id
            if (!mediaId) return
            const buf = await this.whatsapp.downloadMediaBuffer(String(mediaId))
            let lat: number | null = null
            let lng: number | null = null
            try {
                const tags = await exifr.parse(buf, { gps: true })
                if (tags && typeof tags === 'object') {
                    const t = tags as Record<string, unknown>
                    if (typeof t.latitude === 'number') lat = t.latitude
                    if (typeof t.longitude === 'number') lng = t.longitude
                }
            } catch {
                /* exif missing or stripped */
            }
            const result = await this.electricianOps.attachWhatsAppProof({
                electricianUserId: user.id,
                image: { buffer: buf, originalname: `wa-${mediaId}.jpg` },
                exifLat: lat,
                exifLng: lng,
            })
            if ('error' in result) {
                this.logger.warn(`WhatsApp proof attach: ${result.error} (user ${user.id})`)
            }
        }
    }

    private normalizeWaPhone(from: string): string[] {
        const digits = from.replace(/\D/g, '')
        const variants = new Set<string>()
        if (digits.length) variants.add(`+${digits}`)
        variants.add(from.startsWith('+') ? from : `+${from}`)
        return [...variants]
    }

    private async findUserByWaPhone(from: string) {
        const variants = this.normalizeWaPhone(from)
        for (const v of variants) {
            const u = await this.prisma.user.findFirst({
                where: { phone_e164: v },
            })
            if (u) return u
        }
        return null
    }
}
