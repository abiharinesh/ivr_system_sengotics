import { Controller, Get, Param } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { VitalEventsService } from './vital-events.service';

/**
 * Public certificate verification — the endpoint the printed QR code points at.
 *
 * Deliberately unauthenticated. A bank clerk or school admissions officer
 * scanning a birth certificate has no account on this platform, and requiring
 * one would make the QR code decorative. (The older
 * `GET /certificates/verify/:qrToken` sits behind `JwtAuthGuard` and has
 * exactly that problem.)
 *
 * The service returns a redacted projection: enough to confirm the document is
 * genuine, nothing that would turn this into a lookup service for personal
 * data. Rate-limited because the endpoint is open, and tokens are 24 random
 * bytes so enumeration is not a realistic attack anyway.
 */
@Controller('public/vital-certificates')
export class VitalEventsPublicController {
  constructor(private readonly service: VitalEventsService) {}

  @Get(':token')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  verify(@Param('token') token: string) {
    return this.service.verifyByToken(token);
  }
}
