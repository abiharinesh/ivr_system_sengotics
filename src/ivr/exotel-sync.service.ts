import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

/** Timeout for individual Exotel API requests (ms). */
const EXOTEL_TIMEOUT_MS = 30_000;

export interface SyncResult {
  synced: number;
  skipped: number;
  errors: number;
}

/**
 * Syncs data from the Exotel REST API into local database tables.
 *
 * Covers three data types:
 * 1. **Phone numbers** — the virtual numbers assigned to the Exotel account
 * 2. **Bots** — the AI voicebots configured on the account
 * 3. **Interactions** — the call/bot interaction history with audio & transcripts
 *
 * All endpoints use Exotel Basic Auth (`EXOTEL_API_KEY:EXOTEL_API_TOKEN`).
 */
@Injectable()
export class ExotelSyncService {
  private readonly logger = new Logger(ExotelSyncService.name);
  private readonly apiKey: string;
  private readonly apiToken: string;
  private readonly accountSid: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    this.apiKey = this.config.get<string>('EXOTEL_API_KEY', '');
    this.apiToken = this.config.get<string>('EXOTEL_API_TOKEN', '');
    // Account SID is typically the same as the API key for Exotel
    this.accountSid = this.config.get<string>('EXOTEL_ACCOUNT_SID', this.apiKey);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  private get isConfigured(): boolean {
    return !!(this.apiKey && this.apiToken);
  }

  private get authHeader(): string {
    return `Basic ${Buffer.from(`${this.apiKey}:${this.apiToken}`).toString('base64')}`;
  }

  private async exotelFetch(url: string): Promise<any> {
    if (!this.isConfigured) {
      throw new Error('Exotel API credentials not configured (EXOTEL_API_KEY / EXOTEL_API_TOKEN)');
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), EXOTEL_TIMEOUT_MS);

