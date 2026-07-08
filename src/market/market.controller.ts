import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { MarketService } from './market.service';

@Controller('markets')
export class MarketController {
  constructor(private readonly marketService: MarketService) {}

  // ─── Market Days ────────────────────────────────────────────────────────────

  /** GET /markets/days?panchayat_id=1 */
  @Get('days')
  async listMarketDays(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.marketService.listMarketDays(panchayatId);
  }

  /** POST /markets/days */
  @Post('days')
  async createMarketDay(@Body() body: {
    panchayat_id: number;
    name: string;
    location?: string;
    day_of_week: number;
    daily_fee: number;
  }) {
    return this.marketService.createMarketDay(body);
  }

  // ─── Vendors ───────────────────────────────────────────────────────────────

  /** GET /markets/vendors?panchayat_id=1 */
  @Get('vendors')
  async listVendors(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.marketService.listVendors(panchayatId);
  }

  /** GET /markets/vendors/qr/:token */
  @Get('vendors/qr/:token')
  async getVendorByToken(@Param('token') token: string) {
    return this.marketService.getVendorByToken(token);
  }

  /** POST /markets/vendors */
  @Post('vendors')
  async createVendor(@Body() body: {
    panchayat_id: number;
    vendor_name: string;
    vendor_phone: string;
    business_type?: string;
    photo_url?: string;
  }) {
    return this.marketService.createVendor(body);
  }

  /** PUT /markets/vendors/:id */
  @Put('vendors/:id')
  async updateVendor(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: Partial<{
      vendor_name: string;
      vendor_phone: string;
      business_type: string;
      photo_url: string;
      is_active: boolean;
    }>,
  ) {
    return this.marketService.updateVendor(id, body);
  }

  // ─── Payments ───────────────────────────────────────────────────────────────

  /** POST /markets/payments/pay */
  @Post('payments/pay')
  async recordPayment(@Body() body: {
    vendor_id: number;
    market_day_id: number;
    amount_paid: number;
    payment_method?: string;
    collected_by?: string;
  }) {
    return this.marketService.recordFeePayment(body);
  }

  /** GET /markets/payments?panchayat_id=1 */
  @Get('payments')
  async getPayments(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.marketService.getPaymentsByPanchayat(panchayatId);
  }
}
