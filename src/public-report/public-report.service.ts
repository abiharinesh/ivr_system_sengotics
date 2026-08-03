import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { randomUUID } from 'crypto';
import { AdCampaignService } from '../ad-campaign/ad-campaign.service';

@Injectable()
export class PublicReportService {
  private readonly logger = new Logger(PublicReportService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly adCampaignService: AdCampaignService,
  ) {}

  // ─── QR / Public Pole Lookup ────────────────────────────────────────────────

  /** Fetch non-sensitive pole info by its permanent QR token, including active ads. */
  async getPoleByToken(token: string) {
    const pole = await this.prisma.electricPole.findUnique({
      where: { public_report_token: token },
      select: {
        id: true,
        pole_number: true,
        keypad_id: true,
        latitude: true,
        longitude: true,
        landmarks: true,
        public_report_token: true,
        org_unit_id: true,
        org_unit: { select: { id: true, name: true } },
      },
    });
    if (!pole) throw new NotFoundException('Pole not found or invalid QR code');

    let activeAd: any = null;
    if (pole.org_unit_id) {
      try {
        activeAd = await this.adCampaignService.getActiveAdForPole(pole.id, pole.org_unit_id);
        if (activeAd) {
          // Record impression asynchronously (fire-and-forget/non-blocking)
          this.adCampaignService.recordImpression(activeAd.id, pole.id).catch(err => {
            this.logger.error(`Error recording ad impression: ${err.message}`);
          });
        }
      } catch (err) {
        // Log error but do not fail the request
        this.logger.error(`Error loading ad for pole: ${(err as Error).message}`);
      }
    }

    return {
      ...pole,
      active_ad: activeAd ? {
        id: activeAd.id,
        title: activeAd.title,
        description: activeAd.description,
        image_url: activeAd.image_url,
        link_url: activeAd.link_url,
      } : null,
    };
  }

  // ─── Guest Complaint (zero-auth) ───────────────────────────────────────────

  /** Create a complaint from an anonymous/guest citizen via QR scan page. */
  async createGuestComplaint(
    token: string,
    data: {
      complaint_type?: string;
      description?: string;
      urgency_level?: string;
      guest_phone?: string;
    },
  ) {
    const pole = await this.prisma.electricPole.findUnique({
      where: { public_report_token: token },
      select: { id: true, org_unit_id: true },
    });
    if (!pole) throw new NotFoundException('Invalid pole token');
    if (!pole.org_unit_id) {
      throw new BadRequestException('Pole is not assigned to a panchayat');
    }

    const trackingToken = randomUUID();

    const complaint = await this.prisma.complaint.create({
      data: {
        pole_id: pole.id,
        org_unit_id: pole.org_unit_id,
        complaint_type: data.complaint_type?.trim() || 'citizen_reported',
        description: data.description?.trim() || null,
        urgency_level: data.urgency_level?.trim() || 'medium',
        status: 'pending',
        guest_phone: data.guest_phone?.trim() || null,
        guest_tracking_token: trackingToken,
      },
      include: { pole: true },
    });

    const webBase =
      process.env.WEB_APP_BASE_URL ??
      'https://ivr-system-sengotics.vercel.app';
    const trackingUrl = `${webBase}/public/track/${trackingToken}`;

    return {
      complaint_id: complaint.id,
      tracking_token: trackingToken,
      tracking_url: trackingUrl,
      status: complaint.status,
    };
  }

  // ─── Complaint Tracking (public, by token) ─────────────────────────────────

  /** Public read-only complaint status lookup by guest tracking token. */
  async trackComplaint(trackingToken: string) {
    const complaint = await this.prisma.complaint.findUnique({
      where: { guest_tracking_token: trackingToken },
      select: {
        id: true,
        complaint_type: true,
        description: true,
        urgency_level: true,
        status: true,
        created_at: true,
        assigned_at: true,
        resolved_at: true,
        pole: {
          select: {
            pole_number: true,
            landmarks: true,
          },
        },
        org_unit: {
          select: { name: true },
        },
      },
    });
    if (!complaint) throw new NotFoundException('Tracking link not found');
    return complaint;
  }

