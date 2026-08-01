import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Cron, CronExpression } from '@nestjs/schedule';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PLATFORM_EVENTS, SlaWarningEvent, SlaBreachedEvent } from '../events/platform-events';

@Injectable()
export class SlaService {
  private readonly logger = new Logger(SlaService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventEmitter2,
  ) {}

  /**
   * Calculate business date by adding a given number of hours to start date.
   * Skips weekends and holidays defined in calendar.
   */
  async calculateTargetDate(
    tenantId: string,
    branchId: number | null,
    startDate: Date,
    hoursToAdd: number,
  ): Promise<Date> {
    const calendar = await this.prisma.workingCalendar.findFirst({
      where: { tenant_id: tenantId, branch_id: branchId },
    }) || await this.prisma.workingCalendar.findFirst({
      where: { tenant_id: tenantId, branch_id: null, is_default: true },
    }) || {
      working_days: [1, 2, 3, 4, 5, 6], // Mon-Sat
      working_hours_start: '09:30',
      working_hours_end: '17:45',
    };

    const holidays = await this.prisma.holiday.findMany({
      where: {
        tenant_id: tenantId,
        branch_id: branchId ?? undefined,
        date: { gte: startDate },
        is_active: true,
      },
      select: { date: true },
    });
    const holidayDates = new Set(holidays.map((h) => h.date.toISOString().split('T')[0]));

    const workingDays = new Set(calendar.working_days); // 0=Sun, 1=Mon, ..., 6=Sat
    const [startHour, startMin] = calendar.working_hours_start.split(':').map(Number);
    const [endHour, endMin] = calendar.working_hours_end.split(':').map(Number);

    let currentDate = new Date(startDate);
    let remainingHours = hoursToAdd;

    const setWorkingTime = (date: Date, hours: number, minutes: number) => {
      date.setHours(hours, minutes, 0, 0);
    };

    while (remainingHours > 0) {
      const dateStr = currentDate.toISOString().split('T')[0];
      const dayOfWeek = currentDate.getDay();

      const isWorkingDay = workingDays.has(dayOfWeek) && !holidayDates.has(dateStr);

      if (isWorkingDay) {
        const endOfToday = new Date(currentDate);
        setWorkingTime(endOfToday, endHour, endMin);

        const startOfToday = new Date(currentDate);
        setWorkingTime(startOfToday, startHour, startMin);

        if (currentDate < startOfToday) {
          currentDate = startOfToday;
        }

        if (currentDate < endOfToday) {
          const availableHoursToday = (endOfToday.getTime() - currentDate.getTime()) / (1000 * 60 * 60);
          if (remainingHours <= availableHoursToday) {
            currentDate = new Date(currentDate.getTime() + remainingHours * 60 * 60 * 1000);
            remainingHours = 0;
          } else {
            remainingHours -= availableHoursToday;
            currentDate.setDate(currentDate.getDate() + 1);
            setWorkingTime(currentDate, startHour, startMin);
          }
        } else {
          currentDate.setDate(currentDate.getDate() + 1);
          setWorkingTime(currentDate, startHour, startMin);
        }
      } else {
        currentDate.setDate(currentDate.getDate() + 1);
        setWorkingTime(currentDate, startHour, startMin);
      }
    }

    return currentDate;
  }

  /**
   * Initialize a new SLA tracker for a complaint, building permit, etc.
   */
  async startTracker(
    tenantId: string,
    branchId: number,
    entityType: string,
    entityId: number,
    category: string,
    urgency: string,
  ) {
    const policy = await this.prisma.slaPolicy.findFirst({
      where: {
        tenant_id: tenantId,
        branch_id: branchId,
        entity_type: entityType,
        category,
        urgency_level: urgency,
        is_active: true,
      },
    }) || await this.prisma.slaPolicy.findFirst({
      where: {
        tenant_id: tenantId,
        branch_id: null,
        entity_type: entityType,
        category,
        urgency_level: urgency,
        is_active: true,
      },
    });

    if (!policy) {
      this.logger.warn(`No SLA Policy found for ${entityType} -> ${category} -> ${urgency}`);
      return null;
    }

    const start = new Date();
    const target = policy.is_24x7
      ? new Date(start.getTime() + policy.target_hours * 60 * 60 * 1000)
      : await this.calculateTargetDate(tenantId, branchId, start, policy.target_hours);

    const warning = policy.is_24x7
      ? new Date(start.getTime() + policy.warning_hours * 60 * 60 * 1000)
      : await this.calculateTargetDate(tenantId, branchId, start, policy.warning_hours);

    const escalation = policy.is_24x7
      ? new Date(start.getTime() + policy.escalation_hours * 60 * 60 * 1000)
      : await this.calculateTargetDate(tenantId, branchId, start, policy.escalation_hours);

    const breach = policy.is_24x7
      ? new Date(start.getTime() + policy.breach_hours * 60 * 60 * 1000)
      : await this.calculateTargetDate(tenantId, branchId, start, policy.breach_hours);

    return this.prisma.slaTracker.create({
      data: {
        tenant_id: tenantId,
        entity_type: entityType,
        entity_id: entityId,
        sla_policy_id: policy.id,
        started_at: start,
        target_at: target,
        warning_at: warning,
        escalation_at: escalation,
        breach_at: breach,
        status: 'on_track',
      },
    });
  }

