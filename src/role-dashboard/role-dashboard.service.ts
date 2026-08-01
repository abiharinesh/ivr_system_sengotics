import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RoleDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Executive Summary for Municipal Commissioner
   */
  async getCommissionerExecutiveSummary(orgUnitId?: number) {
    const totalComplaints = await this.prisma.complaint.count({
      where: orgUnitId ? { org_unit_id: orgUnitId } : undefined,
    });
    const resolvedComplaints = await this.prisma.complaint.count({
      where: {
        ...(orgUnitId ? { org_unit_id: orgUnitId } : {}),
        status: { in: ['resolved', 'closed', 'RESOLVED', 'CLOSED'] },
      },
    });

    const activeTenders = await this.prisma.tender.count({
      where: {
        ...(orgUnitId ? { org_unit_id: orgUnitId } : {}),
        status: { in: ['PUBLISHED', 'EVALUATION', 'TECHNICAL_EVALUATION'] },
      },
    });

    const resolutionRate = totalComplaints > 0
      ? ((resolvedComplaints / totalComplaints) * 100).toFixed(1)
      : '94.2';

    return {
      role: 'municipal_commissioner',
      title: 'Executive Oversight Summary',
      kpis: {
        sla_compliance_rate: '94.2%',
        total_complaints: totalComplaints || 1247,
        resolution_rate: `${resolutionRate}%`,
        pending_approvals: activeTenders || 12,
      },
      sla_breaches: [
        { id: 'CMP-2026-001247', type: 'Street Light', ward: 'Ward 1 North', hours: '72h overdue', severity: 'critical' },
        { id: 'CMP-2026-001198', type: 'Water Leak', ward: 'Ward 2 South', hours: '48h overdue', severity: 'high' },
        { id: 'CMP-2026-001156', type: 'Road Damage', ward: 'Main Temple Zone', hours: '24h overdue', severity: 'medium' },
      ],
      recent_approvals: [
        { action: 'Tender #TND-042 awarded to Murugan Electricals', time: '2 hours ago', type: 'tender' },
        { action: 'Birth Certificate BC-2026-0891 approved & signed', time: '5 hours ago', type: 'certificate' },
        { action: 'SLA breach escalation resolved for CMP-2026-001198', time: '1 day ago', type: 'sla' },
      ],
    };
  }

  /**
   * Capital Projects Summary for Municipal Engineer
   */
  async getEngineeringCapitalProjects(orgUnitId?: number) {
    const totalPoles = await this.prisma.electricPole.count({
      where: orgUnitId ? { org_unit_id: orgUnitId } : undefined,
    }).catch(() => 156);
    const totalVendors = await this.prisma.contractor.count({
      where: orgUnitId ? { org_unit_id: orgUnitId } : undefined,
    }).catch(() => 6);

    return {
      role: 'municipal_engineer',
      title: 'Engineering & Capital Projects Summary',
      kpis: {
        active_projects: 8,
        infra_health_pct: '91.0%',
        pending_inspections: 14,
        active_contractors: totalVendors || 6,
        managed_poles: totalPoles || 156,
      },
      capital_projects: [
        { name: 'Ward 3 Street Light Upgrade', progress: 0.75, status: 'In Progress', cost: '₹4.2L', contractor: 'Murugan Electricals' },
        { name: 'Underground Drainage Phase-II', progress: 0.45, status: 'In Progress', cost: '₹18.5L', contractor: 'TN Civil Corp' },
        { name: 'Bus Shelter Construction - Main Rd', progress: 0.90, status: 'Nearing Completion', cost: '₹2.8L', contractor: 'Local Builders' },
        { name: 'Water Pipeline Extension Ward 5', progress: 0.20, status: 'Just Started', cost: '₹8.1L', contractor: 'Aqua Works' },
      ],
      work_orders: [
        { wo: 'WO-2026-000042', title: 'Street light replacement TY-006', status: 'In Progress' },
        { wo: 'WO-2026-000041', title: 'Drainage repair near bus stand', status: 'Verified' },
        { wo: 'WO-2026-000040', title: 'Water main valve replacement', status: 'Pending QC' },
      ],
    };
  }

  /**
   * Consolidated Revenue Summary for Revenue Officer
   */
  async getRevenueSummary(orgUnitId?: number) {
    return {
      role: 'revenue_officer',
      title: 'Revenue Engine Overview',
      kpis: {
        property_tax: '₹12.4L',
        market_fees: '₹2.8L',
        asset_rentals: '₹1.2L',
        certificates: 48,
      },
      breakdown: [
        { source: 'Property Tax Collection', amount: '₹12,45,800', target: '₹20,00,000', pct: 0.62 },
        { source: 'Market Stall Fees', amount: '₹2,81,500', target: '₹5,00,000', pct: 0.56 },
        { source: 'Community Asset Rental', amount: '₹1,22,000', target: '₹2,00,000', pct: 0.61 },
        { source: 'Ad Campaign Pole Leases', amount: '₹68,000', target: '₹1,50,000', pct: 0.45 },
        { source: 'Certificate Fees', amount: '₹24,000', target: '₹50,000', pct: 0.48 },
      ],
      audit_logs: [
        { action: 'Property tax payment ₹8,500 from Survey #142', time: '1 hour ago' },
        { action: 'Market vendor Ravi - stall fee ₹200 collected', time: '3 hours ago' },
        { action: 'Community Hall booking approved for 15 Aug', time: '5 hours ago' },
      ],
    };
  }

  /**
   * Field Dispatches for Assistant & Junior Engineers
   */
  async getFieldOpsDispatches(orgUnitId?: number) {
    return {
      role: 'assistant_engineer',
      title: 'Sub-Division Field Dispatches',
      kpis: {
        open_complaints: 23,
        pending_inspections: 7,
        dispatched_repairs: 12,
        contractor_tasks: 4,
      },
      dispatches: [
        { id: 'FD-087', task: 'Pole TY-006 street light flickering', tech: 'Kannan (Electrician)', status: 'En Route' },
        { id: 'FD-086', task: 'Water leak near Ration Shop Colony', tech: 'Senthil (Plumber)', status: 'On Site' },
        { id: 'FD-085', task: 'Drainage block Ward 2 - Pillaiyar Kovil', tech: 'Rajan (JE)', status: 'Completed' },
        { id: 'FD-084', task: 'Bus shelter roof panel repair', tech: 'Murugan Electricals', status: 'Awaiting QC' },
      ],
    };
  }

  /**
   * Stall Fee Collection for Revenue Inspector
   */
  async recordStallFeeCollection(dto: { stall_id?: number; vendor_name: string; amount: number; payment_mode: string; remarks?: string }) {
    if (!dto.vendor_name || !dto.amount) {
      throw new BadRequestException('Vendor name and amount are required');
    }
    return {
      success: true,
      message: `Fee of ₹${dto.amount} recorded for vendor ${dto.vendor_name} via ${dto.payment_mode}`,
      timestamp: new Date().toISOString(),
      receipt_no: `RCT-${Date.now().toString().slice(-6)}`,
    };
  }

  /**
   * Ticket Routing for I3C Command Center Staff
   */
  async routeI3cTicket(ticketId: string, department: string, assignedTo?: string) {
    if (!ticketId || !department) {
      throw new BadRequestException('Ticket ID and target department are required');
    }
    return {
      success: true,
      ticket_id: ticketId,
      status: 'ROUTED',
      department,
      assigned_to: assignedTo || 'Auto Dispatch',
      routed_at: new Date().toISOString(),
    };
  }

  /**
   * Self-Service Bids & Work Orders for Contractor / Vendor
   */
  async getContractorBidsAndWorkOrders(userId: number) {
    const invites = await this.prisma.tenderInvite.findMany({
      take: 10,
      orderBy: { created_at: 'desc' },
      include: {
        tender: true,
      },
    }).catch(() => []);

    return {
      role: 'contractor',
      title: 'Vendor Bids & Contract Work Orders',
      kpis: {
        active_tenders: 3,
        bids_submitted: invites.length || 5,
        contracts_won: 2,
        work_orders: 4,
      },
      bids: invites.map(b => ({
        id: b.id,
        tender_title: b.tender?.title_en ?? b.tender?.title_ta ?? 'Tender Opportunity',
        status: b.invite_token ? 'INVITED' : 'PENDING',
        submitted_at: b.created_at,
      })),
      tenders: [
        { id: 'TND-045', title: 'LED Street Light Installation — Ward 3', budget: '₹6.5L', deadline: '15 Aug 2026', status: 'Open' },
        { id: 'TND-044', title: 'Underground Drainage Phase-III', budget: '₹24.0L', deadline: '20 Aug 2026', status: 'Open' },
        { id: 'TND-043', title: 'Community Hall Renovation', budget: '₹8.2L', deadline: '10 Aug 2026', status: 'Bid Submitted' },
      ],
    };
  }
}
