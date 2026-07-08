import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Cron, CronExpression } from '@nestjs/schedule';

@Injectable()
export class PenaltyService {
  private readonly logger = new Logger(PenaltyService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── Cron: Scan for SLA Violations ───────────────────────────────────────────

  /**
   * Runs every hour. Finds assigned-but-unresolved complaints that have
   * exceeded their SLA deadline, and creates penalty records.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async scanForSlaViolations() {
    this.logger.log('⏰ Scanning for SLA violations...');

    const activeComplaints = await this.prisma.complaint.findMany({
      where: {
        status: { notIn: ['resolved', 'closed'] },
        assigned_at: { not: null },
        panchayat_id: { not: null },
        OR: [
          { assigned_electrician_id: { not: null } },
          { assigned_plumber_id: { not: null } },
        ],
      },
    });

    const now = new Date();
    let penaltiesApplied = 0;

    for (const complaint of activeComplaints) {
      const assignedUserId = complaint.assigned_plumber_id || complaint.assigned_electrician_id;
      const role = complaint.assigned_plumber_id ? 'plumber' : 'electrician';

      if (!assignedUserId || !complaint.panchayat_id || !complaint.assigned_at) continue;

      // Fetch the SLA rule for this role + urgency
      const rule = await this.prisma.penaltyRule.findUnique({
        where: {
          panchayat_id_role_urgency_level: {
            panchayat_id: complaint.panchayat_id,
            role,
            urgency_level: complaint.urgency_level || 'medium',
          },
        },
      });

      if (!rule || !rule.is_active) continue;

      const elapsedMs = now.getTime() - complaint.assigned_at.getTime();
      const elapsedHours = elapsedMs / (1000 * 60 * 60);

      if (elapsedHours > rule.deadline_hours) {
        // Check if penalty already exists for this complaint
        const existingPenalty = await this.prisma.userPenalty.findFirst({
          where: { complaint_id: complaint.id, user_id: assignedUserId },
        });

        if (!existingPenalty) {
          await this.prisma.userPenalty.create({
            data: {
              user_id: assignedUserId,
              complaint_id: complaint.id,
              amount: rule.penalty_amount,
              hours_delayed: elapsedHours - rule.deadline_hours,
              reason: `Exceeded ${rule.deadline_hours}-hour SLA deadline for ${role} on ${complaint.urgency_level || 'medium'} urgency complaint.`,
              status: 'pending',
            },
          });
          penaltiesApplied++;
          this.logger.warn(
            `⚠️ Penalty applied: User #${assignedUserId} for Complaint #${complaint.id} (${(elapsedHours - rule.deadline_hours).toFixed(1)}h overdue)`,
          );
        }
      }
    }

    this.logger.log(`✅ SLA scan complete. ${penaltiesApplied} new penalties applied.`);
  }

  // ─── Called on Complaint Resolution ──────────────────────────────────────────

  /** Finalize penalty calculation when a complaint is resolved. */
  async handleComplaintResolution(complaintId: number) {
    const complaint = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
    });

    if (!complaint || !complaint.resolved_at || !complaint.assigned_at) return;

    const assignedUserId = complaint.assigned_plumber_id || complaint.assigned_electrician_id;
    const role = complaint.assigned_plumber_id ? 'plumber' : 'electrician';

    if (!assignedUserId || !complaint.panchayat_id) return;

    const rule = await this.prisma.penaltyRule.findUnique({
      where: {
        panchayat_id_role_urgency_level: {
          panchayat_id: complaint.panchayat_id,
          role,
          urgency_level: complaint.urgency_level || 'medium',
        },
      },
    });

    if (!rule) return;

    const elapsedHours =
      (complaint.resolved_at.getTime() - complaint.assigned_at.getTime()) /
      (1000 * 60 * 60);

