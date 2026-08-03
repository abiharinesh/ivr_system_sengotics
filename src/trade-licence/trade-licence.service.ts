import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { createHash, randomBytes } from 'crypto';
import { OwnershipType, Prisma, TradeLicenceStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { DocumentService } from '../core/document/document.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { SlaService } from '../core/sla/sla.service';
import { WorkflowService } from '../core/workflow/workflow.service';
import {
  assessRenewal,
  computeLicenceFee,
  financialYearEnd,
  financialYearOf,
  financialYearStart,
  nextFinancialYear,
  quartersRemaining,
  requiresAnnualInspection,
} from './licence-year';
import type {
  ApproveLicenceDto,
  CancelLicenceDto,
  CreateTradeLicenceDto,
  IssueLicenceCertificateDto,
  ListTradeLicencesDto,
  RecordLicenceInspectionDto,
  RecordLicencePaymentDto,
  RejectLicenceDto,
  RenewLicenceDto,
  ScheduleLicenceInspectionDto,
  SuspendLicenceDto,
  UpdateTradeLicenceDto,
} from './dto/trade-licence.dto';

const ENTITY_TYPE = 'trade_licence';
const MODULE = 'trade_licences';
const WORKFLOW_TEMPLATE = 'trade_licence_approval';
const LICENCE_SEQUENCE = 'trade_licence';
const CERTIFICATE_SEQUENCE = 'trade_licence_certificate';

/**
 * Legal status transitions.
 *
 * APPROVED → EXPIRED happens by the passage of time (the nightly sweep), and
 * EXPIRED → APPROVED only via renewal. A suspended licence can be restored;
 * a cancelled one cannot.
 */
const ALLOWED_TRANSITIONS: Record<TradeLicenceStatus, TradeLicenceStatus[]> = {
  DRAFT: ['SUBMITTED', 'CANCELLED'],
  SUBMITTED: ['INSPECTION', 'APPROVED', 'REJECTED', 'DRAFT'],
  INSPECTION: ['APPROVED', 'REJECTED', 'SUBMITTED'],
  APPROVED: ['EXPIRED', 'SUSPENDED', 'CANCELLED'],
  EXPIRED: ['APPROVED', 'CANCELLED'],
  SUSPENDED: ['APPROVED', 'CANCELLED'],
  REJECTED: [],
  CANCELLED: [],
} as Record<TradeLicenceStatus, TradeLicenceStatus[]>;

const EDITABLE_STATUSES: TradeLicenceStatus[] = ['DRAFT', 'SUBMITTED'];

type LicenceWithRelations = Prisma.TradeLicenceGetPayload<{
  include: { renewals: true; inspections: true; certificates: true };
}>;

@Injectable()
export class TradeLicenceService {
  private readonly logger = new Logger(TradeLicenceService.name);

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

  private maskAadhaar(aadhaar?: string | null): string | null {
    if (!aadhaar) return null;
    return `XXXXXXXX${aadhaar.slice(-4)}`;
  }

  private serialize(licence: any) {
    if (!licence) return licence;
    return {
      ...licence,
      motive_power_hp: this.num(licence.motive_power_hp),
      area_sqft: this.num(licence.area_sqft),
      base_fee: this.num(licence.base_fee),
      area_fee: this.num(licence.area_fee),
      power_fee: this.num(licence.power_fee),
      penalty_fee: this.num(licence.penalty_fee),
      total_fee: this.num(licence.total_fee),
      paid_amount: this.num(licence.paid_amount),
      renewals: (licence.renewals ?? []).map((r: any) => ({
        ...r,
        base_fee: this.num(r.base_fee),
        area_fee: this.num(r.area_fee),
        power_fee: this.num(r.power_fee),
        penalty_fee: this.num(r.penalty_fee),
        total_fee: this.num(r.total_fee),
        paid_amount: this.num(r.paid_amount),
      })),
    };
  }

  private async findOwned(
    tenantId: string,
    id: number,
  ): Promise<LicenceWithRelations> {
    const licence = await this.prisma.tradeLicence.findFirst({
      where: { id, tenant_id: tenantId },
      include: { renewals: true, inspections: true, certificates: true },
    });
    if (!licence) throw new NotFoundException(`Trade licence #${id} not found`);
    return licence as LicenceWithRelations;
  }

  private assertTransition(
    from: TradeLicenceStatus,
    to: TradeLicenceStatus,
  ) {
    const allowed = ALLOWED_TRANSITIONS[from] ?? [];
    if (!allowed.includes(to)) {
      throw new BadRequestException(
        `Cannot move a licence from ${from} to ${to}` +
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

  private sealHash(licence: LicenceWithRelations, certificateNumber: string) {
    const material = [
      licence.licence_number,
      certificateNumber,
      licence.licence_year ?? '',
      licence.trade_name,
      licence.trade_category,
      licence.owner_name,
      licence.door_number ?? '',
      licence.org_unit_id,
    ].join('|');
    return createHash('sha256').update(material).digest('hex');
  }

  /**
   * Which statutory references the trade holds have already lapsed. A licence
   * resting on an expired fire NOC is a finding waiting to happen, so this is
   * surfaced rather than left for someone to notice.
   */
  private expiredReferences(licence: LicenceWithRelations, on = new Date()) {
    const lapsed: string[] = [];
    if (licence.fssai_expiry && licence.fssai_expiry < on) lapsed.push('FSSAI');
    if (licence.fire_noc_expiry && licence.fire_noc_expiry < on) {
      lapsed.push('Fire NOC');
    }
    if (licence.pollution_consent_expiry && licence.pollution_consent_expiry < on) {
      lapsed.push('Pollution board consent');
    }
    return lapsed;
  }

  /** What stands between this licence and approval or renewal. */
  private readiness(licence: LicenceWithRelations) {
    const total = this.num(licence.total_fee) ?? 0;
    const paid = this.num(licence.paid_amount) ?? 0;
    const feePaid = licence.payment_status === 'paid';
    const needsInspection = requiresAnnualInspection(licence.trade_category);
    const hasCompliantInspection = licence.inspections.some(
      (i) => i.status === 'completed' && i.is_compliant === true,
    );
    const expiredRefs = this.expiredReferences(licence);

    const blockers: string[] = [];
    if (!feePaid) blockers.push(`₹${total - paid} of fees unpaid`);
    if (needsInspection && !hasCompliantInspection) {
      blockers.push('No compliant premises inspection on record');
    }
    if (expiredRefs.length) {
      blockers.push(`Lapsed statutory reference: ${expiredRefs.join(', ')}`);
    }

    return {
      fee_paid: feePaid,
      outstanding_amount: Math.max(0, total - paid),
      requires_inspection: needsInspection,
      has_compliant_inspection: hasCompliantInspection,
      expired_references: expiredRefs,
      blockers,
      can_approve:
        blockers.length === 0 &&
        (licence.status === 'SUBMITTED' || licence.status === 'INSPECTION'),
    };
  }

  private feesFor(
    licence: { trade_category: string; area_sqft: any; motive_power_hp: any },
    quarters: number,
    penaltyPct = 0,
  ) {
    return computeLicenceFee({
      trade_category: licence.trade_category,
      area_sqft: this.num(licence.area_sqft) ?? 0,
      motive_power_hp: this.num(licence.motive_power_hp),
      quarters,
      penaltyPct,
    });
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  async list(tenantId: string, query: ListTradeLicencesDto) {
    const now = new Date();
    const where: Prisma.TradeLicenceWhereInput = {
      tenant_id: tenantId,
      ...(query.org_unit_id !== undefined && { org_unit_id: query.org_unit_id }),
      ...(query.status && {
        status: query.status.toUpperCase() as TradeLicenceStatus,
      }),
      ...(query.trade_category && { trade_category: query.trade_category }),
      ...(query.ward_number && { ward_number: query.ward_number }),
      ...(query.expiring_within_days !== undefined && {
        status: 'APPROVED' as TradeLicenceStatus,
        valid_until: {
          gte: now,
          lte: new Date(
            now.getTime() + query.expiring_within_days * 86_400_000,
          ),
        },
      }),
      ...(query.overdue_only && {
        valid_until: { lt: now },
        status: { in: ['APPROVED', 'EXPIRED'] as TradeLicenceStatus[] },
      }),
      ...(query.q && {
        OR: [
          { licence_number: { contains: query.q, mode: 'insensitive' } },
          { trade_name: { contains: query.q, mode: 'insensitive' } },
          { owner_name: { contains: query.q, mode: 'insensitive' } },
          { door_number: { contains: query.q, mode: 'insensitive' } },
          { survey_number: { contains: query.q, mode: 'insensitive' } },
          { owner_phone: { contains: query.q } },
        ],
      }),
    };

    const [rows, total] = await Promise.all([
      this.prisma.tradeLicence.findMany({
        where,
        include: {
          org_unit: { select: { id: true, name: true } },
          _count: { select: { renewals: true, inspections: true } },
        },
        orderBy: [{ valid_until: 'asc' }, { id: 'desc' }],
        take: query.take ?? 50,
        skip: query.skip ?? 0,
      }),
      this.prisma.tradeLicence.count({ where }),
    ]);

    return { total, items: rows.map((r) => this.serialize(r)) };
  }

  async getById(tenantId: string, id: number) {
    const licence = await this.prisma.tradeLicence.findFirst({
      where: { id, tenant_id: tenantId },
      include: {
        org_unit: { select: { id: true, name: true } },
        renewals: { orderBy: { licence_year: 'desc' } },
        inspections: { orderBy: { scheduled_for: 'desc' } },
        certificates: { orderBy: { copy_number: 'asc' } },
      },
    });
    if (!licence) throw new NotFoundException(`Trade licence #${id} not found`);

    const [timeline, documents, history] = await Promise.all([
      this.workflow.getTimeline(tenantId, ENTITY_TYPE, id),
      this.documents.getForEntity(tenantId, ENTITY_TYPE, id),
      this.audit.getEntityHistory(tenantId, ENTITY_TYPE, id.toString(), 25),
    ]);

    return {
      ...this.serialize(licence),
      workflow: timeline,
      documents,
      history: history.map((h) => ({ ...h, id: h.id.toString() })),
      readiness: this.readiness(licence as LicenceWithRelations),
    };
  }

  /** Counters for the register header and the renewal board. */
  async summary(tenantId: string, orgUnitId?: number) {
    const now = new Date();
    const in30 = new Date(now.getTime() + 30 * 86_400_000);
    const scope = {
      tenant_id: tenantId,
      ...(orgUnitId !== undefined && { org_unit_id: orgUnitId }),
    };

    const [byStatus, expiringSoon, overdue, collected] = await Promise.all([
      this.prisma.tradeLicence.groupBy({
        by: ['status'],
        where: scope,
        _count: { _all: true },
      }),
      this.prisma.tradeLicence.count({
        where: {
          ...scope,
          status: 'APPROVED',
          valid_until: { gte: now, lte: in30 },
        },
      }),
      this.prisma.tradeLicence.count({
        where: {
          ...scope,
          status: { in: ['APPROVED', 'EXPIRED'] },
          valid_until: { lt: now },
        },
      }),
      this.prisma.tradeLicenceRenewal.aggregate({
        where: {
          licence_year: financialYearOf(now),
          licence: scope,
        },
        _sum: { paid_amount: true },
      }),
    ]);

    const counts = Object.fromEntries(
      byStatus.map((r) => [r.status, r._count._all]),
    ) as Record<string, number>;

    return {
      licence_year: financialYearOf(now),
      total: byStatus.reduce((s, r) => s + r._count._all, 0),
      active: counts.APPROVED ?? 0,
      pending_action: (counts.SUBMITTED ?? 0) + (counts.INSPECTION ?? 0),
      expiring_soon: expiringSoon,
      overdue,
      suspended: counts.SUSPENDED ?? 0,
      fees_collected: this.num(collected._sum.paid_amount) ?? 0,
      by_status: counts,
    };
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  async create(
    tenantId: string,
    orgUnitId: number,
    userId: number,
    dto: CreateTradeLicenceDto,
  ) {
    await this.assertOrgUnit(tenantId, orgUnitId);

    const now = new Date();
    const fyLabel = financialYearOf(now);
    const quarters = quartersRemaining(now, fyLabel);
    const fees = computeLicenceFee({
      trade_category: dto.trade_category,
      area_sqft: dto.area_sqft,
      motive_power_hp: dto.motive_power_hp,
      quarters,
    });

    const licenceNumber = await this.numbers.next(
      tenantId,
      LICENCE_SEQUENCE,
      orgUnitId,
    );

    const licence = await this.prisma.tradeLicence.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        licence_number: licenceNumber,
        status: 'DRAFT',

        trade_name: dto.trade_name,
        trade_category: dto.trade_category,
        trade_sub_category: dto.trade_sub_category ?? null,
        description: dto.description ?? null,
        motive_power_hp: dto.motive_power_hp ?? null,
        worker_count: dto.worker_count ?? null,
        operating_hours: dto.operating_hours ?? null,

        owner_name: dto.owner_name,
        ownership_type: (dto.ownership_type ?? 'PROPRIETOR') as OwnershipType,
        signatory_name: dto.signatory_name ?? null,
        owner_phone: dto.owner_phone ?? null,
        owner_email: dto.owner_email ?? null,
        owner_address: dto.owner_address ?? null,
        owner_aadhaar: this.maskAadhaar(dto.owner_aadhaar),

        door_number: dto.door_number ?? null,
        street_name: dto.street_name ?? null,
        ward_number: dto.ward_number ?? null,
        survey_number: dto.survey_number ?? null,
        area_sqft: dto.area_sqft,
        is_rented: dto.is_rented ?? false,
        landlord_name: dto.landlord_name ?? null,
        rent_agreement_ref: dto.rent_agreement_ref ?? null,
        latitude: dto.latitude ?? null,
        longitude: dto.longitude ?? null,

        fssai_number: dto.fssai_number ?? null,
        fssai_expiry: dto.fssai_expiry ? new Date(dto.fssai_expiry) : null,
        gst_number: dto.gst_number ?? null,
        fire_noc_ref: dto.fire_noc_ref ?? null,
        fire_noc_expiry: dto.fire_noc_expiry
          ? new Date(dto.fire_noc_expiry)
          : null,
        pollution_consent_ref: dto.pollution_consent_ref ?? null,
        pollution_consent_expiry: dto.pollution_consent_expiry
          ? new Date(dto.pollution_consent_expiry)
          : null,

        licence_year: fyLabel,
        base_fee: fees.base_fee,
        area_fee: fees.area_fee,
        power_fee: fees.power_fee,
        total_fee: fees.total_fee,

        created_by: userId,
      },
      include: { renewals: true, inspections: true, certificates: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: licence.id.toString(),
      action: 'create',
      afterValue: {
        licence_number: licenceNumber,
        trade_name: dto.trade_name,
        trade_category: dto.trade_category,
        licence_year: fyLabel,
        quarters_charged: quarters,
        total_fee: fees.total_fee,
      },
    });

    this.logger.log(
      `Created trade licence ${licenceNumber} (${quarters}/4 of ${fyLabel})`,
    );
    return this.serialize(licence);
  }

  async update(
    tenantId: string,
    id: number,
    userId: number,
    dto: UpdateTradeLicenceDto,
  ) {
    const before = await this.findOwned(tenantId, id);

    if (!EDITABLE_STATUSES.includes(before.status)) {
      throw new BadRequestException(
        `A licence in ${before.status} cannot be edited. Return it to draft first.`,
      );
    }

    const affectsFees =
      dto.area_sqft !== undefined || dto.motive_power_hp !== undefined;

    const fees = affectsFees
      ? this.feesFor(
          {
            trade_category: before.trade_category,
            area_sqft: dto.area_sqft ?? before.area_sqft,
            motive_power_hp: dto.motive_power_hp ?? before.motive_power_hp,
          },
          quartersRemaining(new Date(), before.licence_year ?? financialYearOf(new Date())),
        )
      : null;

    const after = await this.prisma.tradeLicence.update({
      where: { id },
      data: {
        ...(dto.trade_name !== undefined && { trade_name: dto.trade_name }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.motive_power_hp !== undefined && {
          motive_power_hp: dto.motive_power_hp,
        }),
        ...(dto.worker_count !== undefined && { worker_count: dto.worker_count }),
        ...(dto.owner_name !== undefined && { owner_name: dto.owner_name }),
        ...(dto.owner_phone !== undefined && { owner_phone: dto.owner_phone }),
        ...(dto.owner_email !== undefined && { owner_email: dto.owner_email }),
        ...(dto.owner_address !== undefined && {
          owner_address: dto.owner_address,
        }),
        ...(dto.area_sqft !== undefined && { area_sqft: dto.area_sqft }),
        ...(dto.fire_noc_ref !== undefined && { fire_noc_ref: dto.fire_noc_ref }),
        ...(dto.fire_noc_expiry !== undefined && {
          fire_noc_expiry: new Date(dto.fire_noc_expiry),
        }),
        ...(dto.fssai_number !== undefined && { fssai_number: dto.fssai_number }),
        ...(dto.fssai_expiry !== undefined && {
          fssai_expiry: new Date(dto.fssai_expiry),
        }),
        ...(fees && {
          base_fee: fees.base_fee,
          area_fee: fees.area_fee,
          power_fee: fees.power_fee,
          total_fee: fees.total_fee,
        }),
      },
      include: { renewals: true, inspections: true, certificates: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: before.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'update',
      beforeValue: this.serialize(before),
      afterValue: this.serialize(after),
      changedFields: AuditService.diffFields(
        this.serialize(before),
        this.serialize(after),
      ),
    });

    return this.serialize(after);
  }

  /** Lodge the application: starts the approval chain and the decision SLA. */
  async submit(tenantId: string, id: number, userId: number) {
    const licence = await this.findOwned(tenantId, id);
    this.assertTransition(licence.status, 'SUBMITTED');

    const updated = await this.prisma.tradeLicence.update({
      where: { id },
      data: { status: 'SUBMITTED', submitted_at: new Date() },
      include: { renewals: true, inspections: true, certificates: true },
    });

    const instance = await this.workflow.startWorkflow(
      tenantId,
      licence.org_unit_id,
      WORKFLOW_TEMPLATE,
      ENTITY_TYPE,
      id,
    );
    if (!instance) {
      this.logger.warn(
        `Licence #${id} submitted without an approval chain — no published "${WORKFLOW_TEMPLATE}" template for org unit ${licence.org_unit_id}`,
      );
    }

    await this.sla.startTracker(
      tenantId,
      licence.org_unit_id,
      ENTITY_TYPE,
      id,
      licence.trade_category,
      'medium',
    );

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'submit',
      beforeValue: { status: licence.status },
      afterValue: {
        status: 'SUBMITTED',
        workflow_instance_id: instance?.id ?? null,
      },
      changedFields: ['status'],
    });

    return this.serialize(updated);
  }

  // ── Inspections ───────────────────────────────────────────────────────────

  async scheduleInspection(
    tenantId: string,
    id: number,
    userId: number,
    dto: ScheduleLicenceInspectionDto,
  ) {
    const licence = await this.findOwned(tenantId, id);

    const scheduledFor = new Date(dto.scheduled_for);
    if (Number.isNaN(scheduledFor.getTime())) {
      throw new BadRequestException('scheduled_for is not a valid date');
    }

    const inspection = await this.prisma.tradeLicenceInspection.create({
      data: {
        licence_id: id,
        inspection_type: dto.inspection_type,
        scheduled_for: scheduledFor,
        inspector_user_id: dto.inspector_user_id ?? null,
      },
    });

    // Moving to INSPECTION is only meaningful from SUBMITTED; scheduling a
    // complaint-driven visit against a live licence must not reopen it.
    if (licence.status === 'SUBMITTED') {
      await this.prisma.tradeLicence.update({
        where: { id },
        data: { status: 'INSPECTION' },
      });
    }

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'inspection_scheduled',
      afterValue: {
        inspection_id: inspection.id,
        inspection_type: dto.inspection_type,
        scheduled_for: scheduledFor.toISOString(),
      },
    });

    return inspection;
  }

  async recordInspection(
    tenantId: string,
    id: number,
    inspectionId: number,
    userId: number,
    dto: RecordLicenceInspectionDto,
  ) {
    const licence = await this.findOwned(tenantId, id);
    const inspection = licence.inspections.find((i) => i.id === inspectionId);
    if (!inspection) {
      throw new NotFoundException(
        `Inspection #${inspectionId} is not on licence #${id}`,
      );
    }
    if (inspection.status === 'completed') {
      throw new BadRequestException(
        'This inspection is already recorded. Schedule a re-inspection instead of overwriting the finding.',
      );
    }

    const updated = await this.prisma.tradeLicenceInspection.update({
      where: { id: inspectionId },
      data: {
        status: 'completed',
        is_compliant: dto.is_compliant,
        findings: dto.findings ?? null,
        violations: dto.violations ?? [],
        latitude: dto.latitude ?? null,
        longitude: dto.longitude ?? null,
        inspector_user_id: inspection.inspector_user_id ?? userId,
        inspected_at: new Date(),
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'inspection_recorded',
      afterValue: {
        inspection_id: inspectionId,
        is_compliant: dto.is_compliant,
        violations: dto.violations ?? [],
      },
    });

    return updated;
  }

  // ── Fees ──────────────────────────────────────────────────────────────────

  async recordPayment(
    tenantId: string,
    id: number,
    userId: number,
    dto: RecordLicencePaymentDto,
  ) {
    const licence = await this.findOwned(tenantId, id);

    const total = this.num(licence.total_fee) ?? 0;
    const alreadyPaid = this.num(licence.paid_amount) ?? 0;
    const newPaid = alreadyPaid + dto.amount;

    if (newPaid > total) {
      throw new BadRequestException(
        `Payment of ₹${dto.amount} exceeds the outstanding ₹${total - alreadyPaid}`,
      );
    }

    const paymentStatus = newPaid >= total ? 'paid' : 'partial';

    const updated = await this.prisma.tradeLicence.update({
      where: { id },
      data: {
        paid_amount: newPaid,
        payment_status: paymentStatus,
        payment_ref: dto.payment_ref ?? licence.payment_ref,
        ...(paymentStatus === 'paid' && { paid_at: new Date() }),
      },
      include: { renewals: true, inspections: true, certificates: true },
    });

    // Keep the current licence year's renewal row in step, so the annual
    // collection report does not have to reconcile two sources.
    if (licence.licence_year) {
      await this.prisma.tradeLicenceRenewal.updateMany({
        where: { licence_id: id, licence_year: licence.licence_year },
        data: { paid_amount: newPaid, payment_ref: dto.payment_ref ?? undefined },
      });
    }

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'payment_recorded',
      beforeValue: {
        paid_amount: alreadyPaid,
        payment_status: licence.payment_status,
      },
      afterValue: { paid_amount: newPaid, payment_status: paymentStatus },
      changedFields: ['paid_amount', 'payment_status'],
    });

    return this.serialize(updated);
  }

  // ── Decisions ─────────────────────────────────────────────────────────────

  /**
   * Grant the licence for the current financial year and open the renewal
   * chain with an initial-grant row.
   */
  async approve(
    tenantId: string,
    id: number,
    userId: number,
    dto: ApproveLicenceDto,
  ) {
    const licence = await this.findOwned(tenantId, id);
    this.assertTransition(licence.status, 'APPROVED');

    const readiness = this.readiness(licence);
    if (readiness.blockers.length) {
      throw new BadRequestException(
        `Cannot approve: ${readiness.blockers.join('; ')}`,
      );
    }

    const now = new Date();
    const fyLabel = licence.licence_year ?? financialYearOf(now);
    const validFrom = now > financialYearStart(fyLabel) ? now : financialYearStart(fyLabel);
    const validUntil = financialYearEnd(fyLabel);

    const updated = await this.prisma.tradeLicence.update({
      where: { id },
      data: {
        status: 'APPROVED',
        approved_by: userId,
        approved_at: now,
        licence_year: fyLabel,
        valid_from: validFrom,
        valid_until: validUntil,
        renewals: {
          create: {
            licence_year: fyLabel,
            valid_from: validFrom,
            valid_until: validUntil,
            days_late: 0,
            penalty_band: 'ontime',
            base_fee: licence.base_fee,
            area_fee: licence.area_fee,
            power_fee: licence.power_fee,
            penalty_fee: licence.penalty_fee,
            total_fee: licence.total_fee,
            paid_amount: licence.paid_amount,
            payment_ref: licence.payment_ref,
            is_initial_grant: true,
            renewed_by: userId,
          },
        },
      },
      include: { renewals: true, inspections: true, certificates: true },
    });

    await this.closeSla(tenantId, id);

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'approve',
      beforeValue: { status: licence.status },
      afterValue: {
        status: 'APPROVED',
        licence_year: fyLabel,
        valid_until: validUntil.toISOString().slice(0, 10),
        remarks: dto.remarks ?? null,
      },
      changedFields: ['status', 'valid_until'],
    });

    this.logger.log(
      `Granted ${licence.licence_number} for ${fyLabel}, valid to ${validUntil.toISOString().slice(0, 10)}`,
    );
    return this.serialize(updated);
  }

  async reject(
    tenantId: string,
    id: number,
    userId: number,
    dto: RejectLicenceDto,
  ) {
    const licence = await this.findOwned(tenantId, id);
    this.assertTransition(licence.status, 'REJECTED');

    const updated = await this.prisma.tradeLicence.update({
      where: { id },
      data: { status: 'REJECTED', rejection_reason: dto.reason },
      include: { renewals: true, inspections: true, certificates: true },
    });

    await this.closeSla(tenantId, id);

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'reject',
      beforeValue: { status: licence.status },
      afterValue: { status: 'REJECTED', rejection_reason: dto.reason },
      changedFields: ['status', 'rejection_reason'],
    });

    return this.serialize(updated);
  }

  /**
   * Renew into the next licence year.
   *
   * The year, dates and penalty are all derived from the current validity — a
   * caller cannot choose which year to renew into. Beyond the lapse window the
   * renewal is refused outright and a fresh application is required.
   */
  async renew(
    tenantId: string,
    id: number,
    userId: number,
    dto: RenewLicenceDto,
  ) {
    const licence = await this.findOwned(tenantId, id);

    if (licence.status !== 'APPROVED' && licence.status !== 'EXPIRED') {
      throw new BadRequestException(
        `Only a granted licence can be renewed — this one is ${licence.status}`,
      );
    }
    if (!licence.valid_until || !licence.licence_year) {
      throw new BadRequestException(
        'This licence has no current validity to renew from',
      );
    }

    const now = new Date();
    const assessment = assessRenewal(licence.valid_until, now);
    if (assessment.requiresFreshApplication) {
      throw new BadRequestException(assessment.reason);
    }

    const nextYear = nextFinancialYear(licence.licence_year);
    const existing = licence.renewals.find((r) => r.licence_year === nextYear);
    if (existing) {
      throw new BadRequestException(
        `This licence is already renewed for ${nextYear}`,
      );
    }

    // A renewal is always a full year — the pro-rata only applies to a first
    // grant part-way through a year.
    const fees = this.feesFor(licence, 4, assessment.penaltyPct);
    const validFrom = financialYearStart(nextYear);
    const validUntil = financialYearEnd(nextYear);

    const updated = await this.prisma.tradeLicence.update({
      where: { id },
      data: {
        status: 'APPROVED',
        licence_year: nextYear,
        valid_from: validFrom,
        valid_until: validUntil,
        base_fee: fees.base_fee,
        area_fee: fees.area_fee,
        power_fee: fees.power_fee,
        penalty_fee: fees.penalty_fee,
        total_fee: fees.total_fee,
        // A new licence year is a new demand: the previous year's payment does
        // not carry over.
        paid_amount: 0,
        payment_status: 'unpaid',
        payment_ref: null,
        paid_at: null,
        renewals: {
          create: {
            licence_year: nextYear,
            valid_from: validFrom,
            valid_until: validUntil,
            days_late: assessment.daysLate,
            penalty_band: assessment.band,
            base_fee: fees.base_fee,
            area_fee: fees.area_fee,
            power_fee: fees.power_fee,
            penalty_fee: fees.penalty_fee,
            total_fee: fees.total_fee,
            paid_amount: 0,
            renewed_by: userId,
          },
        },
      },
      include: { renewals: true, inspections: true, certificates: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'renew',
      beforeValue: { licence_year: licence.licence_year },
      afterValue: {
        licence_year: nextYear,
        days_late: assessment.daysLate,
        penalty_band: assessment.band,
        total_fee: fees.total_fee,
        remarks: dto.remarks ?? null,
      },
      changedFields: ['licence_year', 'valid_until', 'total_fee'],
    });

    this.logger.log(
      `Renewed ${licence.licence_number} into ${nextYear} (${assessment.band})`,
    );
    return {
      ...this.serialize(updated),
      renewal_assessment: assessment,
    };
  }

  async suspend(
    tenantId: string,
    id: number,
    userId: number,
    dto: SuspendLicenceDto,
  ) {
    const licence = await this.findOwned(tenantId, id);
    this.assertTransition(licence.status, 'SUSPENDED');

    const updated = await this.prisma.tradeLicence.update({
      where: { id },
      data: {
        status: 'SUSPENDED',
        suspension_reason: dto.reason,
        suspended_at: new Date(),
      },
      include: { renewals: true, inspections: true, certificates: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'suspend',
      beforeValue: { status: licence.status },
      afterValue: { status: 'SUSPENDED', suspension_reason: dto.reason },
      changedFields: ['status'],
    });

    return this.serialize(updated);
  }

  /** Lift a suspension, returning the licence to service for its current year. */
  async restore(tenantId: string, id: number, userId: number) {
    const licence = await this.findOwned(tenantId, id);
    if (licence.status !== 'SUSPENDED') {
      throw new BadRequestException(
        `Only a suspended licence can be restored — this one is ${licence.status}`,
      );
    }

    const expired = licence.valid_until && licence.valid_until < new Date();

    const updated = await this.prisma.tradeLicence.update({
      where: { id },
      data: {
        // Restoring past the year end returns it to EXPIRED, not to service —
        // the suspension ending does not extend the licence year.
        status: expired ? 'EXPIRED' : 'APPROVED',
        suspension_reason: null,
        suspended_at: null,
      },
      include: { renewals: true, inspections: true, certificates: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'restore',
      beforeValue: { status: 'SUSPENDED' },
      afterValue: { status: expired ? 'EXPIRED' : 'APPROVED' },
      changedFields: ['status'],
    });

    return this.serialize(updated);
  }

  async cancel(
    tenantId: string,
    id: number,
    userId: number,
    dto: CancelLicenceDto,
  ) {
    const licence = await this.findOwned(tenantId, id);
    this.assertTransition(licence.status, 'CANCELLED');

    const updated = await this.prisma.tradeLicence.update({
      where: { id },
      data: {
        status: 'CANCELLED',
        cancelled_reason: dto.reason,
        cancelled_at: new Date(),
      },
      include: { renewals: true, inspections: true, certificates: true },
    });

    // A cancelled licence must not leave a valid certificate in a shop window.
    const live = licence.certificates.filter((c) => !c.is_cancelled);
    if (live.length) {
      await this.prisma.tradeLicenceCertificate.updateMany({
        where: { id: { in: live.map((c) => c.id) } },
        data: {
          is_cancelled: true,
          cancelled_reason: 'Licence cancelled',
          cancelled_at: new Date(),
        },
      });
    }

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'cancel',
      beforeValue: { status: licence.status },
      afterValue: {
        status: 'CANCELLED',
        cancelled_reason: dto.reason,
        certificates_cancelled: live.length,
      },
      changedFields: ['status'],
    });

    return { ...this.serialize(updated), cancelled_certificates: live.length };
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

  async issueCertificate(
    tenantId: string,
    id: number,
    userId: number,
    _dto: IssueLicenceCertificateDto,
  ) {
    const licence = await this.findOwned(tenantId, id);

    if (licence.status !== 'APPROVED') {
      throw new BadRequestException(
        `A certificate can only be issued against a granted licence — this one is ${licence.status}`,
      );
    }
    if (!licence.licence_year) {
      throw new BadRequestException('This licence has no licence year set');
    }

    const certificateNumber = await this.numbers.next(
      tenantId,
      CERTIFICATE_SEQUENCE,
      licence.org_unit_id,
    );
    const sameYear = licence.certificates.filter(
      (c) => c.licence_year === licence.licence_year,
    );
    const nextCopy =
      sameYear.reduce((max, c) => Math.max(max, c.copy_number), 0) + 1;

    const certificate = await this.prisma.tradeLicenceCertificate.create({
      data: {
        licence_id: id,
        licence_year: licence.licence_year,
        certificate_number: certificateNumber,
        verification_token: randomBytes(24).toString('base64url'),
        copy_number: nextCopy,
        seal_hash: this.sealHash(licence, certificateNumber),
        issued_by: userId,
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: licence.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'certificate_issued',
      afterValue: {
        certificate_number: certificateNumber,
        licence_year: licence.licence_year,
        copy_number: nextCopy,
      },
    });

    return certificate;
  }

  /**
   * Public verification behind the QR printed on the licence displayed in the
   * shop. Returns only what a verifier needs — never the owner's contact
   * details, Aadhaar fragment or fee history.
   */
  async verifyByToken(token: string) {
    const certificate = await this.prisma.tradeLicenceCertificate.findUnique({
      where: { verification_token: token },
      include: {
        licence: {
          include: { org_unit: { select: { name: true } } },
        },
      },
    });

    if (!certificate) {
      throw new NotFoundException('This verification code is not recognised');
    }

    const licence = certificate.licence;
    const now = new Date();
    const withinValidity = licence.valid_until ? licence.valid_until >= now : false;
    const live = licence.status === 'APPROVED' && withinValidity;

    return {
      valid: !certificate.is_cancelled && live,
      cancelled_reason: certificate.cancelled_reason,
      status: licence.status,
      /// Distinguishes "this document is fake" from "this shop's licence lapsed".
      lapsed: !withinValidity && licence.status !== 'CANCELLED',
      certificate_number: certificate.certificate_number,
      licence_number: licence.licence_number,
      licence_year: certificate.licence_year,
      copy_number: certificate.copy_number,
      seal_hash: certificate.seal_hash,
      issued_at: certificate.issued_at,

      trade_name: licence.trade_name,
      trade_category: licence.trade_category,
      owner_name: licence.owner_name,
      premises: [licence.door_number, licence.street_name, licence.ward_number]
        .filter(Boolean)
        .join(', '),
      valid_from: licence.valid_from,
      valid_until: licence.valid_until,
      issuing_authority: licence.org_unit.name,
    };
  }

  // ── Scheduled maintenance ─────────────────────────────────────────────────

  /**
   * Expire licences whose year has run out.
   *
   * This is the sweep that turns a silent lapse into a visible one — without
   * it, an unrenewed licence sits in APPROVED forever and never appears on the
   * renewal board.
   */
  @Cron(CronExpression.EVERY_DAY_AT_2AM)
  async expireLapsedLicences() {
    const now = new Date();
    const lapsed = await this.prisma.tradeLicence.findMany({
      where: { status: 'APPROVED', valid_until: { lt: now } },
      select: {
        id: true,
        tenant_id: true,
        org_unit_id: true,
        licence_number: true,
        licence_year: true,
      },
    });

    if (lapsed.length === 0) return { expired: 0 };

    await this.prisma.tradeLicence.updateMany({
      where: { id: { in: lapsed.map((l) => l.id) } },
      data: { status: 'EXPIRED' },
    });

    for (const licence of lapsed) {
      await this.audit.log({
        tenantId: licence.tenant_id,
        orgUnitId: licence.org_unit_id,
        module: MODULE,
        entityType: ENTITY_TYPE,
        entityId: licence.id.toString(),
        action: 'expire',
        afterValue: {
          status: 'EXPIRED',
          licence_number: licence.licence_number,
          licence_year: licence.licence_year,
        },
        changedFields: ['status'],
      });
    }

    this.logger.log(`Expired ${lapsed.length} trade licence(s)`);
    return { expired: lapsed.length };
  }
}
