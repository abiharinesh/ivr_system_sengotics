import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

/**
 * Meta WhatsApp Cloud API — outbound messages and media download.
 * Env: WHATSAPP_CLOUD_TOKEN, WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_APP_SECRET (signature), WHATSAPP_VERIFY_TOKEN (webhook GET).
 */
@Injectable()
export class WhatsAppService {
  private readonly logger = new Logger(WhatsAppService.name);
  private readonly graphVersion = 'v21.0';

  constructor(private readonly config: ConfigService) {}

  isConfigured(): boolean {
    const token = this.config.get<string>('WHATSAPP_CLOUD_TOKEN');
    const phoneId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID');
    return Boolean(token && phoneId);
  }

  verifyWebhookToken(token: string | undefined): boolean {
    const expected = this.config.get<string>('WHATSAPP_VERIFY_TOKEN');
    if (!expected) {
      this.logger.warn(
        'WHATSAPP_VERIFY_TOKEN not set — webhook verification fails',
      );
      return false;
    }
    return token === expected;
  }

  verifySignature(
    rawBody: Buffer,
    signatureHeader: string | undefined,
  ): boolean {
    const secret = this.config.get<string>('WHATSAPP_APP_SECRET');
    if (!secret) {
      this.logger.warn(
        'WHATSAPP_APP_SECRET not set — accepting webhook without signature check (dev only)',
      );
      return true;
    }
    if (!signatureHeader?.startsWith('sha256=')) return false;
    const expected =
      'sha256=' +
      crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
    try {
      const a = Buffer.from(expected);
      const b = Buffer.from(signatureHeader);
      return a.length === b.length && crypto.timingSafeEqual(a, b);
    } catch {
      return false;
    }
  }

  async sendText(
    toE164: string,
    body: string,
  ): Promise<{ ok: boolean; skipped?: boolean }> {
    if (!this.isConfigured()) {
      this.logger.debug('WhatsApp not configured — skip send');
      return { ok: true, skipped: true };
    }
    const token = this.config.get<string>('WHATSAPP_CLOUD_TOKEN')!;
    const phoneId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID')!;
    const to = toE164.replace(/^\+/, '').replace(/\D/g, '');

    const res = await fetch(
      `https://graph.facebook.com/${this.graphVersion}/${phoneId}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to,
          type: 'text',
          text: { body },
        }),
      },
    );
    if (!res.ok) {
      const errText = await res.text();
      this.logger.warn(`WhatsApp send failed ${res.status}: ${errText}`);
      return { ok: false };
    }
    return { ok: true };
  }

  /** Download binary for inbound image `media.id`. */
  async downloadMediaBuffer(mediaId: string): Promise<Buffer> {
    const token = this.config.get<string>('WHATSAPP_CLOUD_TOKEN');
    if (!token) throw new Error('WHATSAPP_CLOUD_TOKEN not configured');

    const metaRes = await fetch(
      `https://graph.facebook.com/${this.graphVersion}/${encodeURIComponent(mediaId)}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (!metaRes.ok) {
      throw new Error(`Media meta ${metaRes.status}: ${await metaRes.text()}`);
    }
    const meta = (await metaRes.json()) as { url?: string };
    if (!meta.url) throw new Error('Media URL missing');

    const binRes = await fetch(meta.url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!binRes.ok) {
      throw new Error(`Media download ${binRes.status}`);
    }
    return Buffer.from(await binRes.arrayBuffer());
  }
}
