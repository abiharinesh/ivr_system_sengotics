import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BranchHierarchyService } from '../core/tenant/branch-hierarchy.service';

export class CreateInspectionTemplateDto {
  name: string;
  assetTypeCode?: string;
  checklistItems: any[]; // Array of checklist definitions: [{ item: "status", type: "yes_no" }]
}

export class CreateFieldInspectionDto {
  templateId?: number;
  branchId: number;
  inspectorUserId: number;
  assetId?: number;
  locationLat?: number;
  locationLng?: number;
  checklistResults?: Record<string, any>;
  overallScore?: number;
  photos?: string[];
  signatureUrl?: string;
  remarks?: string;
}

@Injectable()
export class InspectionService {
  private readonly logger = new Logger(InspectionService.name);

  constructor(
    private prisma: PrismaService,
    private hierarchy: BranchHierarchyService,
  ) {}

  // ── Template CRUD ────────────────────────────────────────────────────────

  async createTemplate(tenantId: string, dto: CreateInspectionTemplateDto) {
    return this.prisma.inspectionTemplate.create({
      data: {
        tenant_id: tenantId,
        name: dto.name,
        asset_type_code: dto.assetTypeCode ?? null,
        checklist_items: dto.checklistItems as any,
        is_active: true,
      },
    });
  }

  async getTemplates(tenantId: string) {
    return this.prisma.inspectionTemplate.findMany({
      where: { tenant_id: tenantId, is_active: true },
    });
  }

  async getTemplate(tenantId: string, id: number) {
    const template = await this.prisma.inspectionTemplate.findFirst({
      where: { id, tenant_id: tenantId, is_active: true },
    });
    if (!template) throw new NotFoundException(`Inspection template #${id} not found.`);
    return template;
  }

  // ── Field Inspection CRUD ────────────────────────────────────────────────

  async createInspection(tenantId: string, dto: CreateFieldInspectionDto) {
    let gpsLocked = false;
    let gpsAccuracyM: number | null = null;

    // GPS Locking validation logic
    if (dto.assetId && dto.locationLat && dto.locationLng) {
      const asset = await this.prisma.asset.findUnique({
        where: { id: dto.assetId },
      });

      if (asset && asset.latitude && asset.longitude) {
        const distance = this.calculateDistance(
          dto.locationLat,
          dto.locationLng,
          asset.latitude,
          asset.longitude,
        );

        gpsAccuracyM = distance;

        // Verify if inspector is within 100 meters radius of asset location
        if (distance <= 100) {
          gpsLocked = true;
        } else {
          this.logger.warn(`GPS verification mismatch: inspector is ${distance.toFixed(1)}m away from Asset #${dto.assetId}`);
        }
      }
    }

    const inspection = await this.prisma.fieldInspection.create({
      data: {
        tenant_id: tenantId,
        branch_id: dto.branchId,
        template_id: dto.templateId ?? null,
        inspector_user_id: dto.inspectorUserId,
        asset_id: dto.assetId ?? null,
        location_lat: dto.locationLat ?? null,
        location_lng: dto.locationLng ?? null,
        gps_locked: gpsLocked,
        gps_accuracy_m: gpsAccuracyM,
        checklist_results: dto.checklistResults ? (dto.checklistResults as any) : null,
        overall_score: dto.overallScore ?? null,
        photos: dto.photos ? (dto.photos as any) : null,
        signature_url: dto.signatureUrl ?? null,
        remarks: dto.remarks ?? null,
      },
    });

    return inspection;
  }

  async getInspections(
    tenantId: string,
    branchId: number,
    accessScope: string,
    filters?: {
      templateId?: number;
      assetId?: number;
    },
  ) {
    const branchIds = accessScope === 'child_branches'
      ? await this.hierarchy.getDescendantBranchIds(tenantId, branchId)
      : [branchId];

    return this.prisma.fieldInspection.findMany({
      where: {
        tenant_id: tenantId,
        branch_id: { in: branchIds },
        ...(filters?.templateId && { template_id: filters.templateId }),
        ...(filters?.assetId && { asset_id: filters.assetId }),
      },
      orderBy: { inspected_at: 'desc' },
    });
  }

  async getInspection(tenantId: string, id: number) {
    const inspection = await this.prisma.fieldInspection.findFirst({
      where: { id, tenant_id: tenantId },
    });
    if (!inspection) throw new NotFoundException(`Inspection #${id} not found.`);
    return inspection;
  }

  // ── Coordinate Distance Calculation Helper ──────────────────────────────

  private calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371e3; // Earth radius in meters
    const phi1 = (lat1 * Math.PI) / 180;
    const phi2 = (lat2 * Math.PI) / 180;
    const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
    const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
      Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // in meters
  }
}