    try {
      const response = await fetch(url, {
        headers: {
          Authorization: this.authHeader,
          Accept: 'application/json',
        },
        signal: controller.signal,
      });

      if (!response.ok) {
        const body = await response.text().catch(() => '');
        throw new Error(`Exotel API error: HTTP ${response.status} ${response.statusText} — ${body.slice(0, 200)}`);
      }

      return response.json();
    } finally {
      clearTimeout(timeout);
    }
  }

  // ── Phone Number Sync ────────────────────────────────────────────────────

  /**
   * Fetches all incoming phone numbers from the Exotel account and upserts
   * them into the `exotel_phone_numbers` table.
   */
  async syncPhoneNumbers(): Promise<{ synced: number; total: number }> {
    this.logger.log('[SYNC] Starting phone number sync from Exotel...');

    try {
      const url = `https://api.exotel.com/v1/Accounts/${this.accountSid}/IncomingPhoneNumbers.json`;
      const data = await this.exotelFetch(url);

      const numbers = data?.IncomingPhoneNumbers ?? data?.incoming_phone_numbers ?? [];
      if (!Array.isArray(numbers)) {
        this.logger.warn('[SYNC] Unexpected phone number response format');
        return { synced: 0, total: 0 };
      }

      let synced = 0;
      for (const num of numbers) {
        const phoneNumber = num.PhoneNumber ?? num.phone_number ?? num.Number ?? '';
        const sid = num.Sid ?? num.sid ?? null;
        const friendlyName = num.FriendlyName ?? num.friendly_name ?? null;

        if (!phoneNumber) continue;

        await this.prisma.exotelPhoneNumber.upsert({
          where: { phone_number: phoneNumber },
          create: {
            phone_number: phoneNumber,
            friendly_name: friendlyName,
            exotel_sid: sid,
            is_active: true,
          },
          update: {
            friendly_name: friendlyName,
            exotel_sid: sid,
            updated_at: new Date(),
          },
        });
        synced++;
      }

      this.logger.log(`[SYNC] ✅ Phone numbers synced: ${synced}/${numbers.length}`);
      return { synced, total: numbers.length };
    } catch (err) {
      this.logger.error(`[SYNC] Phone number sync failed: ${(err as Error).message}`);
      throw err;
    }
  }

  // ── Bot Sync ─────────────────────────────────────────────────────────────

  /**
   * Fetches bots from Exotel and upserts into `exotel_bots` table.
   * Uses the Exotel Voicebot API endpoint.
   */
  async syncBots(): Promise<{ synced: number; total: number }> {
    this.logger.log('[SYNC] Starting bot sync from Exotel...');

    try {
      // Exotel bot listing endpoint (Exotel platform API)
      const url = `https://api.exotel.com/v2/accounts/${this.accountSid}/bots`;
      const data = await this.exotelFetch(url);

      const bots = data?.bots ?? data?.data ?? data?.Bots ?? [];
      if (!Array.isArray(bots)) {
        this.logger.warn('[SYNC] Unexpected bot response format — may need endpoint adjustment');
        return { synced: 0, total: 0 };
      }

      let synced = 0;
      for (const bot of bots) {
        const botId = bot.id ?? bot.bot_id ?? bot.BotId ?? '';
        const botName = bot.name ?? bot.bot_name ?? bot.BotName ?? 'Unknown Bot';
        const version = bot.version ?? bot.bot_version ?? null;
        const description = bot.description ?? null;

        if (!botId) continue;

        await this.prisma.exotelBot.upsert({
          where: { bot_id: String(botId) },
          create: {
            bot_id: String(botId),
            bot_name: botName,
            bot_version: version,
            description,
            is_active: true,
          },
          update: {
            bot_name: botName,
            bot_version: version,
            description,
            updated_at: new Date(),
          },
        });
        synced++;
      }

      this.logger.log(`[SYNC] ✅ Bots synced: ${synced}/${bots.length}`);
      return { synced, total: bots.length };
    } catch (err) {
      this.logger.error(`[SYNC] Bot sync failed: ${(err as Error).message}`);
      throw err;
    }
  }

  // ── Interaction History Sync ─────────────────────────────────────────────

  /**
   * Fetches call/interaction history from Exotel for the given date range
   * and stores it in `exotel_interactions`.
   */
  async syncInteractionHistory(
    dateFrom?: Date,
    dateTo?: Date,
  ): Promise<SyncResult> {
    this.logger.log('[SYNC] Starting interaction history sync from Exotel...');

    const from = dateFrom ?? new Date(Date.now() - 7 * 86400000); // default: last 7 days
    const to = dateTo ?? new Date();

    const result: SyncResult = { synced: 0, skipped: 0, errors: 0 };

    try {
      // Exotel call details API
      const fromStr = from.toISOString().split('T')[0];
      const toStr = to.toISOString().split('T')[0];
      const url = `https://api.exotel.com/v2/accounts/${this.accountSid}/call-details?from_date=${fromStr}&to_date=${toStr}&page_size=100`;

      const data = await this.exotelFetch(url);
      const interactions = data?.data ?? data?.calls ?? data?.CallDetails ?? [];

      if (!Array.isArray(interactions)) {
        this.logger.warn('[SYNC] Unexpected interaction response format');
        return result;
      }

      for (const item of interactions) {
        try {
          const interactionId =
            item.interaction_id ??
            item.id ??
            item.Sid ??
            item.CallSid ??
            `exotel-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

          // Check if already synced
          const existing = await this.prisma.exotelInteraction.findUnique({
            where: { interaction_id: String(interactionId) },
          });

          if (existing) {
            result.skipped++;
            continue;
          }

          // Extract fields from various Exotel API shapes
          const callSid = item.call_sid ?? item.CallSid ?? item.Sid ?? null;
          const customerNumber =
            item.customer_number ?? item.From ?? item.CallFrom ?? item.from ?? null;
          const botId = item.bot_id ?? item.BotId ?? null;
          const botName = item.bot_name ?? item.BotName ?? null;
          const botVersion = item.bot_version ?? item.Version ?? null;
          const audioUrl = this.extractAudioUrl(item);
          const transcriptJson = this.extractTranscriptJson(item);
          const transcriptText = this.flattenTranscript(transcriptJson ?? item);
          const status = item.status ?? item.Status ?? item.call_status ?? null;
          const startedAt = item.started_at ?? item.StartTime ?? item.start_time ?? null;
          const endedAt = item.ended_at ?? item.EndTime ?? item.end_time ?? null;
          const duration = item.duration ?? item.Duration ?? item.duration_seconds ?? null;

          await this.prisma.exotelInteraction.create({
            data: {
              interaction_id: String(interactionId),
              bot_id: botId ? String(botId) : null,
              call_sid: callSid ? String(callSid) : null,
              customer_number: customerNumber ? String(customerNumber) : null,
              bot_name: botName ? String(botName) : null,
              bot_version: botVersion ? String(botVersion) : null,
              started_at: startedAt ? new Date(startedAt) : null,
              ended_at: endedAt ? new Date(endedAt) : null,
              duration_seconds: duration != null ? Number(duration) || null : null,
              audio_url: audioUrl,
              transcript_json: transcriptJson,
              transcript_text: transcriptText || null,
              status: status ? String(status) : null,
              metadata: item,
            },
          });

          result.synced++;
        } catch (itemErr) {
          this.logger.error(`[SYNC] Failed to sync interaction: ${(itemErr as Error).message}`);
          result.errors++;
        }
      }

      this.logger.log(
        `[SYNC] ✅ Interactions synced=${result.synced}, skipped=${result.skipped}, errors=${result.errors}`,
      );
      return result;
    } catch (err) {
      this.logger.error(`[SYNC] Interaction sync failed: ${(err as Error).message}`);
      throw err;
    }
  }

  // ── Single Interaction Detail ────────────────────────────────────────────

  async getInteractionDetail(interactionId: string) {
    return this.prisma.exotelInteraction.findUnique({
      where: { interaction_id: interactionId },
    });
  }

  // ── Audio Proxy for Exotel Interactions ──────────────────────────────────

  async getAudioForInteraction(interactionId: string): Promise<{
    buffer: Buffer;
    contentType: string;
  }> {
    const interaction = await this.prisma.exotelInteraction.findUnique({
      where: { interaction_id: interactionId },
      select: { audio_url: true },
    });

    if (!interaction?.audio_url) {
      throw new Error(`Interaction ${interactionId} not found or has no audio`);
    }

    const headers: Record<string, string> = {};
    if (interaction.audio_url.includes('exotel') && this.isConfigured) {
      headers['Authorization'] = this.authHeader;
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), EXOTEL_TIMEOUT_MS);

    try {
      const response = await fetch(interaction.audio_url, {
        headers,
        signal: controller.signal,
      });

      if (!response.ok) {
        throw new Error(`Audio fetch failed: HTTP ${response.status}`);
      }

      const arrayBuffer = await response.arrayBuffer();
      let contentType = response.headers.get('content-type') || 'audio/mpeg';
      if (interaction.audio_url.endsWith('.wav')) contentType = 'audio/wav';

      return { buffer: Buffer.from(arrayBuffer), contentType };
    } finally {
      clearTimeout(timeout);
    }
  }

  // ── Dashboard Stats ──────────────────────────────────────────────────────

  async getDashboardStats() {
    const [totalInteractions, totalPhones, activeBots, activeAssignments, recentInteractions] =
      await Promise.all([
        this.prisma.exotelInteraction.count(),
        this.prisma.exotelPhoneNumber.count({ where: { is_active: true } }),
        this.prisma.exotelBot.count({ where: { is_active: true } }),
        this.prisma.exotelBotAssignment.count({ where: { is_active: true } }),
        this.prisma.exotelInteraction.count({
          where: { started_at: { gte: new Date(Date.now() - 30 * 86400000) } },
        }),
      ]);

    return {
      total_interactions: totalInteractions,
      interactions_last_30_days: recentInteractions,
      active_phone_numbers: totalPhones,
      active_bots: activeBots,
      active_assignments: activeAssignments,
    };
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  /** Recursively search for a recording URL in the payload. */
  private extractAudioUrl(obj: any): string | null {
    if (!obj) return null;
    if (typeof obj === 'string') {
      if (
        obj.includes('recordings.exotel.com') ||
        (obj.startsWith('http') && (obj.endsWith('.mp3') || obj.endsWith('.wav')))
      ) {
        return obj;
      }
      return null;
    }
    if (typeof obj === 'object') {
      for (const key of Object.keys(obj)) {
        if (
          key.toLowerCase().includes('recording') ||
          key.toLowerCase().includes('audio') ||
          key.toLowerCase() === 'media_url'
        ) {
          if (typeof obj[key] === 'string' && obj[key].startsWith('http')) {
            return obj[key];
          }
        }
        const nested = this.extractAudioUrl(obj[key]);
        if (nested) return nested;
      }
    }
    return null;
  }

  /** Extract transcript JSON from various Exotel payload shapes. */
  private extractTranscriptJson(obj: any): any | null {
    const keys = [
      'conversation_transcript',
      'transcript',
      'transcripts',
      'messages',
      'conversation',
      'dialogue',
    ];
    for (const key of keys) {
      if (obj[key] && (Array.isArray(obj[key]) || typeof obj[key] === 'object')) {
        return obj[key];
      }
    }
    // Check nested data/session
    if (obj.data) {
      for (const key of keys) {
        if (obj.data[key]) return obj.data[key];
      }
    }
    return null;
  }

  /** Flatten transcript data into a human-readable string. */
  private flattenTranscript(obj: any): string {
    if (!obj) return '';
    if (typeof obj === 'string') return obj;
    if (Array.isArray(obj)) {
      return obj
        .map((item: any) => {
          if (typeof item === 'string') return item;
          const speaker = item.role || item.speaker || item.sender || 'Unknown';
          const text = item.content || item.message || item.text || '';
          return `${speaker}: ${text}`;
        })
        .join('\n');
    }
    return '';
  }
}
