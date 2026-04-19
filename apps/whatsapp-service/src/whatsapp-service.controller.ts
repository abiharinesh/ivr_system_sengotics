import { Controller, Get, Post, Req, Res, Query, Logger, HttpCode } from '@nestjs/common'
import type { Request, Response } from 'express'
import exifr from 'exifr'
import { WhatsappServiceService } from './whatsapp-service.service'
import { PrismaService } from '@app/shared'

const ELECTRICIAN_SERVICE_URL = process.env.ELECTRICIAN_SERVICE_URL || 'http://localhost:3004'

@Controller('webhooks/whatsapp')
export class WhatsappServiceController {
    private readonly logger = new Logger(WhatsappServiceController.name)
    constructor(
        private readonly whatsapp: WhatsappServiceService,
        private readonly prisma: PrismaService,
    ) {}

    @Get()
    verify(@Query('hub.mode') mode: string, @Query('hub.verify_token') token: string, @Query('hub.challenge') challenge: string, @Res() res: Response) {
        if (mode === 'subscribe' && this.whatsapp.verifyWebhookToken(token)) return res.status(200).send(challenge)
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
        } catch (e: any) { this.logger.warn(`Webhook parse error: ${e?.message}`) }
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
                for (const msg of messages) await this.handleMessage(msg)
            }
        }
    }

    private async handleMessage(msg: any): Promise<void> {
        const fromRaw = String(msg?.from ?? '')
        if (!fromRaw) return
        const user = await this.findUserByWaPhone(fromRaw)
        if (!user || user.role !== 'electrician') return
        const type = String(msg?.type ?? '')

        if (type === 'interactive') {
            const bid = msg?.interactive?.button_reply?.id || msg?.interactive?.list_reply?.id
            if (typeof bid === 'string' && bid.startsWith('done_')) {
                const cid = parseInt(bid.slice('done_'.length), 10)
                if (!Number.isNaN(cid)) await this.callElectricianService('markDone', cid, user.id)
            }
            return
        }

        if (type === 'text') {
            const text = String(msg?.text?.body ?? '').trim().toUpperCase()
            if (text === 'DONE' || text.startsWith('DONE ')) {
                const parts = text.split(/\s+/)
                const idPart = parts.length > 1 ? parseInt(parts[1], 10) : NaN
                if (!Number.isNaN(idPart)) await this.callElectricianService('markDone', idPart, user.id)
            }
            return
        }

        if (type === 'image') {
            const mediaId = msg?.image?.id
            if (!mediaId) return
            const buf = await this.whatsapp.downloadMediaBuffer(String(mediaId))
            let lat: number | null = null; let lng: number | null = null
            try {
                const tags = await exifr.parse(buf, { gps: true })
                if (tags && typeof tags === 'object') {
                    if (typeof tags.latitude === 'number') lat = tags.latitude
                    if (typeof tags.longitude === 'number') lng = tags.longitude
                }
            } catch { /* exif missing */ }
            // For WhatsApp image proofs, we call electrician-service via HTTP
            this.logger.log(`WhatsApp image from user ${user.id} — exif lat=${lat}, lng=${lng}`)
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
            const u = await this.prisma.user.findFirst({ where: { phone_e164: v } })
            if (u) return u
        }
        return null
    }

    private async callElectricianService(action: 'markDone', complaintId: number, userId: number) {
        try {
            await fetch(`${ELECTRICIAN_SERVICE_URL}/api/electrician/internal/whatsapp-done`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ complaint_id: complaintId, electrician_user_id: userId }),
            })
        } catch (err: any) { this.logger.warn(`electrician-service call failed: ${err?.message}`) }
    }
}
