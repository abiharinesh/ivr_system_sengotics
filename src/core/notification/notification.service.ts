import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface SendNotificationDto {
  tenantId: string;
  recipientUserId?: number;
  recipientPhone?: string;
  recipientEmail?: string;
  templateCode: string;
  channel: 'whatsapp' | 'sms' | 'email' | 'push' | 'in_app';
  variables?: Record<string, string>;
  scheduledFor?: Date;
}

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Queue a notification for asynchronous delivery.
   */
  async queue(dto: SendNotificationDto): Promise<void> {
    try {
      await this.prisma.notification.create({
        data: {
          tenant_id: dto.tenantId,
          recipient_user_id: dto.recipientUserId ?? null,
          recipient_phone: dto.recipientPhone ?? null,
          recipient_email: dto.recipientEmail ?? null,
          template_code: dto.templateCode,
          channel: dto.channel,
          variables: dto.variables as any,
          status: 'queued',
          retry_count: 0,
          max_retries: 3,
          scheduled_for: dto.scheduledFor ?? null,
        },
      });
      this.logger.log(`Queued notification for template ${dto.templateCode} via ${dto.channel}`);
    } catch (err) {
      this.logger.error(`Failed to queue notification: ${err.message}`, err.stack);
    }
  }

  /**
   * Process queued notifications (called by background job scheduler).
   */
  async processQueue(): Promise<void> {
    const pending = await this.prisma.notification.findMany({
      where: {
        status: 'queued',
        OR: [
          { scheduled_for: null },
          { scheduled_for: { lte: new Date() } },
        ],
      },
      take: 50,
    });

    for (const notif of pending) {
      try {
        await this.send(notif.id);
      } catch (err) {
        this.logger.error(`Error processing notification ${notif.id}: ${err.message}`);
      }
    }
  }

  private async send(notifId: bigint): Promise<void> {
    const notif = await this.prisma.notification.findUnique({
      where: { id: notifId },
    });

    if (!notif) return;

    // Fetch the template
    const template = await this.prisma.notificationTemplate.findFirst({
      where: {
        tenant_id: notif.tenant_id,
        code: notif.template_code,
        channel: notif.channel,
        is_active: true,
      },
    });

    if (!template) {
      await this.prisma.notification.update({
        where: { id: notifId },
        data: {
          status: 'failed',
          error_message: `Template ${notif.template_code} not found for channel ${notif.channel}`,
        },
      });
      return;
    }

    // Render body using variables
    let rendered = template.body_template;
    if (notif.variables) {
      const vars = notif.variables as Record<string, string>;
      for (const [key, val] of Object.entries(vars)) {
        rendered = rendered.replace(new RegExp(`{{${key}}}`, 'g'), val);
      }
    }

    // Mock sending for channels (WhatsApp, SMS, etc. are mocked or integration configs used)
    this.logger.log(`[Notification Engine] Sending ${notif.channel} to ${notif.recipient_phone || notif.recipient_email}: ${rendered}`);

    // Update status to sent
    await this.prisma.notification.update({
      where: { id: notifId },
      data: {
        status: 'sent',
        rendered_body: rendered,
        sent_at: new Date(),
      },
    });
  }
}