  // ─── GPS-Based Panchayat Auto-Detection ────────────────────────────────────

  /** Spatial lookup: find which panchayat contains the given GPS coordinate. */
  async findPanchayatByCoords(lat: number, lng: number) {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw new BadRequestException('Invalid coordinates');
    }

    const result = await this.prisma.$queryRawUnsafe<
      { id: number; name: string }[]
    >(
      `SELECT id, name FROM panchayats
       WHERE boundary IS NOT NULL
         AND ST_Contains(boundary, ST_SetSRID(ST_Point($1, $2), 4326))
       LIMIT 1`,
      lng,
      lat,
    );

    if (!result || result.length === 0) {
      // Fallback: find nearest panchayat by center_lat/center_lng
      const nearest = await this.prisma.orgUnit.findFirst({
        where: {
          center_lat: { not: null },
          center_lng: { not: null },
        },
        orderBy: [{ id: 'asc' }], // Simple fallback; true distance requires raw SQL
        select: { id: true, name: true },
      });
      return nearest ? { ...nearest, method: 'nearest_fallback' } : null;
    }

    return { ...result[0], method: 'spatial_contains' };
  }

  // ─── IVR Identity Sync ─────────────────────────────────────────────────────

  /**
   * IVR sync entry-point for authenticated citizens.
   * Looks up the user's phone, then delegates to syncIvrHistory.
   */
  async syncIvrHistoryForUser(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phone_e164: true },
    });
    if (!user?.phone_e164) {
      return {
        phone: null,
        total_calls: 0,
        calls: [],
        voice_transcripts: [],
        message: 'No phone number linked to your account.',
      };
    }
    return this.syncIvrHistory(user.phone_e164);
  }

  /**
   * Given a registered citizen's phone number, find all IVR voice calls
   * and linked complaints that match their caller ID.
   */
  async syncIvrHistory(phoneE164: string) {
    if (!phoneE164 || !phoneE164.startsWith('+')) {
      throw new BadRequestException('Phone number must be in E.164 format');
    }

    // Find IVR master records by caller number
    const calls = await this.prisma.ivrCall.findMany({
      where: { caller_number: phoneE164 },
      orderBy: { created_at: 'desc' },
      take: 50,
      select: {
        call_sid: true,
        caller_number: true,
        call_start_time: true,
        call_end_time: true,
        final_call_status: true,
        service_selected: true,
      },
    });

    // Find voice call transcripts matched by call_sid
    const callSids = calls.map((c) => c.call_sid);
    const voiceCalls = await this.prisma.voiceCall.findMany({
      where: { call_sid: { in: callSids } },
      orderBy: { created_at: 'desc' },
      select: {
        id: true,
        call_sid: true,
        transcript: true,
        transcript_english: true,
        processing_status: true,
        created_at: true,
        complaints: {
          select: {
            id: true,
            status: true,
            complaint_type: true,
            description: true,
            created_at: true,
          },
        },
      },
    });

    return {
      phone: phoneE164,
      total_calls: calls.length,
      calls,
      voice_transcripts: voiceCalls,
    };
  }

  // ─── QR Code Generation ────────────────────────────────────────────────────

  /** Generate the URL that goes into a QR code for a given pole. */
  async getQrUrl(poleId: number) {
    const pole = await this.prisma.electricPole.findUnique({
      where: { id: poleId },
      select: { public_report_token: true, pole_number: true },
    });
    if (!pole || !pole.public_report_token) {
      throw new NotFoundException('Pole not found or has no public token');
    }
    const webBase =
      process.env.WEB_APP_BASE_URL ??
      'https://ivr-system-sengotics.vercel.app';
    return {
      pole_number: pole.pole_number,
      url: `${webBase}/public/report/${pole.public_report_token}`,
      token: pole.public_report_token,
    };
  }
}
