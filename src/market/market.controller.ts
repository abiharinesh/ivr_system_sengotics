import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { MarketService } from './market.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin', 'revenue_officer', 'revenue_inspector')
@Controller('markets')
export class MarketController {
  constructor(private readonly marketService: MarketService) {}

  // ─── Market Days ────────────────────────────────────────────────────────────

  /** GET /markets/days?org_unit_id=1 */
  @Get('days')
  async listMarketDays(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.marketService.listMarketDays(orgUnitId);
  }

  /** POST /markets/days */
  @Post('days')
  async createMarketDay(@Body() body: {
    org_unit_id: number;
    name: string;
    location?: string;
    day_of_week: number;
    daily_fee: number;
  }) {
    return this.marketService.createMarketDay(body);
  }

  // ─── Vendors ───────────────────────────────────────────────────────────────

  /** GET /markets/vendors?org_unit_id=1 */
  @Get('vendors')
  async listVendors(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.marketService.listVendors(orgUnitId);
  }

  /** GET /markets/vendors/qr/:token */
  @Get('vendors/qr/:token')
  async getVendorByToken(@Param('token') token: string) {
    return this.marketService.getVendorByToken(token);
  }

  /** POST /markets/vendors */
  @Post('vendors')
  async createVendor(@Body() body: {
    org_unit_id: number;
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

  /** GET /markets/payments?org_unit_id=1 */
  @Get('payments')
  async getPayments(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.marketService.getPaymentsByPanchayat(orgUnitId);
  }
}
