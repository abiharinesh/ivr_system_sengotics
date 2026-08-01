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
import { AssetBookingService } from './asset-booking.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin', 'revenue_officer', 'revenue_inspector')
@Controller('asset-bookings')
export class AssetBookingController {
  constructor(private readonly assetBookingService: AssetBookingService) {}

  // ─── Assets ────────────────────────────────────────────────────────────────

  /** GET /asset-bookings/assets?org_unit_id=1 */
  @Get('assets')
  async listAssets(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.assetBookingService.listAssets(orgUnitId);
  }

  /** GET /asset-bookings/assets/:id */
  @Get('assets/:id')
  async getAsset(@Param('id', ParseIntPipe) id: number) {
    return this.assetBookingService.getAssetById(id);
  }

  /** POST /asset-bookings/assets */
  @Post('assets')
  async createAsset(@Body() body: {
    org_unit_id: number;
    name: string;
    facility_type: string;
    description?: string;
    daily_rate: number;
    hourly_rate?: number;
    deposit_amount?: number;
    max_capacity?: number;
    image_url?: string;
  }) {
    return this.assetBookingService.createAsset(body);
  }

  /** PUT /asset-bookings/assets/:id */
  @Put('assets/:id')
  async updateAsset(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: Partial<{
      name: string;
      description: string;
      daily_rate: number;
      hourly_rate: number;
      deposit_amount: number;
      max_capacity: number;
      image_url: string;
      is_available: boolean;
    }>,
  ) {
    return this.assetBookingService.updateAsset(id, body);
  }

  // ─── Bookings ──────────────────────────────────────────────────────────────

  /** GET /asset-bookings/check-availability?facility_id=1&start_date=...&end_date=... */
  @Get('check-availability')
  async checkAvailability(
    @Query('facility_id', ParseIntPipe) assetId: number,
    @Query('start_date') startDate: string,
    @Query('end_date') endDate: string,
  ) {
    const isAvailable = await this.assetBookingService.checkAvailability(assetId, startDate, endDate);
    return { available: isAvailable };
  }

  /** POST /asset-bookings/reserve */
  @Post('reserve')
  async reserve(@Body() body: {
    facility_id: number;
    booked_by_name: string;
    booked_by_phone: string;
    event_type?: string;
    start_date: string;
    end_date: string;
    deposit_paid?: number;
  }) {
    return this.assetBookingService.createBooking(body);
  }

  /** POST /asset-bookings/:id/confirm */
  @Post(':id/confirm')
  async confirm(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { payment_ref: string },
  ) {
    return this.assetBookingService.confirmBooking(id, body.payment_ref);
  }

  /** POST /asset-bookings/:id/pay-balance */
  @Post(':id/pay-balance')
  async payBalance(@Param('id', ParseIntPipe) id: number) {
    return this.assetBookingService.recordBalancePayment(id);
  }

  /** POST /asset-bookings/:id/cancel */
  @Post(':id/cancel')
  async cancel(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { cancellation_fee: number },
  ) {
    return this.assetBookingService.cancelBooking(id, body.cancellation_fee);
  }

  /** GET /asset-bookings/list?org_unit_id=1 */
  @Get('list')
  async listBookings(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.assetBookingService.getBookingsByPanchayat(orgUnitId);
  }
}
