import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
  Req,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PublicReportService } from './public-report.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    panchayat_id: number | null;
    phone_e164?: string;
  };
}

@Controller('api/public')
export class PublicReportController {
  constructor(private readonly service: PublicReportService) {}

  // ── Zero-Auth QR Scan Endpoints ─────────────────────────────────────────

  /** Public: fetch pole info by QR token. No auth required. */
  @Get('poles/:token')
  @Throttle({ default: { ttl: 60000, limit: 20 } })
  getPoleByToken(@Param('token') token: string) {
    return this.service.getPoleByToken(token);
  }

  /** Public: submit a guest complaint via QR scan page. */
  @Post('poles/:token/complaints')
  @Throttle({ default: { ttl: 60000, limit: 5 } })
  createGuestComplaint(
    @Param('token') token: string,
    @Body()
    body: {
      complaint_type?: string;
      description?: string;
      urgency_level?: string;
      guest_phone?: string;
    },
  ) {
    return this.service.createGuestComplaint(token, body);
  }

  // ── Complaint Tracking (public, by token) ───────────────────────────────

  /** Public: read-only complaint status for guest tracking links. */
  @Get('track/:trackingToken')
  @Throttle({ default: { ttl: 60000, limit: 30 } })
  trackComplaint(@Param('trackingToken') trackingToken: string) {
    return this.service.trackComplaint(trackingToken);
  }

  // ── GPS-Based Panchayat Auto-Detection ──────────────────────────────────

  /** Public: find which panchayat contains the provided GPS coordinates. */
  @Post('panchayat-lookup')
  @Throttle({ default: { ttl: 60000, limit: 10 } })
  findPanchayatByCoords(@Body() body: { lat: number; lng: number }) {
    return this.service.findPanchayatByCoords(body.lat, body.lng);
  }

  // ── IVR Identity Sync (authenticated) ───────────────────────────────────

  /** Citizen: fetch all IVR calls and linked complaints for their phone. */
  @Get('ivr-sync')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('citizen')
  async syncIvrHistory(@Req() req: AuthenticatedRequest) {
    return this.service.syncIvrHistoryForUser(req.user.id);
  }

  // ── QR Code Generation (admin) ──────────────────────────────────────────

  /** Admin: get the QR URL for a specific pole ID. */
  @Get('qr/:poleId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('panchayat_admin', 'super_admin')
  getQrUrl(@Param('poleId') poleId: string) {
    return this.service.getQrUrl(+poleId);
  }
}
