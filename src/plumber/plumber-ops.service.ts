import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { resolveDateRange } from '../common/date-preset.util';

/**
 * Admin-facing plumber operations service.
 * Mirrors ElectricianOpsService but for the `plumber` role
 * and `assigned_plumber_id` on complaints.
 */
@Injectable()
export class PlumberOpsService {
  private readonly logger = new Logger(PlumberOpsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** List plumbers in a specific panchayat (for panchayat admin). */
  async listPlumbers(orgUnitId: number) {
    return this.prisma.user.findMany({
      where: { primary_org_unit_id: orgUnitId, role: 'plumber' },
      select: {
        id: true,
        email: true,
        phone_e164: true,
        created_at: true,
        primary_org_unit_id: true,
      },
      orderBy: { id: 'asc' },
    });
  }

  /** List all plumbers across panchayats (for super admin). */
  async listAllPlumbers(panchayatFilterId?: number) {
    return this.prisma.user.findMany({
      where: {
        role: 'plumber',
        ...(panchayatFilterId != null && !Number.isNaN(panchayatFilterId)
          ? { primary_org_unit_id: panchayatFilterId }
          : {}),
      },
      select: {
        id: true,
        email: true,
        phone_e164: true,
        created_at: true,
        primary_org_unit_id: true,
        primary_org_unit: { select: { id: true, name: true } },
      },
      orderBy: [{ primary_org_unit_id: 'asc' }, { id: 'asc' }],
    });
  }

  /** Create a new plumber user for a panchayat. */
  async createPlumberForPanchayat(
    orgUnitId: number,
    data: { email: string; password: string; phone_e164?: string | null },
  ) {
    if (!data.password || data.password.length < 8) {
      throw new BadRequestException(
        'Password must be at least 8 characters long',
      );
    }
    const existing = await this.prisma.user.findFirst({
      where: { email: data.email },
    });
    if (existing) throw new BadRequestException('Email already in use');
    const password_hash = await bcrypt.hash(data.password, 10);
    return this.prisma.user.create({
      data: {
        email: data.email,
        password_hash,
        role: 'plumber',
        primary_org_unit_id: orgUnitId,
        phone_e164: data.phone_e164?.trim() || null,
      },
      select: {
        id: true,
        email: true,
        phone_e164: true,
        role: true,
        primary_org_unit_id: true,
        created_at: true,
      },
    });
  }

  /** Get stats for a plumber within a date range preset. */
  async getPlumberStats(
    plumberId: number,
    scopedPanchayatId: number | null,
    preset: string,
    dateFrom?: string,
    dateTo?: string,
  ) {
    const u = await this.prisma.user.findUnique({
      where: { id: plumberId },
    });
    if (!u || u.role !== 'plumber')
      throw new NotFoundException('Plumber not found');
    if (scopedPanchayatId != null && u.primary_org_unit_id !== scopedPanchayatId) {
      throw new ForbiddenException('Plumber belongs to another panchayat');
    }

    const { from, to } = resolveDateRange(preset, dateFrom, dateTo);

    const [assignedInPeriod, resolvedInPeriod, openAssigned] =
      await Promise.all([
        this.prisma.complaint.count({
          where: {
            assigned_plumber_id: plumberId,
            assigned_at: { gte: from, lte: to },
          },
        }),
        this.prisma.complaint.count({
          where: {
            assigned_plumber_id: plumberId,
            status: 'resolved',
            resolved_at: { gte: from, lte: to },
          },
        }),
        this.prisma.complaint.count({
          where: {
            assigned_plumber_id: plumberId,
            status: {
              in: [
                'assigned',
                'in_progress',
                'resolved_pending_confirmation',
                'reassign_required',
              ],
            },
          },
        }),
      ]);

    return {
      plumber: { id: u.id, email: u.email, phone_e164: u.phone_e164 },
      preset,
      range: { from: from.toISOString(), to: to.toISOString() },
      assigned_in_period: assignedInPeriod,
      resolved_in_period: resolvedInPeriod,
      open_assigned: openAssigned,
    };
  }

  /**
   * Assign a complaint to a plumber (called from PanchayatAdminController).
   * Validates that the plumber belongs to the same panchayat.
   */
  async assignPlumber(
    orgUnitId: number,
    complaintId: number,
    plumberUserId: number,
  ) {
    const plumber = await this.prisma.user.findUnique({
      where: { id: plumberUserId },
      select: { id: true, role: true, primary_org_unit_id: true, phone_e164: true },
    });
    if (!plumber || plumber.role !== 'plumber') {
      throw new BadRequestException('User is not a plumber');
    }
    if (plumber.primary_org_unit_id !== orgUnitId) {
      throw new ForbiddenException('Plumber belongs to another panchayat');
    }

    const complaint = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
    });
    if (!complaint)
      throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (complaint.org_unit_id !== orgUnitId) {
      throw new ForbiddenException(
        'Access denied — complaint belongs to another panchayat',
      );
    }
    if (!['pending', 'reassign_required'].includes(complaint.status)) {
      throw new BadRequestException(
        `Can only assign complaints in status pending or reassign_required. Current: ${complaint.status}`,
      );
    }

    const updated = await this.prisma.complaint.update({
      where: { id: complaintId },
      data: {
        assigned_plumber_id: plumberUserId,
        assigned_at: new Date(),
        status: 'assigned',
      },
      include: {
        pole: true,
        pipeline: true,
        assigned_plumber: {
          select: { id: true, email: true, phone_e164: true },
        },
      },
    });

    return updated;
  }
}