    if (elapsedHours > rule.deadline_hours) {
      const hoursDelayed = elapsedHours - rule.deadline_hours;
      const finalAmount = Number(rule.penalty_amount);

      // Upsert: update existing penalty or create final one
      const existing = await this.prisma.userPenalty.findFirst({
        where: { complaint_id: complaintId, user_id: assignedUserId },
      });

      if (existing) {
        await this.prisma.userPenalty.update({
          where: { id: existing.id },
          data: {
            amount: finalAmount,
            hours_delayed: hoursDelayed,
            reason: `Resolved ${hoursDelayed.toFixed(1)} hours past the ${rule.deadline_hours}-hour SLA deadline.`,
          },
        });
      } else {
        await this.prisma.userPenalty.create({
          data: {
            user_id: assignedUserId,
            complaint_id: complaintId,
            amount: finalAmount,
            hours_delayed: hoursDelayed,
            reason: `Resolved ${hoursDelayed.toFixed(1)} hours past the ${rule.deadline_hours}-hour SLA deadline.`,
            status: 'pending',
          },
        });
      }
    }
  }

  // ─── Penalty Rules CRUD ──────────────────────────────────────────────────────

  async listRules(panchayatId: number) {
    return this.prisma.penaltyRule.findMany({
      where: { panchayat_id: panchayatId },
      orderBy: [{ role: 'asc' }, { urgency_level: 'asc' }],
    });
  }

  async upsertRule(data: {
    panchayat_id: number;
    role: string;
    urgency_level: string;
    deadline_hours: number;
    penalty_amount: number;
  }) {
    return this.prisma.penaltyRule.upsert({
      where: {
        panchayat_id_role_urgency_level: {
          panchayat_id: data.panchayat_id,
          role: data.role,
          urgency_level: data.urgency_level,
        },
      },
      create: {
        panchayat_id: data.panchayat_id,
        role: data.role,
        urgency_level: data.urgency_level,
        deadline_hours: data.deadline_hours,
        penalty_amount: data.penalty_amount,
      },
      update: {
        deadline_hours: data.deadline_hours,
        penalty_amount: data.penalty_amount,
      },
    });
  }

  // ─── Penalty Records ────────────────────────────────────────────────────────

  /** List penalties for a specific user (worker). */
  async listPenaltiesByUser(userId: number) {
    return this.prisma.userPenalty.findMany({
      where: { user_id: userId },
      include: { complaint: { select: { id: true, complaint_type: true, status: true } } },
      orderBy: { created_at: 'desc' },
    });
  }

  /** List all penalties for a panchayat. */
  async listPenaltiesByPanchayat(panchayatId: number) {
    return this.prisma.userPenalty.findMany({
      where: { complaint: { panchayat_id: panchayatId } },
      include: {
        user: { select: { id: true, email: true, role: true } },
        complaint: { select: { id: true, complaint_type: true, status: true } },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  /** Waive a penalty (admin action). */
  async waivePenalty(penaltyId: number, reason: string) {
    const penalty = await this.prisma.userPenalty.findUnique({ where: { id: penaltyId } });
    if (!penalty) throw new NotFoundException(`Penalty #${penaltyId} not found`);

    return this.prisma.userPenalty.update({
      where: { id: penaltyId },
      data: { status: 'waived', waived_reason: reason },
    });
  }

  /** Mark a penalty as deducted (from payment). */
  async markDeducted(penaltyId: number) {
    const penalty = await this.prisma.userPenalty.findUnique({ where: { id: penaltyId } });
    if (!penalty) throw new NotFoundException(`Penalty #${penaltyId} not found`);

    return this.prisma.userPenalty.update({
      where: { id: penaltyId },
      data: { status: 'deducted' },
    });
  }

  // ─── Summary Dashboard ──────────────────────────────────────────────────────

  /** Get penalty summary for a panchayat. */
  async getPenaltySummary(panchayatId: number) {
    const penalties = await this.prisma.userPenalty.findMany({
      where: { complaint: { panchayat_id: panchayatId } },
    });

    const total = penalties.length;
    const pending = penalties.filter(p => p.status === 'pending').length;
    const waived = penalties.filter(p => p.status === 'waived').length;
    const deducted = penalties.filter(p => p.status === 'deducted').length;
    const totalAmount = penalties.reduce((sum, p) => sum + Number(p.amount), 0);
    const pendingAmount = penalties
      .filter(p => p.status === 'pending')
      .reduce((sum, p) => sum + Number(p.amount), 0);

    return {
      total_penalties: total,
      pending,
      waived,
      deducted,
      total_penalty_amount: totalAmount.toFixed(2),
      pending_amount: pendingAmount.toFixed(2),
    };
  }
}
