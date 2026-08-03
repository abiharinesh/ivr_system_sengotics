import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { BuildingPermitStatus, NocStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { DocumentService } from '../core/document/document.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { SlaService } from '../core/sla/sla.service';
import { WorkflowService } from '../core/workflow/workflow.service';
import { computePermitFees } from './building-permit.fees';
import type {
  AddNocDto,
  ApprovePermitDto,
  CreateBuildingPermitDto,
  ListBuildingPermitsDto,
  RecordInspectionDto,
  RecordPaymentDto,
  RejectPermitDto,
  ScheduleInspectionDto,
  UpdateBuildingPermitDto,
  UpdateNocDto,
} from './dto/building-permit.dto';

/** Audit/workflow/SLA/document key for this entity. Keep these in one place. */
const ENTITY_TYPE = 'building_permit';
const MODULE = 'building_permits';
const WORKFLOW_TEMPLATE = 'building_permit_approval';
const SEQUENCE_ENTITY = 'permit';

/** Default validity of an approved permit, in months. */
const DEFAULT_VALIDITY_MONTHS = 36;

/**
 * Which clearances each kind of proposal needs when the applicant doesn't
 * specify. A council can override per application; this is only the starting
 * checklist so a clerk isn't building it by hand every time.
 */
const DEFAULT_NOCS: Record<string, string[]> = {
  residential: ['water', 'electricity'],
  commercial: ['fire', 'traffic', 'electricity', 'water', 'health'],
  industrial: ['fire', 'pollution', 'electricity', 'water', 'highways'],
  institutional: ['fire', 'traffic', 'electricity', 'water', 'health'],
  mixed: ['fire', 'traffic', 'electricity', 'water'],
};

/**
 * Legal status transitions. Anything not listed is rejected — a permit file
 * that jumps from SUBMITTED straight to APPROVED is the exact audit finding
 * this module exists to prevent.
 */
const ALLOWED_TRANSITIONS: Record<BuildingPermitStatus, BuildingPermitStatus[]> = {
  DRAFT: ['SUBMITTED', 'CANCELLED'],
  SUBMITTED: ['SCRUTINY', 'RETURNED', 'REJECTED', 'CANCELLED'],
  SCRUTINY: ['NOC_PENDING', 'RETURNED', 'REJECTED'],
  NOC_PENDING: ['INSPECTION', 'RETURNED', 'REJECTED'],
  INSPECTION: ['APPROVED', 'RETURNED', 'REJECTED'],
  RETURNED: ['SUBMITTED', 'CANCELLED'],
  APPROVED: ['EXPIRED'],
  REJECTED: [],
  CANCELLED: [],
  EXPIRED: [],
} as Record<BuildingPermitStatus, BuildingPermitStatus[]>;

/** Statuses in which an applicant may still edit the particulars. */
const EDITABLE_STATUSES: BuildingPermitStatus[] = ['DRAFT', 'RETURNED'];

type PermitWithRelations = Prisma.BuildingPermitGetPayload<{
  include: { nocs: true; inspections: true };
}>;

@Injectable()
export class BuildingPermitService {
  private readonly logger = new Logger(BuildingPermitService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly numbers: NumberGenService,
    private readonly workflow: WorkflowService,
    private readonly sla: SlaService,
    private readonly audit: AuditService,
    private readonly documents: DocumentService,
  ) {}

  // ── Serialisation ─────────────────────────────────────────────────────────

  /**
   * Prisma returns `Decimal` for money and area columns, which `JSON.stringify`
   * renders as a string. Converting here keeps the numeric contract in one
   * place instead of every client having to `double.parse` defensively.
   */
  private num(value: Prisma.Decimal | number | null | undefined): number | null {
    if (value === null || value === undefined) return null;
    return typeof value === 'number' ? value : Number(value.toString());
  }

  private serialize(permit: PermitWithRelations | any) {
    return {
      ...permit,
      plot_area_sqm: this.num(permit.plot_area_sqm),
      built_up_area_sqm: this.num(permit.built_up_area_sqm),
      height_m: this.num(permit.height_m),
      setback_front_m: this.num(permit.setback_front_m),
      setback_rear_m: this.num(permit.setback_rear_m),
      setback_left_m: this.num(permit.setback_left_m),
      setback_right_m: this.num(permit.setback_right_m),
      estimated_cost: this.num(permit.estimated_cost),
      scrutiny_fee: this.num(permit.scrutiny_fee),
      permit_fee: this.num(permit.permit_fee),
      development_fee: this.num(permit.development_fee),
      total_fee: this.num(permit.total_fee),
      paid_amount: this.num(permit.paid_amount),
    };
  }

  // ── Guards & helpers ──────────────────────────────────────────────────────

  /**
   * Load a permit and prove it belongs to the caller's tenant. Every mutation
   * goes through this — an `id` in a URL is not authority to touch a row.
   */
  private async findOwned(
    tenantId: string,
    id: number,
    include: Prisma.BuildingPermitInclude = { nocs: true, inspections: true },
  ): Promise<PermitWithRelations> {
    const permit = await this.prisma.buildingPermit.findFirst({
      where: { id, tenant_id: tenantId },
      include,
    });
    if (!permit) throw new NotFoundException(`Building permit #${id} not found`);
    return permit as PermitWithRelations;
  }

  private assertTransition(from: BuildingPermitStatus, to: BuildingPermitStatus) {
    const allowed = ALLOWED_TRANSITIONS[from] ?? [];
    if (!allowed.includes(to)) {
      throw new BadRequestException(
        `Cannot move a permit from ${from} to ${to}` +
          (allowed.length
            ? `. Allowed from ${from}: ${allowed.join(', ')}`
            : `. ${from} is a terminal state.`),
      );
    }
  }

  /** Store only the last four digits — the rest is never needed after intake. */
  private maskAadhaar(aadhaar?: string): string | null {
    if (!aadhaar) return null;
    return `XXXXXXXX${aadhaar.slice(-4)}`;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  async list(tenantId: string, query: ListBuildingPermitsDto) {
    const where: Prisma.BuildingPermitWhereInput = {
      tenant_id: tenantId,
      ...(query.org_unit_id !== undefined && { org_unit_id: query.org_unit_id }),
      ...(query.status && {
        status: query.status.toUpperCase() as BuildingPermitStatus,
      }),
      ...(query.construction_type && { construction_type: query.construction_type }),
      ...(query.q && {
        OR: [
          { permit_number: { contains: query.q, mode: 'insensitive' } },
          { applicant_name: { contains: query.q, mode: 'insensitive' } },
          { survey_number: { contains: query.q, mode: 'insensitive' } },
          { door_number: { contains: query.q, mode: 'insensitive' } },
        ],
      }),
    };

    const [rows, total] = await Promise.all([
      this.prisma.buildingPermit.findMany({
        where,
        include: {
          org_unit: { select: { id: true, name: true } },
          nocs: { select: { id: true, department: true, status: true, is_mandatory: true } },
          _count: { select: { inspections: true } },
        },
        orderBy: { created_at: 'desc' },
        take: query.take ?? 50,
        skip: query.skip ?? 0,
      }),
      this.prisma.buildingPermit.count({ where }),
    ]);

    return {
      total,
      items: rows.map((r) => this.serialize(r)),
    };
  }

  /**
   * Full permit file: particulars, NOC checklist, inspections, the approval
   * chain from the workflow engine, the live SLA clock, and every uploaded
   * blueprint or clearance letter.
   */
  async getById(tenantId: string, id: number) {
    const permit = await this.prisma.buildingPermit.findFirst({
      where: { id, tenant_id: tenantId },
      include: {
        org_unit: { select: { id: true, name: true } },
        nocs: { orderBy: { department: 'asc' } },
        inspections: { orderBy: { scheduled_for: 'desc' } },
      },
    });
    if (!permit) throw new NotFoundException(`Building permit #${id} not found`);

    const [timeline, documents, slaTracker, history] = await Promise.all([
      this.workflow.getTimeline(tenantId, ENTITY_TYPE, id),
      this.documents.getForEntity(tenantId, ENTITY_TYPE, id),
      this.prisma.slaTracker.findFirst({
        where: { tenant_id: tenantId, entity_type: ENTITY_TYPE, entity_id: id },
        orderBy: { started_at: 'desc' },
      }),
      this.audit.getEntityHistory(tenantId, ENTITY_TYPE, id.toString(), 25),
    ]);

    return {
      ...this.serialize(permit),
      workflow: timeline,
      documents,
      sla: slaTracker,
      history: history.map((h) => ({ ...h, id: h.id.toString() })),
      readiness: this.readiness(permit as PermitWithRelations),
    };
  }

  /**
   * What still stands between this permit and approval. The detail screen
   * renders this directly, so the officer sees the blockers rather than
   * discovering them by clicking Approve.
   */
  private readiness(permit: PermitWithRelations) {
    const pendingNocs = permit.nocs
      .filter((n) => n.is_mandatory && n.status !== 'GRANTED' && n.status !== 'NOT_APPLICABLE')
      .map((n) => n.department);
    const rejectedNocs = permit.nocs
      .filter((n) => n.status === 'REJECTED')
      .map((n) => n.department);
    const hasCompliantInspection = permit.inspections.some(
      (i) => i.status === 'completed' && i.is_compliant === true,
    );
    const feePaid = permit.payment_status === 'paid';

    return {
      pending_nocs: pendingNocs,
      rejected_nocs: rejectedNocs,
      fee_paid: feePaid,
      outstanding_amount: Math.max(
        0,
        (this.num(permit.total_fee) ?? 0) - (this.num(permit.paid_amount) ?? 0),
      ),
      has_compliant_inspection: hasCompliantInspection,
      can_approve:
        pendingNocs.length === 0 &&
        rejectedNocs.length === 0 &&
        feePaid &&
        hasCompliantInspection &&
        permit.status === 'INSPECTION',
    };
  }

  /** Counters for the list screen's KPI strip. */
  async summary(tenantId: string, orgUnitId?: number) {
    const where: Prisma.BuildingPermitWhereInput = {
      tenant_id: tenantId,
      ...(orgUnitId !== undefined && { org_unit_id: orgUnitId }),
    };

    const [byStatus, revenue, overdue] = await Promise.all([
      this.prisma.buildingPermit.groupBy({
        by: ['status'],
        where,
        _count: { _all: true },
      }),
      this.prisma.buildingPermit.aggregate({
        where: { ...where, payment_status: 'paid' },
        _sum: { paid_amount: true },
      }),
      this.prisma.slaTracker.count({
        where: {
          tenant_id: tenantId,
          entity_type: ENTITY_TYPE,
          status: { in: ['warning', 'escalated', 'breached'] },
          resolved_at: null,
        },
      }),
    ]);

    const counts = Object.fromEntries(
      byStatus.map((row) => [row.status, row._count._all]),
    ) as Record<string, number>;

    return {
      by_status: counts,
      total: byStatus.reduce((sum, row) => sum + row._count._all, 0),
      pending_action:
        (counts.SUBMITTED ?? 0) +
        (counts.SCRUTINY ?? 0) +
        (counts.NOC_PENDING ?? 0) +
        (counts.INSPECTION ?? 0),
      approved: counts.APPROVED ?? 0,
      rejected: counts.REJECTED ?? 0,
      fees_collected: this.num(revenue._sum.paid_amount) ?? 0,
      sla_at_risk: overdue,
    };
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  async create(
    tenantId: string,
    userId: number,
    dto: CreateBuildingPermitDto,
  ) {
    const orgUnit = await this.prisma.orgUnit.findFirst({
      where: { id: dto.org_unit_id, tenant_id: tenantId },
      select: { id: true },
    });
    if (!orgUnit) {
      throw new ForbiddenException(
        `Org unit #${dto.org_unit_id} does not belong to your tenant`,
      );
    }

    if (dto.built_up_area_sqm > dto.plot_area_sqm * (dto.floors_proposed ?? 1)) {
      throw new BadRequestException(
        'Built-up area exceeds what the plot can carry across the proposed floors',
      );
    }

    const permitNumber = await this.numbers.next(
      tenantId,
      SEQUENCE_ENTITY,
      dto.org_unit_id,
    );
    const fees = computePermitFees({
      construction_type: dto.construction_type,
      work_nature: dto.work_nature,
      built_up_area_sqm: dto.built_up_area_sqm,
      plot_area_sqm: dto.plot_area_sqm,
      floors_proposed: dto.floors_proposed,
    });

    const departments =
      dto.noc_departments?.length
        ? dto.noc_departments
        : (DEFAULT_NOCS[dto.construction_type] ?? DEFAULT_NOCS.residential);

    const permit = await this.prisma.buildingPermit.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: dto.org_unit_id,
        permit_number: permitNumber,

        applicant_name: dto.applicant_name,
        applicant_phone: dto.applicant_phone ?? null,
        applicant_email: dto.applicant_email ?? null,
        applicant_address: dto.applicant_address ?? null,
        applicant_aadhaar: this.maskAadhaar(dto.applicant_aadhaar),
        is_owner: dto.is_owner ?? true,
        power_of_attorney: dto.power_of_attorney ?? null,

        survey_number: dto.survey_number,
        subdivision_no: dto.subdivision_no ?? null,
        ward_number: dto.ward_number ?? null,
        street_name: dto.street_name ?? null,
        door_number: dto.door_number ?? null,
        plot_area_sqm: dto.plot_area_sqm,
        latitude: dto.latitude ?? null,
        longitude: dto.longitude ?? null,

        construction_type: dto.construction_type,
        work_nature: dto.work_nature ?? 'new',
        built_up_area_sqm: dto.built_up_area_sqm,
        floors_proposed: dto.floors_proposed ?? 1,
        height_m: dto.height_m ?? null,
        setback_front_m: dto.setback_front_m ?? null,
        setback_rear_m: dto.setback_rear_m ?? null,
        setback_left_m: dto.setback_left_m ?? null,
        setback_right_m: dto.setback_right_m ?? null,
        estimated_cost: dto.estimated_cost ?? null,

        architect_name: dto.architect_name ?? null,
        architect_licence: dto.architect_licence ?? null,

        scrutiny_fee: fees.scrutiny_fee,
        permit_fee: fees.permit_fee,
        development_fee: fees.development_fee,
        total_fee: fees.total_fee,

        status: 'DRAFT',
        created_by: userId,

        nocs: {
          create: departments.map((department) => ({
            department,
            is_mandatory: true,
          })),
        },
      },
      include: { nocs: true, inspections: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: dto.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: permit.id.toString(),
      action: 'create',
      afterValue: {
        permit_number: permit.permit_number,
        applicant_name: permit.applicant_name,
        survey_number: permit.survey_number,
        construction_type: permit.construction_type,
        total_fee: fees.total_fee,
      },
    });

    this.logger.log(`Created building permit ${permit.permit_number} (#${permit.id})`);
    return this.serialize(permit);
  }

  async update(
    tenantId: string,
    id: number,
    userId: number,
    dto: UpdateBuildingPermitDto,
  ) {
    const before = await this.findOwned(tenantId, id);

    if (!EDITABLE_STATUSES.includes(before.status)) {
      throw new BadRequestException(
        `A permit in ${before.status} cannot be edited. Return it to the applicant first.`,
      );
    }

    // Recompute fees when anything they depend on moves.
    const affectsFees =
      dto.construction_type !== undefined ||
      dto.work_nature !== undefined ||
      dto.built_up_area_sqm !== undefined ||
      dto.plot_area_sqm !== undefined ||
      dto.floors_proposed !== undefined;

    const fees = affectsFees
      ? computePermitFees({
          construction_type: dto.construction_type ?? before.construction_type,
          work_nature: dto.work_nature ?? before.work_nature,
          built_up_area_sqm:
            dto.built_up_area_sqm ?? (this.num(before.built_up_area_sqm) ?? 0),
          plot_area_sqm: dto.plot_area_sqm ?? (this.num(before.plot_area_sqm) ?? 0),
          floors_proposed: dto.floors_proposed ?? before.floors_proposed,
        })
      : null;

    const data: Prisma.BuildingPermitUpdateInput = {
      ...(dto.applicant_name !== undefined && { applicant_name: dto.applicant_name }),
      ...(dto.applicant_phone !== undefined && { applicant_phone: dto.applicant_phone }),
      ...(dto.applicant_email !== undefined && { applicant_email: dto.applicant_email }),
      ...(dto.applicant_address !== undefined && {
        applicant_address: dto.applicant_address,
      }),
      ...(dto.ward_number !== undefined && { ward_number: dto.ward_number }),
      ...(dto.street_name !== undefined && { street_name: dto.street_name }),
      ...(dto.door_number !== undefined && { door_number: dto.door_number }),
      ...(dto.plot_area_sqm !== undefined && { plot_area_sqm: dto.plot_area_sqm }),
      ...(dto.construction_type !== undefined && {
        construction_type: dto.construction_type,
      }),
      ...(dto.work_nature !== undefined && { work_nature: dto.work_nature }),
      ...(dto.built_up_area_sqm !== undefined && {
        built_up_area_sqm: dto.built_up_area_sqm,
      }),
      ...(dto.floors_proposed !== undefined && { floors_proposed: dto.floors_proposed }),
      ...(dto.height_m !== undefined && { height_m: dto.height_m }),
      ...(dto.setback_front_m !== undefined && { setback_front_m: dto.setback_front_m }),
      ...(dto.setback_rear_m !== undefined && { setback_rear_m: dto.setback_rear_m }),
      ...(dto.setback_left_m !== undefined && { setback_left_m: dto.setback_left_m }),
      ...(dto.setback_right_m !== undefined && { setback_right_m: dto.setback_right_m }),
      ...(dto.estimated_cost !== undefined && { estimated_cost: dto.estimated_cost }),
      ...(dto.architect_name !== undefined && { architect_name: dto.architect_name }),
      ...(dto.architect_licence !== undefined && {
        architect_licence: dto.architect_licence,
      }),
      ...(fees && {
        scrutiny_fee: fees.scrutiny_fee,
        permit_fee: fees.permit_fee,
        development_fee: fees.development_fee,
        total_fee: fees.total_fee,
      }),
    };

    const after = await this.prisma.buildingPermit.update({
      where: { id },
      data,
      include: { nocs: true, inspections: true },
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

  /**
   * Lodge the application. This is the point the statutory clock starts: the
   * approval chain is instantiated from the workflow template and an SLA
   * tracker begins counting business hours against the council's policy.
   */
  async submit(tenantId: string, id: number, userId: number) {
    const permit = await this.findOwned(tenantId, id);
    this.assertTransition(permit.status, 'SUBMITTED');

    if (permit.nocs.length === 0) {
      throw new BadRequestException(
        'Add at least one department clearance before submitting',
      );
    }

    const updated = await this.prisma.buildingPermit.update({
      where: { id },
      data: { status: 'SUBMITTED', submitted_at: new Date() },
      include: { nocs: true, inspections: true },
    });

    // Both are best-effort: a council that hasn't configured a template or an
    // SLA policy yet should still be able to accept applications.
    const instance = await this.workflow.startWorkflow(
      tenantId,
      permit.org_unit_id,
      WORKFLOW_TEMPLATE,
      ENTITY_TYPE,
      id,
    );
    if (!instance) {
      this.logger.warn(
        `Permit #${id} submitted without an approval chain — no published "${WORKFLOW_TEMPLATE}" template for org unit ${permit.org_unit_id}`,
      );
    }

    await this.sla.startTracker(
      tenantId,
      permit.org_unit_id,
      ENTITY_TYPE,
      id,
      permit.construction_type,
      permit.floors_proposed > 3 ? 'high' : 'medium',
    );

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'submit',
      beforeValue: { status: permit.status },
      afterValue: { status: 'SUBMITTED', workflow_instance_id: instance?.id ?? null },
      changedFields: ['status'],
    });

    return this.serialize(updated);
  }

  /** Move the file along its lifecycle (scrutiny, NOC circulation, site visit). */
  async changeStatus(
    tenantId: string,
    id: number,
    userId: number,
    target: BuildingPermitStatus,
  ) {
    const permit = await this.findOwned(tenantId, id);
    this.assertTransition(permit.status, target);

    if (target === 'APPROVED' || target === 'REJECTED') {
      throw new BadRequestException(
        'Use the approve or reject endpoint — those transitions carry their own checks',
      );
    }

    if (target === 'INSPECTION') {
      const blocking = permit.nocs.filter(
        (n) => n.is_mandatory && n.status !== 'GRANTED' && n.status !== 'NOT_APPLICABLE',
      );
      if (blocking.length > 0) {
        throw new BadRequestException(
          `Clearance still pending from: ${blocking.map((n) => n.department).join(', ')}`,
        );
      }
    }

    const updated = await this.prisma.buildingPermit.update({
      where: { id },
      data: { status: target },
      include: { nocs: true, inspections: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: `status_${target.toLowerCase()}`,
      beforeValue: { status: permit.status },
      afterValue: { status: target },
      changedFields: ['status'],
    });

    return this.serialize(updated);
  }

  // ── NOC clearances ────────────────────────────────────────────────────────

  async addNoc(tenantId: string, id: number, userId: number, dto: AddNocDto) {
    const permit = await this.findOwned(tenantId, id);

    const existing = permit.nocs.find((n) => n.department === dto.department);
    if (existing) {
      throw new BadRequestException(
        `${dto.department} clearance is already on this permit`,
      );
    }

    const noc = await this.prisma.buildingPermitNoc.create({
      data: {
        permit_id: id,
        department: dto.department,
        is_mandatory: dto.is_mandatory ?? true,
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'noc_added',
      afterValue: { department: dto.department, is_mandatory: noc.is_mandatory },
    });

    return noc;
  }

  /**
   * Record a department's decision. When the last mandatory clearance lands,
   * the permit advances itself to INSPECTION — the clerk shouldn't have to
   * notice and click.
   */
  async updateNoc(
    tenantId: string,
    id: number,
    nocId: number,
    userId: number,
    dto: UpdateNocDto,
  ) {
    const permit = await this.findOwned(tenantId, id);
    const noc = permit.nocs.find((n) => n.id === nocId);
    if (!noc) {
      throw new NotFoundException(`Clearance #${nocId} is not on permit #${id}`);
    }

    const cleared = dto.status !== 'PENDING';
    const updatedNoc = await this.prisma.buildingPermitNoc.update({
      where: { id: nocId },
      data: {
        status: dto.status as NocStatus,
        reference_no: dto.reference_no ?? noc.reference_no,
        remarks: dto.remarks ?? noc.remarks,
        cleared_by: cleared ? userId : null,
        cleared_at: cleared ? new Date() : null,
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: `noc_${dto.status.toLowerCase()}`,
      beforeValue: { department: noc.department, status: noc.status },
      afterValue: {
        department: noc.department,
        status: dto.status,
        reference_no: updatedNoc.reference_no,
      },
      changedFields: ['status'],
    });

    // Re-read so the auto-advance decision sees the row we just wrote.
    const refreshed = await this.findOwned(tenantId, id);
    const allCleared = refreshed.nocs
      .filter((n) => n.is_mandatory)
      .every((n) => n.status === 'GRANTED' || n.status === 'NOT_APPLICABLE');

    if (allCleared && refreshed.status === 'NOC_PENDING') {
      await this.changeStatus(tenantId, id, userId, 'INSPECTION');
      this.logger.log(
        `Permit #${id}: all mandatory clearances granted, advanced to INSPECTION`,
      );
    }

    return this.getById(tenantId, id);
  }

  // ── Site inspections ──────────────────────────────────────────────────────

  async scheduleInspection(
    tenantId: string,
    id: number,
    userId: number,
    dto: ScheduleInspectionDto,
  ) {
    const permit = await this.findOwned(tenantId, id);

    const scheduledFor = new Date(dto.scheduled_for);
    if (Number.isNaN(scheduledFor.getTime())) {
      throw new BadRequestException('scheduled_for is not a valid date');
    }

    const inspection = await this.prisma.buildingPermitInspection.create({
      data: {
        permit_id: id,
        inspection_type: dto.inspection_type,
        scheduled_for: scheduledFor,
        inspector_user_id: dto.inspector_user_id ?? null,
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'inspection_scheduled',
      afterValue: {
        inspection_id: inspection.id,
        inspection_type: dto.inspection_type,
        scheduled_for: scheduledFor.toISOString(),
        inspector_user_id: dto.inspector_user_id ?? null,
      },
    });

    return inspection;
  }

  async recordInspection(
    tenantId: string,
    id: number,
    inspectionId: number,
    userId: number,
    dto: RecordInspectionDto,
  ) {
    const permit = await this.findOwned(tenantId, id);
    const inspection = permit.inspections.find((i) => i.id === inspectionId);
    if (!inspection) {
      throw new NotFoundException(
        `Inspection #${inspectionId} is not on permit #${id}`,
      );
    }
    if (inspection.status === 'completed') {
      throw new BadRequestException(
        'This inspection is already recorded. Schedule a fresh visit instead of overwriting the finding.',
      );
    }

    const updated = await this.prisma.buildingPermitInspection.update({
      where: { id: inspectionId },
      data: {
        status: 'completed',
        is_compliant: dto.is_compliant,
        findings: dto.findings ?? null,
        location_lat: dto.location_lat ?? null,
        location_lng: dto.location_lng ?? null,
        gps_accuracy_m: dto.gps_accuracy_m ?? null,
        photos: dto.photos ? (dto.photos as Prisma.InputJsonValue) : undefined,
        inspector_user_id: inspection.inspector_user_id ?? userId,
        inspected_at: new Date(),
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'inspection_recorded',
      afterValue: {
        inspection_id: inspectionId,
        is_compliant: dto.is_compliant,
        findings: dto.findings ?? null,
      },
    });

    return updated;
  }

  // ── Fees ──────────────────────────────────────────────────────────────────

  async recordPayment(
    tenantId: string,
    id: number,
    userId: number,
    dto: RecordPaymentDto,
  ) {
    const permit = await this.findOwned(tenantId, id);

    const total = this.num(permit.total_fee) ?? 0;
    const alreadyPaid = this.num(permit.paid_amount) ?? 0;
    const newPaid = alreadyPaid + dto.amount;

    if (newPaid > total) {
      throw new BadRequestException(
        `Payment of ₹${dto.amount} exceeds the outstanding ₹${total - alreadyPaid}`,
      );
    }

    const paymentStatus = newPaid >= total ? 'paid' : 'partial';

    const updated = await this.prisma.buildingPermit.update({
      where: { id },
      data: {
        paid_amount: newPaid,
        payment_status: paymentStatus,
        payment_ref: dto.payment_ref ?? permit.payment_ref,
        ...(paymentStatus === 'paid' && { paid_at: new Date() }),
      },
      include: { nocs: true, inspections: true },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'payment_recorded',
      beforeValue: { paid_amount: alreadyPaid, payment_status: permit.payment_status },
      afterValue: {
        paid_amount: newPaid,
        payment_status: paymentStatus,
        payment_ref: dto.payment_ref ?? null,
      },
      changedFields: ['paid_amount', 'payment_status'],
    });

    return this.serialize(updated);
  }

  // ── Decision ──────────────────────────────────────────────────────────────

  /**
   * Sanction the permit. Refuses unless every mandatory clearance is in, the
   * fee is fully paid, and a site inspection has come back compliant.
   */
  async approve(
    tenantId: string,
    id: number,
    userId: number,
    dto: ApprovePermitDto,
  ) {
    const permit = await this.findOwned(tenantId, id);
    this.assertTransition(permit.status, 'APPROVED');

    const readiness = this.readiness(permit);
    const blockers: string[] = [];
    if (readiness.pending_nocs.length) {
      blockers.push(`clearance pending from ${readiness.pending_nocs.join(', ')}`);
    }
    if (readiness.rejected_nocs.length) {
      blockers.push(`clearance refused by ${readiness.rejected_nocs.join(', ')}`);
    }
    if (!readiness.fee_paid) {
      blockers.push(`₹${readiness.outstanding_amount} of fees unpaid`);
    }
    if (!readiness.has_compliant_inspection) {
      blockers.push('no compliant site inspection on record');
    }
    if (blockers.length) {
      throw new BadRequestException(`Cannot approve: ${blockers.join('; ')}`);
    }

    const validityMonths = dto.validity_months ?? DEFAULT_VALIDITY_MONTHS;
    const validUntil = new Date();
    validUntil.setMonth(validUntil.getMonth() + validityMonths);

    const updated = await this.prisma.buildingPermit.update({
      where: { id },
      data: {
        status: 'APPROVED',
        approved_by: userId,
        approved_at: new Date(),
        valid_until: validUntil,
      },
      include: { nocs: true, inspections: true },
    });

    await this.closeSla(tenantId, id);

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'approve',
      beforeValue: { status: permit.status },
      afterValue: {
        status: 'APPROVED',
        valid_until: validUntil.toISOString(),
        remarks: dto.remarks ?? null,
      },
      changedFields: ['status', 'valid_until'],
    });

    this.logger.log(
      `Approved permit ${permit.permit_number} (#${id}), valid until ${validUntil.toISOString().slice(0, 10)}`,
    );
    return this.serialize(updated);
  }

  async reject(
    tenantId: string,
    id: number,
    userId: number,
    dto: RejectPermitDto,
  ) {
    const permit = await this.findOwned(tenantId, id);
    this.assertTransition(permit.status, 'REJECTED');

    const updated = await this.prisma.buildingPermit.update({
      where: { id },
      data: { status: 'REJECTED', rejection_reason: dto.reason },
      include: { nocs: true, inspections: true },
    });

    await this.closeSla(tenantId, id);

    await this.audit.log({
      tenantId,
      orgUnitId: permit.org_unit_id,
      userId,
      module: MODULE,
      entityType: ENTITY_TYPE,
      entityId: id.toString(),
      action: 'reject',
      beforeValue: { status: permit.status },
      afterValue: { status: 'REJECTED', rejection_reason: dto.reason },
      changedFields: ['status', 'rejection_reason'],
    });

    return this.serialize(updated);
  }

  /** Stop the SLA clock once the file reaches a decision. */
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

  // ── Scheduled maintenance ─────────────────────────────────────────────────

  /**
   * A sanctioned permit lapses if the applicant never starts work. Marking it
   * EXPIRED nightly keeps the register honest without anyone having to sweep
   * it by hand.
   */
  @Cron(CronExpression.EVERY_DAY_AT_1AM)
  async expireLapsedPermits() {
    const now = new Date();
    const lapsed = await this.prisma.buildingPermit.findMany({
      where: { status: 'APPROVED', valid_until: { lt: now } },
      select: { id: true, tenant_id: true, org_unit_id: true, permit_number: true },
    });

    if (lapsed.length === 0) return { expired: 0 };

    await this.prisma.buildingPermit.updateMany({
      where: { id: { in: lapsed.map((p) => p.id) } },
      data: { status: 'EXPIRED' },
    });

    for (const permit of lapsed) {
      await this.audit.log({
        tenantId: permit.tenant_id,
        orgUnitId: permit.org_unit_id,
        module: MODULE,
        entityType: ENTITY_TYPE,
        entityId: permit.id.toString(),
        action: 'expire',
        afterValue: { status: 'EXPIRED', permit_number: permit.permit_number },
        changedFields: ['status'],
      });
    }

    this.logger.log(`Expired ${lapsed.length} lapsed building permit(s)`);
    return { expired: lapsed.length };
  }
}
