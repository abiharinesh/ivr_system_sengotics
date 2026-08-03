import { Controller, Get, Param } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { TradeLicenceService } from './trade-licence.service';

/**
 * Public licence verification — the target of the QR printed on the licence
 * displayed in the shop.
 *
 * Unauthenticated by design: a customer, or an inspector from another
 * department, has no account here. The service returns a redacted projection
 * and distinguishes "this document is not genuine" from "this shop's licence
 * has lapsed", because those are very different findings.
 */
@Controller('public/trade-licences')
export class TradeLicencePublicController {
  constructor(private readonly service: TradeLicenceService) {}

  @Get(':token')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  verify(@Param('token') token: string) {
    return this.service.verifyByToken(token);
  }
}
