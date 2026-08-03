import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Cron, CronExpression } from '@nestjs/schedule';

@Injectable()
export class PropertyTaxService {
  private readonly logger = new Logger(PropertyTaxService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── Property CRUD ──────────────────────────────────────────────────────────

  async listProperties(orgUnitId: number) {
    return this.prisma.taxProperty.findMany({
      where: { org_unit_id: orgUnitId },
      include: {
        tax_payments: { orderBy: { financial_year: 'desc' }, take: 3 },
      },
      orderBy: { door_number: 'asc' },
    });
  }

  async getPropertyById(id: number) {
    const property = await this.prisma.taxProperty.findUnique({
      where: { id },
      include: { tax_payments: { orderBy: { financial_year: 'desc' } } },
    });
    if (!property) throw new NotFoundException(`Property #${id} not found`);
    return property;
  }

  async createProperty(data: {
    org_unit_id: number;
    owner_name: string;
    owner_phone?: string;
    door_number?: string;
    address?: string;
    property_type?: string;
    area_sqft: number;
    latitude?: number;
    longitude?: number;
    annual_tax: number;
  }) {
    return this.prisma.taxProperty.create({ data });
  }

  async updateProperty(id: number, data: Partial<{
    owner_name: string;
    owner_phone: string;
    address: string;
    property_type: string;
    area_sqft: number;
    annual_tax: number;
    status: string;
  }>) {
    const property = await this.prisma.taxProperty.findUnique({ where: { id } });
    if (!property) throw new NotFoundException(`Property #${id} not found`);

    return this.prisma.taxProperty.update({
      where: { id },
      data: {
        ...(data.owner_name !== undefined && { owner_name: data.owner_name }),
        ...(data.owner_phone !== undefined && { owner_phone: data.owner_phone }),
        ...(data.address !== undefined && { address: data.address }),
        ...(data.property_type !== undefined && { property_type: data.property_type }),
        ...(data.area_sqft !== undefined && { area_sqft: data.area_sqft }),
        ...(data.annual_tax !== undefined && { annual_tax: data.annual_tax }),
        ...(data.status !== undefined && { status: data.status }),
      },
    });
  }

  // ─── Tax Demand Generation ──────────────────────────────────────────────────

  /** Generate tax demands for all active properties in a panchayat for a given year. */
  async generateTaxDemands(orgUnitId: number, financialYear: string, dueDate: string) {
    const properties = await this.prisma.taxProperty.findMany({
      where: { org_unit_id: orgUnitId, status: 'active' },
    });

    const dueDateObj = new Date(dueDate);
    let created = 0;
    let skipped = 0;

    for (const property of properties) {
      // Check if demand already exists
      const existing = await this.prisma.taxPayment.findFirst({
        where: { property_id: property.id, financial_year: financialYear },
      });

      if (existing) {
        skipped++;
        continue;
      }

      await this.prisma.taxPayment.create({
        data: {
          property_id: property.id,
          financial_year: financialYear,
          demand_amount: property.annual_tax,
          due_date: dueDateObj,
          status: 'unpaid',
        },
      });
      created++;
    }

    this.logger.log(`Tax demands generated: ${created} created, ${skipped} skipped (already exist)`);
    return { created, skipped, total_properties: properties.length };
  }

  // ─── Tax Payment Recording ──────────────────────────────────────────────────

  async recordPayment(paymentId: number, data: {
    paid_amount: number;
    payment_method: string;
    transaction_ref?: string;
  }) {
    const payment = await this.prisma.taxPayment.findUnique({ where: { id: paymentId } });
    if (!payment) throw new NotFoundException(`Tax payment #${paymentId} not found`);

    const totalPaid = Number(payment.paid_amount) + data.paid_amount;
    const totalDue = Number(payment.demand_amount) + Number(payment.penalty_amount);
    const newStatus = totalPaid >= totalDue ? 'paid' : 'partial';

    return this.prisma.taxPayment.update({
      where: { id: paymentId },
      data: {
        paid_amount: totalPaid,
        payment_method: data.payment_method,
        transaction_ref: data.transaction_ref,
        paid_at: new Date(),
        status: newStatus,
      },
    });
  }

  // ─── Cron: Auto-apply Late Penalties ────────────────────────────────────────

  /** Runs daily at midnight. Applies 10% surcharge on overdue tax payments. */
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async applyLatePenalties() {
    this.logger.log('⏰ Checking for overdue property tax payments...');

    const overdue = await this.prisma.taxPayment.findMany({
      where: {
        status: 'unpaid',
        due_date: { lt: new Date() },
        penalty_amount: { equals: 0 },
      },
    });

    for (const payment of overdue) {
      const penaltyAmount = Number(payment.demand_amount) * 0.10; // 10% surcharge
      await this.prisma.taxPayment.update({
        where: { id: payment.id },
        data: {
          penalty_amount: penaltyAmount,
          status: 'overdue',
        },
      });
    }

    this.logger.log(`✅ Late penalties applied to ${overdue.length} overdue payments.`);
  }

  // ─── Defaulters Report ──────────────────────────────────────────────────────

  async getDefaulters(orgUnitId: number, financialYear?: string) {
    const where: any = {
      status: { in: ['unpaid', 'overdue'] },
      property: { org_unit_id: orgUnitId },
    };
    if (financialYear) where.financial_year = financialYear;

    return this.prisma.taxPayment.findMany({
      where,
      include: {
        property: {
          select: {
            id: true,
            owner_name: true,
            owner_phone: true,
            door_number: true,
            address: true,
          },
        },
      },
      orderBy: { demand_amount: 'desc' },
    });
  }

  // ─── Revenue Summary ───────────────────────────────────────────────────────

  async getRevenueSummary(orgUnitId: number, financialYear?: string) {
    const where: any = { property: { org_unit_id: orgUnitId } };
    if (financialYear) where.financial_year = financialYear;

    const payments = await this.prisma.taxPayment.findMany({ where });

    const totalDemand = payments.reduce((s, p) => s + Number(p.demand_amount), 0);
    const totalPenalty = payments.reduce((s, p) => s + Number(p.penalty_amount), 0);
    const totalCollected = payments.reduce((s, p) => s + Number(p.paid_amount), 0);
    const totalOutstanding = totalDemand + totalPenalty - totalCollected;

    const paid = payments.filter(p => p.status === 'paid').length;
    const unpaid = payments.filter(p => p.status === 'unpaid').length;
    const overdue = payments.filter(p => p.status === 'overdue').length;

    return {
      total_properties: payments.length,
      total_demand: totalDemand.toFixed(2),
      total_penalty: totalPenalty.toFixed(2),
      total_collected: totalCollected.toFixed(2),
      total_outstanding: totalOutstanding.toFixed(2),
      collection_rate: payments.length > 0
        ? `${((paid / payments.length) * 100).toFixed(1)}%`
        : '0%',
      status_breakdown: { paid, unpaid, overdue },
    };
  }
}
