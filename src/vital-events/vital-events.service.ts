import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { createHash, randomBytes } from 'crypto';
import {
  Prisma,
  ReportingSource,
  VitalEventStatus,
  VitalEventType,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { DocumentService } from '../core/document/document.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { SlaService } from '../core/sla/sla.service';
import { WorkflowService } from '../core/workflow/workflow.service';
import { assessDelay } from './registration-delay';
import type {
  CancelCertificateDto,
  CorrectEventDto,
  HospitalFeedDto,
  IssueCertificateDto,
  ListVitalEventsDto,
  RegisterEventDto,
  RejectEventDto,
  ReportVitalEventDto,
  UpdateParticularsDto,
} from './dto/vital-event.dto';

const ENTITY_TYPE = 'vital_event';
const MODULE = 'vital_events';
const WORKFLOW_TEMPLATE = 'vital_event_registration';
const CERTIFICATE_SEQUENCE = 'vital_certificate';

/**
 * Legal status transitions. Registration is one-way: once an entry is in the
 * register it can only be corrected, never un-registered.
 */
const ALLOWED_TRANSITIONS: Record<VitalEventStatus, VitalEventStatus[]> = {
  REPORTED: ['VERIFIED', 'REJECTED'],
  VERIFIED: ['REGISTERED', 'REPORTED', 'REJECTED'],
  REGISTERED: ['CORRECTED'],
  CORRECTED: ['CORRECTED'],
  REJECTED: [],
} as Record<VitalEventStatus, VitalEventStatus[]>;

/** Statuses in which the particulars may still be edited freely. */
const EDITABLE_STATUSES: VitalEventStatus[] = ['REPORTED', 'VERIFIED'];

type EventWithDetails = Prisma.VitalEventGetPayload<{
  include: { birth: true; death: true; certificates: true };
}>;

@Injectable()
export class VitalEventsService {
  private readonly logger = new Logger(VitalEventsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly numbers: NumberGenService,
    private readonly workflow: WorkflowService,
    private readonly sla: SlaService,
    private readonly audit: AuditService,
    private readonly documents: DocumentService,
  ) {}

  // ── Helpers ───────────────────────────────────────────────────────────────

  private num(value: Prisma.Decimal | number | null | undefined): number | null {
    if (value === null || value === undefined) return null;
    return typeof value === 'number' ? value : Number(value.toString());
  }

  /** Store only the last four digits — the rest is never needed after intake. */
  private maskAadhaar(aadhaar?: string | null): string | null {
    if (!aadhaar) return null;
    return `XXXXXXXX${aadhaar.slice(-4)}`;
  }

  private serialize(event: any) {
    if (!event) return event;
    return {
      ...event,
      birth: event.birth
        ? { ...event.birth, weight_kg: this.num(event.birth.weight_kg) }
        : null,
      certificates: (event.certificates ?? []).map((c: any) => ({
        ...c,
        fee_amount: this.num(c.fee_amount),
        // The verification token is what the QR encodes. It is deliberately
        // not exposed on list payloads — only here, where the registrar is
        // printing the certificate.
      })),
    };
  }

  /** Load an entry and prove it belongs to the caller's tenant. */
  private async findOwned(
    tenantId: string,
    id: number,
  ): Promise<EventWithDetails> {
    const event = await this.prisma.vitalEvent.findFirst({
      where: { id, tenant_id: tenantId },
      include: { birth: true, death: true, certificates: true },
    });
    if (!event) throw new NotFoundException(`Register entry #${id} not found`);
    return event as EventWithDetails;
  }

  private assertTransition(from: VitalEventStatus, to: VitalEventStatus) {
    const allowed = ALLOWED_TRANSITIONS[from] ?? [];
    if (!allowed.includes(to)) {
      throw new BadRequestException(
        `Cannot move a register entry from ${from} to ${to}` +
          (allowed.length
            ? `. Allowed from ${from}: ${allowed.join(', ')}`
            : `. ${from} is a terminal state.`),
      );
    }
  }

  private async assertOrgUnit(tenantId: string, orgUnitId: number) {
    const orgUnit = await this.prisma.orgUnit.findFirst({
      where: { id: orgUnitId, tenant_id: tenantId },
      select: { id: true },
    });
    if (!orgUnit) {
      throw new ForbiddenException(
        `Org unit #${orgUnitId} does not belong to your tenant`,
      );
    }
  }

  /**
   * Hash over the particulars that appear on the printed certificate. A
   * verifier comparing this against a re-computed hash can tell whether the
   * paper in front of them matches the register.
   */
  private sealHash(event: EventWithDetails, certificateNumber: string): string {
    const subject =
      event.event_type === 'BIRTH'
        ? (event.birth?.child_name ?? '')
        : (event.death?.deceased_name ?? '');
    const material = [
      event.registration_number ?? '',
      certificateNumber,
      event.event_type,
      event.event_date.toISOString().slice(0, 10),
      subject,
      event.place_name ?? '',
      event.org_unit_id,
    ].join('|');
    return createHash('sha256').update(material).digest('hex');
  }

  private buildBirthData(dto: any) {
    return {
      child_name: dto.child_name ?? null,
      sex: dto.sex,
      weight_kg: dto.weight_kg ?? null,
      delivery_type: dto.delivery_type ?? null,
      father_name: dto.father_name ?? null,
      father_aadhaar: this.maskAadhaar(dto.father_aadhaar),
      father_education: dto.father_education ?? null,
      father_occupation: dto.father_occupation ?? null,
      mother_name: dto.mother_name,
      mother_aadhaar: this.maskAadhaar(dto.mother_aadhaar),
      mother_education: dto.mother_education ?? null,
      mother_occupation: dto.mother_occupation ?? null,
      mother_age_at_marriage: dto.mother_age_at_marriage ?? null,
      mother_age_at_birth: dto.mother_age_at_birth ?? null,
      birth_order: dto.birth_order ?? null,
      address_at_birth: dto.address_at_birth ?? null,
      permanent_address: dto.permanent_address ?? null,
      is_multiple_birth: dto.is_multiple_birth ?? false,
      multiple_birth_order: dto.multiple_birth_order ?? null,
    };
  }

  private buildDeathData(dto: any) {
    return {
      deceased_name: dto.deceased_name,
      sex: dto.sex,
      age_years: dto.age_years ?? null,
      age_months: dto.age_months ?? null,
      age_days: dto.age_days ?? null,
      date_of_birth: dto.date_of_birth ? new Date(dto.date_of_birth) : null,
      father_name: dto.father_name ?? null,
      mother_name: dto.mother_name ?? null,
      spouse_name: dto.spouse_name ?? null,
      occupation: dto.occupation ?? null,
      address: dto.address ?? null,
      cause_of_death: dto.cause_of_death ?? null,
      cause_category: dto.cause_category ?? null,
      medically_certified: dto.medically_certified ?? false,
      certifying_doctor: dto.certifying_doctor ?? null,
      doctor_reg_no: dto.doctor_reg_no ?? null,
      disposal_method: dto.disposal_method ?? null,
      disposal_place: dto.disposal_place ?? null,
      disposal_date: dto.disposal_date ? new Date(dto.disposal_date) : null,
    };
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  async list(tenantId: string, query: ListVitalEventsDto) {
    const where: Prisma.VitalEventWhereInput = {
      tenant_id: tenantId,
      ...(query.org_unit_id !== undefined && { org_unit_id: query.org_unit_id }),
      ...(query.event_type && {
        event_type: query.event_type as VitalEventType,
      }),
      ...(query.status && {
        status: query.status.toUpperCase() as VitalEventStatus,
      }),
      ...(query.late_only && { is_late_registration: true }),
      ...((query.from || query.to) && {
        event_date: {
          ...(query.from && { gte: new Date(query.from) }),
          ...(query.to && { lte: new Date(query.to) }),
        },
      }),
      ...(query.q && {
        OR: [
          { registration_number: { contains: query.q, mode: 'insensitive' } },
          { informant_name: { contains: query.q, mode: 'insensitive' } },
          { informant_phone: { contains: query.q } },
          { place_name: { contains: query.q, mode: 'insensitive' } },
          { birth: { child_name: { contains: query.q, mode: 'insensitive' } } },
          { birth: { mother_name: { contains: query.q, mode: 'insensitive' } } },
          { birth: { father_name: { contains: query.q, mode: 'insensitive' } } },
          { death: { deceased_name: { contains: query.q, mode: 'insensitive' } } },
        ],
      }),
    };

    const [rows, total] = await Promise.all([
      this.prisma.vitalEvent.findMany({
        where,
        include: {
          org_unit: { select: { id: true, name: true } },
          birth: { select: { child_name: true, sex: true, mother_name: true, father_name: true } },
          death: { select: { deceased_name: true, sex: true, age_years: true } },
          _count: { select: { certificates: true } },
        },
        orderBy: [{ event_date: 'desc' }, { id: 'desc' }],
        take: query.take ?? 50,
        skip: query.skip ?? 0,
      }),
      this.prisma.vitalEvent.count({ where }),
    ]);

    return { total, items: rows };
  }

  async getById(tenantId: string, id: number) {
    const event = await this.prisma.vitalEvent.findFirst({
      where: { id, tenant_id: tenantId },
      include: {
        org_unit: { select: { id: true, name: true } },
        birth: true,
        death: true,
        certificates: { orderBy: { copy_number: 'asc' } },
      },
    });
    if (!event) throw new NotFoundException(`Register entry #${id} not found`);

    const [timeline, documents, history] = await Promise.all([
      this.workflow.getTimeline(tenantId, ENTITY_TYPE, id),
      this.documents.getForEntity(tenantId, ENTITY_TYPE, id),
      this.audit.getEntityHistory(tenantId, ENTITY_TYPE, id.toString(), 25),
    ]);

    return {
      ...this.serialize(event),
      workflow: timeline,
      documents,
      history: history.map((h) => ({ ...h, id: h.id.toString() })),
      readiness: this.readiness(event as EventWithDetails),
    };
  }

  /** What stands between this entry and registration. */
  private readiness(event: EventWithDetails) {
    const assessment = assessDelay(event.event_date, event.reported_at);
    const blockers: string[] = [];

    if (assessment.requiresApprovalRef && !event.delay_approval_ref) {
      blockers.push(
        assessment.band === 'magistrate_order'
          ? 'A magistrate\'s order reference is required before this entry can be registered'
          : 'Written permission of the prescribed authority is required before this entry can be registered',
      );
    }
    if (event.event_type === 'BIRTH' && !event.birth) {
      blockers.push('Birth particulars (Form 1) are missing');
    }
    if (event.event_type === 'DEATH' && !event.death) {
      blockers.push('Death particulars (Form 2) are missing');
    }

    return {
      delay_days: assessment.delayDays,
      delay_band: assessment.band,
      delay_reason: assessment.reason,
      requires_approval_ref: assessment.requiresApprovalRef,
      has_approval_ref: Boolean(event.delay_approval_ref),
      blockers,
      can_register: blockers.length === 0 && event.status === 'VERIFIED',
    };
  }

  /** Counters for the registry header. */
  async summary(tenantId: string, orgUnitId?: number) {
    const where: Prisma.VitalEventWhereInput = {
      tenant_id: tenantId,
      ...(orgUnitId !== undefined && { org_unit_id: orgUnitId }),
    };

    const startOfYear = new Date(new Date().getFullYear(), 0, 1);

    const [byType, byStatus, lateCount, certificatesIssued] = await Promise.all([
      this.prisma.vitalEvent.groupBy({
        by: ['event_type'],
        where: { ...where, status: { in: ['REGISTERED', 'CORRECTED'] } },
        _count: { _all: true },
      }),
      this.prisma.vitalEvent.groupBy({
        by: ['status'],
        where,
        _count: { _all: true },
      }),
      this.prisma.vitalEvent.count({
        where: { ...where, is_late_registration: true, status: { not: 'REJECTED' } },
      }),
      this.prisma.vitalCertificate.count({
        where: {
          is_cancelled: false,
          issued_at: { gte: startOfYear },
          event: where,
        },
      }),
    ]);

    const typeCounts = Object.fromEntries(
      byType.map((r) => [r.event_type, r._count._all]),
    ) as Record<string, number>;
    const statusCounts = Object.fromEntries(
      byStatus.map((r) => [r.status, r._count._all]),
    ) as Record<string, number>;

    return {
      births_registered: typeCounts.BIRTH ?? 0,
      deaths_registered: typeCounts.DEATH ?? 0,
      pending_action: (statusCounts.REPORTED ?? 0) + (statusCounts.VERIFIED ?? 0),
      late_registrations: lateCount,
      certificates_issued_this_year: certificatesIssued,
      by_status: statusCounts,
      total: byStatus.reduce((sum, r) => sum + r._count._all, 0),
    };
  }

  // ── Intake ────────────────────────────────────────────────────────────────

  async reportEvent(
    tenantId: string,
    orgUnitId: number,
    userId: number | null,
    dto: ReportVitalEventDto,
  ) {
    await this.assertOrgUnit(tenantId, orgUnitId);

    const eventDate = new Date(dto.event_date);
    if (Number.isNaN(eventDate.getTime())) {
      throw new BadRequestException('event_date is not a valid date');
    }

    const reportedAt = new Date();
    const assessment = assessDelay(eventDate, reportedAt);
    if (assessment.delayDays < 0) {
      throw new BadRequestException(
        `event_date is ${Math.abs(assessment.delayDays)} day(s) in the future`,
      );
    }

    if (dto.event_type === 'BIRTH' && !dto.birth) {
      throw new BadRequestException('Birth particulars (Form 1) are required');
    }
    if (dto.event_type === 'DEATH' && !dto.death) {
      throw new BadRequestException('Death particulars (Form 2) are required');
    }

    const event = await this.prisma.vitalEvent.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        event_type: dto.event_type as VitalEventType,
        status: 'REPORTED',

        event_date: eventDate,
        event_time: dto.event_time ?? null,
        place_type: dto.place_type,
        place_name: dto.place_name ?? null,
        place_address: dto.place_address ?? null,
        latitude: dto.latitude ?? null,
        longitude: dto.longitude ?? null,

        reporting_source: (dto.reporting_source ??
          'SELF_REPORTED') as ReportingSource,
        hospital_name: dto.hospital_name ?? null,
        hospital_reg_no: dto.hospital_reg_no ?? null,
        reported_at: reportedAt,

        informant_name: dto.informant_name,
        informant_relation: dto.informant_relation,
        informant_phone: dto.informant_phone ?? null,
        informant_address: dto.informant_address ?? null,
        informant_aadhaar: this.maskAadhaar(dto.informant_aadhaar),

        is_late_registration: assessment.isLate,
        delay_days: assessment.delayDays,

        created_by: userId,

        ...(dto.event_type === 'BIRTH' && dto.birth
          ? { birth: { create: this.buildBirthData(dto.birth) } }
          : {}),
        ...(dto.event_type === 'DEATH' && dto.death
          ? { death: { create: this.buildDeathData(dto.death) } }
          : {}),
      },
      include: { birth: true, death: true, certificates: true },
    });

    // The statutory clock runs from the event, not from when we heard about
    // it, so a late report starts already against the wall.
    await this.sla.startTracker(
      tenantId,
      orgUnitId,
      ENTITY_TYPE,
      event.id,
      dto.event_type.toLowerCase(),
      assessment.isLate ? 'high' : 'medium',
    );

    await this.audit.log({
      tenantId,
      orgUnitId,
      userId: userId ?? undefined,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: event.id.toString(),
      action: 'report',
      afterValue: {
        event_type: event.event_type,
        event_date: eventDate.toISOString().slice(0, 10),
        reporting_source: event.reporting_source,
        delay_days: assessment.delayDays,
        delay_band: assessment.band,
      },
    });

    this.logger.log(
      `Reported ${event.event_type} #${event.id} (${assessment.band}, ${assessment.delayDays}d)`,
    );
    return this.serialize(event);
  }

  /**
   * Bulk intake from a hospital's reporting system.
   *
   * Each event is committed independently: one malformed record in a batch of
   * two hundred must not cost the hospital the other 199, so failures are
   * collected and returned rather than thrown.
   */
  async hospitalFeed(
    tenantId: string,
    orgUnitId: number,
    userId: number | null,
    dto: HospitalFeedDto,
  ) {
    await this.assertOrgUnit(tenantId, orgUnitId);

    const accepted: number[] = [];
    const rejected: { index: number; reason: string }[] = [];

    for (let i = 0; i < dto.events.length; i++) {
      const raw = dto.events[i];
      try {
        const created = await this.reportEvent(tenantId, orgUnitId, userId, {
          ...raw,
          reporting_source: 'HOSPITAL',
          hospital_name: raw.hospital_name ?? dto.hospital_name,
          hospital_reg_no: raw.hospital_reg_no ?? dto.hospital_reg_no,
        });
        accepted.push(created.id);
      } catch (err: any) {
        rejected.push({ index: i, reason: err?.message ?? 'Unknown error' });
      }
    }

    await this.audit.log({
      tenantId,
      orgUnitId,
      userId: userId ?? undefined,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: '0',
      action: 'hospital_feed',
      afterValue: {
        hospital_name: dto.hospital_name,
        submitted: dto.events.length,
        accepted: accepted.length,
        rejected: rejected.length,
      },
    });

    this.logger.log(
      `Hospital feed from "${dto.hospital_name}": ${accepted.length} accepted, ${rejected.length} rejected`,
    );
    return {
      submitted: dto.events.length,
      accepted: accepted.length,
      rejected: rejected.length,
      accepted_ids: accepted,
      failures: rejected,
    };
  }

  async updateParticulars(
    tenantId: string,
    id: number,
    userId: number,
    dto: UpdateParticularsDto,
  ) {
    const before = await this.findOwned(tenantId, id);

    if (!EDITABLE_STATUSES.includes(before.status)) {
      throw new BadRequestException(
        `This entry is ${before.status}. A registered entry can only be changed by a correction under s.15.`,
      );
    }

    const after = await this.prisma.vitalEvent.update({
      where: { id },
      data: {
        ...(dto.place_name !== undefined && { place_name: dto.place_name }),
        ...(dto.place_address !== undefined && { place_address: dto.place_address }),
        ...(dto.informant_name !== undefined && {
          informant_name: dto.informant_name,
        }),
        ...(dto.informant_phone !== undefined && {
          informant_phone: dto.informant_phone,
        }),
        ...(dto.informant_address !== undefined && {
          informant_address: dto.informant_address,
        }),
        ...(dto.birth && before.event_type === 'BIRTH'
          ? {
              birth: {
                upsert: {
                  create: this.buildBirthData(dto.birth),
                  update: this.buildBirthData(dto.birth),
                },
              },
            }
          : {}),
        ...(dto.death && before.event_type === 'DEATH'
          ? {
              death: {
                upsert: {
                  create: this.buildDeathData(dto.death),
                  update: this.buildDeathData(dto.death),
                },
              },
            }
          : {}),
      },
      include: { birth: true, death: true, certificates: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: before.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'update_particulars',
      beforeValue: this.serialize(before),
      afterValue: this.serialize(after),
      changedFields: AuditService.diffFields(
        this.serialize(before),
        this.serialize(after),
      ),
    });

    return this.serialize(after);
  }

  // ── Registrar's acts ──────────────────────────────────────────────────────

  /** Particulars checked against the supporting documents. */
  async verifyEntry(tenantId: string, id: number, userId: number) {
    const event = await this.findOwned(tenantId, id);
    this.assertTransition(event.status, 'VERIFIED');

    const updated = await this.prisma.vitalEvent.update({
      where: { id },
      data: { status: 'VERIFIED' },
      include: { birth: true, death: true, certificates: true },
    });

    // A late entry needs sanction above the registrar, so the approval chain
    // only starts here — the workflow template's rules route on `delay_days`.
    if (event.is_late_registration) {
      const instance = await this.workflow.startWorkflow(
        tenantId,
        event.org_unit_id,
        WORKFLOW_TEMPLATE,
        ENTITY_TYPE,
        id,
      );
      if (!instance) {
        this.logger.warn(
          `Late entry #${id} verified without an approval chain — no published "${WORKFLOW_TEMPLATE}" template for org unit ${event.org_unit_id}`,
        );
      }
    }

    await this.audit.log({
      tenantId,
      orgUnitId: event.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'verify',
      beforeValue: { status: event.status },
      afterValue: { status: 'VERIFIED' },
      changedFields: ['status'],
    });

    return this.serialize(updated);
  }

  /**
   * The legal act: allot a serial number in the register.
   *
   * Birth and death registers carry independent serial sequences per
   * registration unit, reset on 1 January — hence the separate entity types
   * passed to the number generator.
   */
  async register(
    tenantId: string,
    id: number,
    userId: number,
    dto: RegisterEventDto,
  ) {
    const event = await this.findOwned(tenantId, id);
    this.assertTransition(event.status, 'REGISTERED');

    const assessment = assessDelay(event.event_date, event.reported_at);
    const approvalRef = dto.delay_approval_ref ?? event.delay_approval_ref;

    if (assessment.requiresApprovalRef && !approvalRef) {
      throw new BadRequestException(
        `Cannot register: ${assessment.reason}. Record the authorising reference first.`,
      );
    }
    if (event.event_type === 'BIRTH' && !event.birth) {
      throw new BadRequestException('Birth particulars (Form 1) are missing');
    }
    if (event.event_type === 'DEATH' && !event.death) {
      throw new BadRequestException('Death particulars (Form 2) are missing');
    }

    const sequenceEntity =
      event.event_type === 'BIRTH' ? 'birth_registration' : 'death_registration';
    const registrationNumber = await this.numbers.next(
      tenantId,
      sequenceEntity,
      event.org_unit_id,
    );

    const updated = await this.prisma.vitalEvent.update({
      where: { id },
      data: {
        status: 'REGISTERED',
        registration_number: registrationNumber,
        registered_at: new Date(),
        registered_by: userId,
        ...(approvalRef && { delay_approval_ref: approvalRef }),
      },
      include: { birth: true, death: true, certificates: true },
    });

    await this.closeSla(tenantId, id);

    await this.audit.log({
      tenantId,
      orgUnitId: event.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'register',
      beforeValue: { status: event.status },
      afterValue: {
        status: 'REGISTERED',
        registration_number: registrationNumber,
        delay_band: assessment.band,
        delay_approval_ref: approvalRef ?? null,
      },
      changedFields: ['status', 'registration_number'],
    });

    this.logger.log(
      `Registered ${event.event_type} #${id} as ${registrationNumber}`,
    );
    return this.serialize(updated);
  }

  async reject(
    tenantId: string,
    id: number,
    userId: number,
    dto: RejectEventDto,
  ) {
    const event = await this.findOwned(tenantId, id);
    this.assertTransition(event.status, 'REJECTED');

    const updated = await this.prisma.vitalEvent.update({
      where: { id },
      data: { status: 'REJECTED', rejection_reason: dto.reason },
      include: { birth: true, death: true, certificates: true },
    });

    await this.closeSla(tenantId, id);

    await this.audit.log({
      tenantId,
      orgUnitId: event.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'reject',
      beforeValue: { status: event.status },
      afterValue: { status: 'REJECTED', rejection_reason: dto.reason },
      changedFields: ['status', 'rejection_reason'],
    });

    return this.serialize(updated);
  }

  /**
   * Correction of a registered entry under s.15.
   *
   * The previous values go into the audit log's `beforeValue` before anything
   * is written, and any certificate already issued against the old particulars
   * is cancelled — leaving it valid would put two contradictory documents in
   * circulation.
   */
  async correct(
    tenantId: string,
    id: number,
    userId: number,
    dto: CorrectEventDto,
  ) {
    const before = await this.findOwned(tenantId, id);
    this.assertTransition(before.status, 'CORRECTED');

    if (before.event_type === 'BIRTH' && dto.death) {
      throw new BadRequestException('Death particulars sent for a birth entry');
    }
    if (before.event_type === 'DEATH' && dto.birth) {
      throw new BadRequestException('Birth particulars sent for a death entry');
    }
    if (!dto.birth && !dto.death) {
      throw new BadRequestException('A correction must change some particular');
    }

    const after = await this.prisma.vitalEvent.update({
      where: { id },
      data: {
        status: 'CORRECTED',
        correction_note: dto.correction_note,
        ...(dto.birth && before.event_type === 'BIRTH'
          ? { birth: { update: this.buildBirthData(dto.birth) } }
          : {}),
        ...(dto.death && before.event_type === 'DEATH'
          ? { death: { update: this.buildDeathData(dto.death) } }
          : {}),
      },
      include: { birth: true, death: true, certificates: true },
    });

    const liveCertificates = before.certificates.filter((c) => !c.is_cancelled);
    if (liveCertificates.length > 0) {
      await this.prisma.vitalCertificate.updateMany({
        where: { id: { in: liveCertificates.map((c) => c.id) } },
        data: {
          is_cancelled: true,
          cancelled_reason: `Superseded by a correction on ${new Date().toISOString().slice(0, 10)}`,
          cancelled_at: new Date(),
        },
      });
      this.logger.log(
        `Cancelled ${liveCertificates.length} certificate(s) for corrected entry #${id}`,
      );
    }

    await this.audit.log({
      tenantId,
      orgUnitId: before.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'correct',
      beforeValue: this.serialize(before),
      afterValue: this.serialize(after),
      changedFields: AuditService.diffFields(
        this.serialize(before),
        this.serialize(after),
      ),
    });

    return {
      ...this.serialize(after),
      cancelled_certificates: liveCertificates.length,
    };
  }

  private async closeSla(tenantId: string, id: number) {
    await this.prisma.slaTracker.updateMany({
      where: {
        tenant_id: tenantId,
        entity_type: ENTITY_TYPE,
        entity_id: id,
        resolved_at: null,
      },
      data: { resolved_at: new Date(), status: 'resolved' },
    });
  }

  // ── Certificates ──────────────────────────────────────────────────────────

  /**
   * Issue a certificate against a registered entry. Each copy is its own row
   * with its own verification token, so a reissue never invalidates the record
   * of what was handed over the first time.
   */
  async issueCertificate(
    tenantId: string,
    id: number,
    userId: number,
    dto: IssueCertificateDto,
  ) {
    const event = await this.findOwned(tenantId, id);

    if (event.status !== 'REGISTERED' && event.status !== 'CORRECTED') {
      throw new BadRequestException(
        `A certificate can only be issued against a registered entry — this one is ${event.status}`,
      );
    }
    if (!event.registration_number) {
      throw new BadRequestException(
        'This entry has no registration number allotted',
      );
    }

    const certificateNumber = await this.numbers.next(
      tenantId,
      CERTIFICATE_SEQUENCE,
      event.org_unit_id,
    );
    const nextCopy =
      event.certificates.reduce((max, c) => Math.max(max, c.copy_number), 0) + 1;

    const certificate = await this.prisma.vitalCertificate.create({
      data: {
        vital_event_id: id,
        certificate_number: certificateNumber,
        // 32 bytes of randomness, not a sequence — a valid certificate must
        // not be discoverable by incrementing someone else's token.
        verification_token: randomBytes(24).toString('base64url'),
        copy_number: nextCopy,
        issued_to: dto.issued_to,
        issued_to_relation: dto.issued_to_relation ?? null,
        purpose: dto.purpose ?? null,
        fee_amount: dto.fee_amount ?? 0,
        payment_ref: dto.payment_ref ?? null,
        seal_hash: this.sealHash(event, certificateNumber),
        issued_by: userId,
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: event.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'certificate_issued',
      afterValue: {
        certificate_number: certificateNumber,
        copy_number: nextCopy,
        issued_to: dto.issued_to,
        purpose: dto.purpose ?? null,
        fee_amount: dto.fee_amount ?? 0,
      },
    });

    this.logger.log(
      `Issued certificate ${certificateNumber} (copy ${nextCopy}) for entry #${id}`,
    );
    return { ...certificate, fee_amount: this.num(certificate.fee_amount) };
  }

  async cancelCertificate(
    tenantId: string,
    id: number,
    certificateId: number,
    userId: number,
    dto: CancelCertificateDto,
  ) {
    const event = await this.findOwned(tenantId, id);
    const certificate = event.certificates.find((c) => c.id === certificateId);
    if (!certificate) {
      throw new NotFoundException(
        `Certificate #${certificateId} is not on entry #${id}`,
      );
    }
    if (certificate.is_cancelled) {
      throw new BadRequestException('This certificate is already cancelled');
    }

    const updated = await this.prisma.vitalCertificate.update({
      where: { id: certificateId },
      data: {
        is_cancelled: true,
        cancelled_reason: dto.reason,
        cancelled_at: new Date(),
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: event.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'certificate_cancelled',
      beforeValue: { certificate_number: certificate.certificate_number },
      afterValue: {
        certificate_number: certificate.certificate_number,
        cancelled_reason: dto.reason,
      },
    });

    return { ...updated, fee_amount: this.num(updated.fee_amount) };
  }

  /**
   * Public QR verification. Unauthenticated, so it returns only what a
   * verifier needs to confirm the document in their hand is genuine — never
   * the informant's contact details, never Aadhaar fragments, never the
   * parents' particulars beyond the names printed on the certificate itself.
   */
  async verifyByToken(token: string) {
    const certificate = await this.prisma.vitalCertificate.findUnique({
      where: { verification_token: token },
      include: {
        event: {
          include: {
            org_unit: { select: { name: true } },
            birth: { select: { child_name: true, sex: true, mother_name: true, father_name: true } },
            death: { select: { deceased_name: true, sex: true } },
          },
        },
      },
    });

    if (!certificate) {
      throw new NotFoundException('This verification code is not recognised');
    }

    const event = certificate.event;
    const subject =
      event.event_type === 'BIRTH'
        ? (event.birth?.child_name ?? 'Name not recorded')
        : (event.death?.deceased_name ?? 'Name not recorded');

    return {
      valid: !certificate.is_cancelled,
      cancelled_reason: certificate.cancelled_reason,
      certificate_number: certificate.certificate_number,
      copy_number: certificate.copy_number,
      issued_at: certificate.issued_at,
      seal_hash: certificate.seal_hash,

      event_type: event.event_type,
      registration_number: event.registration_number,
      registered_at: event.registered_at,
      event_date: event.event_date,
      place_name: event.place_name,
      issuing_authority: event.org_unit.name,

      subject_name: subject,
      sex: event.event_type === 'BIRTH' ? event.birth?.sex : event.death?.sex,
      ...(event.event_type === 'BIRTH' && {
        mother_name: event.birth?.mother_name,
        father_name: event.birth?.father_name,
      }),
    };
  }
}
