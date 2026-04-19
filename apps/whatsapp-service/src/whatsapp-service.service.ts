import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import * as crypto from 'crypto'

@Injectable()
export class WhatsappServiceService {
    private readonly logger = new Logger(WhatsappServiceService.name)
    private readonly graphVersion = 'v21.0'
    constructor(private readonly config: ConfigService) {}

    isConfigured(): boolean {
        return Boolean(this.config.get<string>('WHATSAPP_CLOUD_TOKEN') && this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID'))
    }

    verifyWebhookToken(token: string | undefined): boolean {
        const expected = this.config.get<string>('WHATSAPP_VERIFY_TOKEN')
        if (!expected) { this.logger.warn('WHATSAPP_VERIFY_TOKEN not set'); return false }
        return token === expected
    }

    verifySignature(rawBody: Buffer, signatureHeader: string | undefined): boolean {
        const secret = this.config.get<string>('WHATSAPP_APP_SECRET')
        if (!secret) { this.logger.warn('WHATSAPP_APP_SECRET not set — accepting without check (dev only)'); return true }
        if (!signatureHeader?.startsWith('sha256=')) return false
        const expected = 'sha256=' + crypto.createHmac('sha256', secret).update(rawBody).digest('hex')
        try {
            const a = Buffer.from(expected); const b = Buffer.from(signatureHeader)
            return a.length === b.length && crypto.timingSafeEqual(a, b)
        } catch { return false }
    }

    async sendText(toE164: string, body: string): Promise<{ ok: boolean; skipped?: boolean }> {
        if (!this.isConfigured()) return { ok: true, skipped: true }
        const token = this.config.get<string>('WHATSAPP_CLOUD_TOKEN')!
        const phoneId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID')!
        const to = toE164.replace(/^\+/, '').replace(/\D/g, '')
        const res = await fetch(`https://graph.facebook.com/${this.graphVersion}/${phoneId}/messages`, {
            method: 'POST',
            headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ messaging_product: 'whatsapp', to, type: 'text', text: { body } }),
        })
        if (!res.ok) { this.logger.warn(`WhatsApp send failed ${res.status}: ${await res.text()}`); return { ok: false } }
        return { ok: true }
    }

    async downloadMediaBuffer(mediaId: string): Promise<Buffer> {
        const token = this.config.get<string>('WHATSAPP_CLOUD_TOKEN')
        if (!token) throw new Error('WHATSAPP_CLOUD_TOKEN not configured')
        const metaRes = await fetch(`https://graph.facebook.com/${this.graphVersion}/${encodeURIComponent(mediaId)}`, { headers: { Authorization: `Bearer ${token}` } })
        if (!metaRes.ok) throw new Error(`Media meta ${metaRes.status}: ${await metaRes.text()}`)
        const meta = (await metaRes.json()) as { url?: string }
        if (!meta.url) throw new Error('Media URL missing')
        const binRes = await fetch(meta.url, { headers: { Authorization: `Bearer ${token}` } })
        if (!binRes.ok) throw new Error(`Media download ${binRes.status}`)
        return Buffer.from(await binRes.arrayBuffer())
    }
}
