import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { AuditService } from '../core/audit/audit.service';
import { OrgHierarchyService } from '../core/tenant/org-hierarchy.service';

export class CreateContractorDto {
  name: string;
  phone: string;
  email?: string;
  gstNumber?: string;
  panNumber?: string;
  registrationNumber?: string;
  category?: string[];
  rating?: number;
}

export class CreateWorkOrderDto {
  branchId: number;
  contractorId?: number;
  tenderId?: number;
  title: string;
  description?: string;
  estimatedCost?: number;
  actualCost?: number;
  expectedCompletion?: Date;
  measurementBook?: any[];
  financialYearCode?: string;
  createdBy: number;
}

@Injectable()
export class ContractorService {
  private readonly logger = new Logger(ContractorService.name);

  constructor(
    private prisma: PrismaService,
    private numberGen: NumberGenService,
    private audit: AuditService,
    private hierarchy: OrgHierarchyService,
  ) {}

  // ── Contractor Operations ───────────────────────────────────────────────

  async createContractor(tenantId: string, dto: CreateContractorDto, userId?: number) {
    const contractor = await this.prisma.contractor.create({
      data: {
        tenant_id: tenantId,
        name: dto.name,
        phone: dto.phone,
        email: dto.email ?? null,
        gst_number: dto.gstNumber ?? null,
        pan_number: dto.panNumber ?? null,
        registration_number: dto.registrationNumber ?? null,
        category: dto.category ?? [],
        rating: dto.rating ?? 5.0,
        is_active: true,
      },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: 'contractor',
      entityType: 'Contractor',
      entityId: contractor.id.toString(),
      action: 'create',
      afterValue: contractor as any,
    });

    return contractor;
  }

  async getContractors(tenantId: string) {
    return this.prisma.contractor.findMany({
      where: { tenant_id: tenantId, is_deleted: false },
    });
  }

  async getContractor(tenantId: string, id: number) {
    const contractor = await this.prisma.contractor.findFirst({
      where: { id, tenant_id: tenantId, is_deleted: false },
      include: { work_orders: true },
    });
    if (!contractor) throw new NotFoundException(`Contractor #${id} not found.`);
    return contractor;
  }

  async updateContractor(tenantId: string, id: number, dto: Partial<CreateContractorDto>, userId?: number) {
    const existing = await this.getContractor(tenantId, id);

    const updated = await this.prisma.contractor.update({
      where: { id },
      data: {
        name: dto.name,
        phone: dto.phone,
        email: dto.email,
        gst_number: dto.gstNumber,
        pan_number: dto.panNumber,
        registration_number: dto.registrationNumber,
        category: dto.category,
        rating: dto.rating,
      },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: 'contractor',
      entityType: 'Contractor',
      entityId: id.toString(),
      action: 'update',
      beforeValue: existing as any,
      afterValue: updated as any,
    });

    return updated;
  }

  async deleteContractor(tenantId: string, id: number, userId?: number) {
    const existing = await this.getContractor(tenantId, id);

    await this.prisma.contractor.update({
      where: { id },
      data: { is_deleted: true, deleted_at: new Date() },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: 'contractor',
      entityType: 'Contractor',
      entityId: id.toString(),
      action: 'delete',
      beforeValue: existing as any,
    });

    return { success: true };
  }

  // ── Work Order Operations ───────────────────────────────────────────────

  async createWorkOrder(tenantId: string, dto: CreateWorkOrderDto, userId?: number) {
    const woNumber = await this.numberGen.next(tenantId, 'work_order', dto.branchId);

    const workOrder = await this.prisma.workOrder.create({
      data: {
        tenant_id: tenantId,
        branch_id: dto.branchId,
        work_order_number: woNumber,
        contractor_id: dto.contractorId ?? null,
        tender_id: dto.tenderId ?? null,
        title: dto.title,
        description: dto.description ?? null,
        estimated_cost: dto.estimatedCost ?? null,
        actual_cost: dto.actualCost ?? null,
        status: 'draft',
        expected_completion: dto.expectedCompletion ?? null,
        measurement_book: dto.measurementBook ? (dto.measurementBook as any) : null,
        financial_year_code: dto.financialYearCode ?? null,
        created_by: dto.createdBy,
      },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: 'contractor',
      entityType: 'WorkOrder',
      entityId: workOrder.id.toString(),
      action: 'create',
      afterValue: workOrder as any,
    });

    return workOrder;
  }

  async getWorkOrders(
    tenantId: string,
    branchId: number,
    accessScope: string,
    filters?: {
      status?: string;
      contractorId?: number;
    },
  ) {
    const branchIds = accessScope === 'child_org_units'
      ? await this.hierarchy.getDescendantBranchIds(tenantId, branchId)
      : [branchId];

    return this.prisma.workOrder.findMany({
      where: {
        tenant_id: tenantId,
        branch_id: { in: branchIds },
        ...(filters?.status && { status: filters.status }),
        ...(filters?.contractorId && { contractor_id: filters.contractorId }),
      },
      include: { contractor: true },
      orderBy: { created_at: 'desc' },
    });
  }

  async getWorkOrder(tenantId: string, id: number) {
    const workOrder = await this.prisma.workOrder.findFirst({
      where: { id, tenant_id: tenantId },
      include: { contractor: true },
    });
    if (!workOrder) throw new NotFoundException(`Work Order #${id} not found.`);
    return workOrder;
  }

  async updateWorkOrder(tenantId: string, id: number, dto: Partial<CreateWorkOrderDto>, userId?: number) {
    const existing = await this.getWorkOrder(tenantId, id);

    const updated = await this.prisma.workOrder.update({
      where: { id },
      data: {
        title: dto.title,
        description: dto.description,
        estimated_cost: dto.estimatedCost,
        actual_cost: dto.actualCost,
        expected_completion: dto.expectedCompletion,
        measurement_book: dto.measurementBook ? (dto.measurementBook as any) : undefined,
        financial_year_code: dto.financialYearCode,
      },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: 'contractor',
      entityType: 'WorkOrder',
      entityId: id.toString(),
      action: 'update',
      beforeValue: existing as any,
      afterValue: updated as any,
    });

    return updated;
  }

  async transitionStatus(
    tenantId: string,
    id: number,
    status: 'draft' | 'issued' | 'in_progress' | 'completed' | 'verified' | 'paid',
    details?: { actualCost?: number; completionCertUrl?: string; remarks?: string },
    userId?: number,
  ) {
    const existing = await this.getWorkOrder(tenantId, id);

    const updated = await this.prisma.workOrder.update({
      where: { id },
      data: {
        status,
        ...(details?.actualCost && { actual_cost: details.actualCost }),
        ...(details?.completionCertUrl && { completion_cert_url: details.completionCertUrl }),
      },
    });

    await this.audit.log({
      tenantId,
      userId,
      module: 'contractor',
      entityType: 'WorkOrder',
      entityId: id.toString(),
      action: `status_change_${status}`,
      beforeValue: existing as any,
      afterValue: updated as any,
    });

    return updated;
  }
}
