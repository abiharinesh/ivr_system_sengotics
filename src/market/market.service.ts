import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MarketService {
  private readonly logger = new Logger(MarketService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── Market Days ────────────────────────────────────────────────────────────

  async listMarketDays(orgUnitId: number) {
    return this.prisma.marketDay.findMany({
      where: { org_unit_id: orgUnitId },
    });
  }

  async createMarketDay(data: {
    org_unit_id: number;
    name: string;
    location?: string;
    day_of_week: number;
    daily_fee: number;
  }) {
    if (data.day_of_week < 0 || data.day_of_week > 6) {
      throw new BadRequestException('day_of_week must be between 0 (Sunday) and 6 (Saturday)');
    }
    return this.prisma.marketDay.create({ data });
  }

  // ─── Market Vendors ─────────────────────────────────────────────────────────

  async listVendors(orgUnitId: number) {
    return this.prisma.marketVendor.findMany({
      where: { org_unit_id: orgUnitId },
      orderBy: { vendor_name: 'asc' },
    });
  }

  async getVendorByToken(token: string) {
    const vendor = await this.prisma.marketVendor.findUnique({
      where: { vendor_token: token },
      include: {
        org_unit: { select: { id: true, name: true } },
        payments: { orderBy: { paid_at: 'desc' }, take: 10 },
      },
    });
    if (!vendor) throw new NotFoundException('Vendor invalid or not found');
    return vendor;
  }

  async createVendor(data: {
    org_unit_id: number;
    vendor_name: string;
    vendor_phone: string;
    business_type?: string;
    photo_url?: string;
  }) {
    // Check if phone already registered in this panchayat
    const existing = await this.prisma.marketVendor.findFirst({
      where: { org_unit_id: data.org_unit_id, vendor_phone: data.vendor_phone },
    });
    if (existing) {
      throw new BadRequestException('A vendor with this phone number is already registered in this panchayat.');
    }

    return this.prisma.marketVendor.create({
      data: {
        org_unit_id: data.org_unit_id,
        vendor_name: data.vendor_name,
        vendor_phone: data.vendor_phone,
        business_type: data.business_type || null,
        photo_url: data.photo_url || null,
      },
    });
  }

  async updateVendor(id: number, data: Partial<{
    vendor_name: string;
    vendor_phone: string;
    business_type: string;
    photo_url: string;
    is_active: boolean;
  }>) {
    const vendor = await this.prisma.marketVendor.findUnique({ where: { id } });
    if (!vendor) throw new NotFoundException(`Vendor #${id} not found`);

    return this.prisma.marketVendor.update({
      where: { id },
      data: {
        ...(data.vendor_name !== undefined && { vendor_name: data.vendor_name }),
        ...(data.vendor_phone !== undefined && { vendor_phone: data.vendor_phone }),
        ...(data.business_type !== undefined && { business_type: data.business_type }),
        ...(data.photo_url !== undefined && { photo_url: data.photo_url }),
        ...(data.is_active !== undefined && { is_active: data.is_active }),
      },
    });
  }

  // ─── Daily Payments ────────────────────────────────────────────────────────

  async recordFeePayment(data: {
    vendor_id: number;
    market_day_id: number;
    amount_paid: number;
    payment_method?: string;
    collected_by?: string;
  }) {
    const vendor = await this.prisma.marketVendor.findUnique({ where: { id: data.vendor_id } });
    if (!vendor) throw new NotFoundException(`Vendor #${data.vendor_id} not found`);

    const marketDay = await this.prisma.marketDay.findUnique({ where: { id: data.market_day_id } });
    if (!marketDay) throw new NotFoundException(`Market Day #${data.market_day_id} not found`);

    // Prevent duplicate payment on the same calendar day for this vendor/market-day combo
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const alreadyPaid = await this.prisma.marketVendorPayment.findFirst({
      where: {
        vendor_id: data.vendor_id,
        market_day_id: data.market_day_id,
        paid_at: { gte: today },
      },
    });

    if (alreadyPaid) {
      throw new BadRequestException('Daily fee has already been collected/recorded for this vendor today.');
    }

    return this.prisma.marketVendorPayment.create({
      data: {
        vendor_id: data.vendor_id,
        market_day_id: data.market_day_id,
        amount_paid: data.amount_paid,
        payment_method: data.payment_method || 'cash',
        collected_by: data.collected_by || null,
      },
    });
  }

  async getPaymentsByPanchayat(orgUnitId: number) {
    return this.prisma.marketVendorPayment.findMany({
      where: { vendor: { org_unit_id: orgUnitId } },
      include: {
        vendor: { select: { vendor_name: true, vendor_phone: true } },
        market_day: { select: { name: true } },
      },
      orderBy: { paid_at: 'desc' },
    });
  }
}