  /**
   * Background scan running every hour to detect warning and breached deadlines.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async checkSlas() {
    this.logger.log('[SLA Engine] Scanning active SLA compliance trackers...');
    const trackers = await this.prisma.slaTracker.findMany({
      where: {
        status: { in: ['on_track', 'warning', 'escalated'] },
        resolved_at: null,
      },
    });

    const now = new Date();

    for (const tracker of trackers) {
      const policy = await this.prisma.slaPolicy.findUnique({
        where: { id: tracker.sla_policy_id },
      });

      if (!policy) continue;

      let updatedStatus = tracker.status;

      if (now >= tracker.breach_at && tracker.status !== 'breached') {
        updatedStatus = 'breached';

        // Auto-escalation if policy specifies a target role
        if (policy.escalation_role) {
          const role = await this.prisma.role.findFirst({
            where: { tenant_id: tracker.tenant_id, name: policy.escalation_role },
          });
          if (role) {
            const escalations = await this.prisma.userRole.findMany({
              where: {
                org_unit_id: tracker.entity_type === 'complaint'
                  ? (await this.prisma.complaint.findUnique({ where: { id: tracker.entity_id } }))?.panchayat_id || 0
                  : 0,
                role_id: role.id,
              },
              select: { user_id: true },
            });

            if (escalations.length > 0) {
              await this.prisma.slaTracker.update({
                where: { id: tracker.id },
                data: { escalated_to_user_id: escalations[0].user_id },
              });
              this.logger.log(`[SLA Escalation] Escalated ${tracker.entity_type}#${tracker.entity_id} to User#${escalations[0].user_id}`);
            }
          }
        }

        this.events.emit(PLATFORM_EVENTS.SLA_BREACHED, new SlaBreachedEvent(tracker.tenant_id, tracker.entity_type, tracker.entity_id, tracker.breach_at));
      } else if (now >= tracker.escalation_at && tracker.status === 'warning') {
        updatedStatus = 'escalated';
      } else if (now >= tracker.warning_at && tracker.status === 'on_track') {
        updatedStatus = 'warning';
        this.events.emit(PLATFORM_EVENTS.SLA_WARNING, new SlaWarningEvent(tracker.tenant_id, tracker.entity_type, tracker.entity_id, tracker.target_at));
      }

      if (updatedStatus !== tracker.status) {
        await this.prisma.slaTracker.update({
          where: { id: tracker.id },
          data: { status: updatedStatus },
        });
      }
    }
  }

  // ── SLA Policy Management (CRUD) ─────────────────────────────────────────

  async createPolicy(tenantId: string, data: any) {
    return this.prisma.slaPolicy.create({
      data: {
        ...data,
        tenant_id: tenantId,
      },
    });
  }

  async getPolicies(tenantId: string, branchId?: number) {
    return this.prisma.slaPolicy.findMany({
      where: {
        tenant_id: tenantId,
        ...(branchId !== undefined && { branch_id: branchId }),
        is_active: true,
      },
    });
  }

  async updatePolicy(tenantId: string, id: number, data: any) {
    const policy = await this.prisma.slaPolicy.findFirst({
      where: { id, tenant_id: tenantId },
    });
    if (!policy) throw new NotFoundException('SLA Policy not found');

    return this.prisma.slaPolicy.update({
      where: { id },
      data,
    });
  }

  async deletePolicy(tenantId: string, id: number) {
    const policy = await this.prisma.slaPolicy.findFirst({
      where: { id, tenant_id: tenantId },
    });
    if (!policy) throw new NotFoundException('SLA Policy not found');

    await this.prisma.slaPolicy.update({
      where: { id },
      data: { is_active: false },
    });
    return { success: true };
  }
}
