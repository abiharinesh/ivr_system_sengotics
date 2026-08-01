import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AssetBookingService {
  private readonly logger = new Logger(AssetBookingService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── Asset CRUD ─────────────────────────────────────────────────────────────

  async listAssets(orgUnitId: number) {
    return this.prisma.bookableFacility.findMany({
      where: { org_unit_id: orgUnitId },
      orderBy: { name: 'asc' },
    });
  }

  async getAssetById(id: number) {
    const asset = await this.prisma.bookableFacility.findUnique({
      where: { id },
      include: { bookings: { orderBy: { start_date: 'desc' } } },
    });
    if (!asset) throw new NotFoundException(`Asset #${id} not found`);
    return asset;
  }

  async createAsset(data: {
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
    return this.prisma.bookableFacility.create({
      data: {
        org_unit_id: data.org_unit_id,
        name: data.name,
        facility_type: data.facility_type,
        description: data.description || null,
        daily_rate: data.daily_rate,
        hourly_rate: data.hourly_rate || null,
        deposit_amount: data.deposit_amount || 0,
        max_capacity: data.max_capacity || null,
        image_url: data.image_url || null,
      },
    });
  }

  async updateAsset(id: number, data: Partial<{
    name: string;
    description: string;
    daily_rate: number;
    hourly_rate: number;
    deposit_amount: number;
    max_capacity: number;
    image_url: string;
    is_available: boolean;
  }>) {
    const asset = await this.prisma.bookableFacility.findUnique({ where: { id } });
    if (!asset) throw new NotFoundException(`Asset #${id} not found`);

    return this.prisma.bookableFacility.update({
      where: { id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.description !== undefined && { description: data.description }),
        ...(data.daily_rate !== undefined && { daily_rate: data.daily_rate }),
        ...(data.hourly_rate !== undefined && { hourly_rate: data.hourly_rate }),
        ...(data.deposit_amount !== undefined && { deposit_amount: data.deposit_amount }),
        ...(data.max_capacity !== undefined && { max_capacity: data.max_capacity }),
        ...(data.image_url !== undefined && { image_url: data.image_url }),
        ...(data.is_available !== undefined && { is_available: data.is_available }),
      },
    });
  }

  // ─── Booking Actions ────────────────────────────────────────────────────────

  async checkAvailability(assetId: number, startDate: string, endDate: string): Promise<boolean> {
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start >= end) {
      throw new BadRequestException('Start date must be before end date');
    }

    const conflictingBookings = await this.prisma.facilityBooking.findMany({
      where: {
        facility_id: assetId,
        booking_status: { in: ['pending', 'confirmed'] },
        OR: [
          { start_date: { lte: start }, end_date: { gt: start } },
          { start_date: { lt: end }, end_date: { gte: end } },
          { start_date: { gte: start }, end_date: { lte: end } },
        ],
      },
    });

    return conflictingBookings.length === 0;
  }

  async createBooking(data: {
    facility_id: number;
    booked_by_name: string;
    booked_by_phone: string;
    event_type?: string;
    start_date: string;
    end_date: string;
    deposit_paid?: number;
  }) {
    const isAvailable = await this.checkAvailability(data.facility_id, data.start_date, data.end_date);
    if (!isAvailable) {
      throw new BadRequestException('Asset is already booked or unavailable during this period.');
    }

    const asset = await this.getAssetById(data.facility_id);
    const start = new Date(data.start_date);
    const end = new Date(data.end_date);

    const diffTime = Math.abs(end.getTime() - start.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    const totalAmount = Number(asset.daily_rate) * diffDays;
    const deposit = data.deposit_paid || Number(asset.deposit_amount);

    return this.prisma.facilityBooking.create({
      data: {
        facility_id: data.facility_id,
        booked_by_name: data.booked_by_name,
        booked_by_phone: data.booked_by_phone,
        event_type: data.event_type || null,
        start_date: start,
        end_date: end,
        total_amount: totalAmount,
        deposit_paid: deposit,
        balance_amount: totalAmount - deposit,
        booking_status: 'pending',
      },
    });
  }

  async confirmBooking(bookingId: number, paymentRef: string) {
    const booking = await this.prisma.facilityBooking.findUnique({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException(`Booking #${bookingId} not found`);

    return this.prisma.facilityBooking.update({
      where: { id: bookingId },
      data: {
        booking_status: 'confirmed',
        payment_ref: paymentRef,
      },
    });
  }

  async recordBalancePayment(bookingId: number) {
    const booking = await this.prisma.facilityBooking.findUnique({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException(`Booking #${bookingId} not found`);

    return this.prisma.facilityBooking.update({
      where: { id: bookingId },
      data: {
        booking_status: 'completed',
        balance_amount: 0,
      },
    });
  }

  async cancelBooking(bookingId: number, cancellationFee: number) {
    const booking = await this.prisma.facilityBooking.findUnique({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException(`Booking #${bookingId} not found`);

    return this.prisma.facilityBooking.update({
      where: { id: bookingId },
      data: {
        booking_status: 'cancelled',
        cancelled_at: new Date(),
        cancellation_fee: cancellationFee,
      },
    });
  }

  async getBookingsByPanchayat(orgUnitId: number) {
    return this.prisma.facilityBooking.findMany({
      where: { facility: { org_unit_id: orgUnitId } },
      include: { facility: { select: { name: true, facility_type: true } } },
      orderBy: { start_date: 'desc' },
    });
  }
}
