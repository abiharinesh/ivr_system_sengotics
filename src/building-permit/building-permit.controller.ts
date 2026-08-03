import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { BuildingPermitStatus } from '@prisma/client';
import type { UploadedImageFile } from '../common/upload.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { FeatureGuard } from '../municipality/guards/feature.guard';
import { RequiresFeature } from '../municipality/decorators/requires-feature.decorator';
import { DocumentService } from '../core/document/document.service';
import { BuildingPermitService } from './building-permit.service';
import {
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

interface AuthReq {
  user: {
    id: number;
    email: string;
    role: string;
    org_unit_id: number | null;
    tenant_id: string;
  };
}

/** Blueprints are PDFs and large scans, not thumbnails. */
const PLAN_UPLOAD_LIMIT = 25 * 1024 * 1024;

const ALLOWED_PLAN_MIME = [
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/tiff',
];

/**
 * Building permit & plan approval API.
 *
 * Roles follow the town-planning chain: clerks and the town planning officer
 * run intake and scrutiny, engineers inspect, and the commissioner sanctions.
 * The approve/reject endpoints narrow that further.
 */
@UseGuards(JwtAuthGuard, RolesGuard, FeatureGuard)
@RequiresFeature('building_permit')
@Roles(
  'super_admin',
  'panchayat_admin',
  'municipal_commissioner',
  'town_planning_officer',
  'municipal_engineer',
  'assistant_engineer',
  'junior_engineer',
)
@Controller('api/building-permits')
export class BuildingPermitController {
  constructor(
    private readonly service: BuildingPermitService,
    private readonly documents: DocumentService,
  ) {}

  /**
   * Resolve which org unit a write applies to. Non-super-admins are pinned to
   * their own branch regardless of what the body claims.
   */
  private resolveOrgUnitId(req: AuthReq, requested?: number): number {
    if (req.user.role === 'super_admin') {
      const id = requested ?? req.user.org_unit_id;
      if (id == null) {
        throw new BadRequestException(
          'org_unit_id is required when acting as super admin',
        );
      }
      return id;
    }
    if (req.user.org_unit_id == null) {
      throw new BadRequestException(
        'Your account is not associated with any branch',
      );
    }
    return req.user.org_unit_id;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /** GET /api/building-permits?status=SUBMITTED&q=survey123 */
  @Get()
  list(@Req() req: AuthReq, @Query() query: ListBuildingPermitsDto) {
    return this.service.list(req.user.tenant_id, {
      ...query,
      org_unit_id:
        req.user.role === 'super_admin'
          ? query.org_unit_id
          : (req.user.org_unit_id ?? undefined),
    });
  }

  /** GET /api/building-permits/summary — KPI counters for the list screen. */
  @Get('summary')
  summary(
    @Req() req: AuthReq,
    @Query('org_unit_id') orgUnitId?: string,
  ) {
    const scope =
      req.user.role === 'super_admin'
        ? orgUnitId
          ? Number(orgUnitId)
          : undefined
        : (req.user.org_unit_id ?? undefined);
    return this.service.summary(req.user.tenant_id, scope);
  }

  /** GET /api/building-permits/:id — the full file. */
  @Get(':id')
  getOne(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.getById(req.user.tenant_id, id);
  }

  // ── Application lifecycle ─────────────────────────────────────────────────

  /** POST /api/building-permits */
  @Post()
  create(@Req() req: AuthReq, @Body() dto: CreateBuildingPermitDto) {
    return this.service.create(req.user.tenant_id, req.user.id, {
      ...dto,
      org_unit_id: this.resolveOrgUnitId(req, dto.org_unit_id),
    });
  }

  /** PUT /api/building-permits/:id */
  @Put(':id')
  update(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateBuildingPermitDto,
  ) {
    return this.service.update(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/building-permits/:id/submit — starts the workflow and SLA clock. */
  @Post(':id/submit')
  submit(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.submit(req.user.tenant_id, id, req.user.id);
  }

  /** POST /api/building-permits/:id/status — scrutiny, NOC circulation, site visit. */
  @Post(':id/status')
  changeStatus(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body('status') status: string,
  ) {
    if (!status) throw new BadRequestException('status is required');
    const target = status.toUpperCase() as BuildingPermitStatus;
    if (!Object.values(BuildingPermitStatus).includes(target)) {
      throw new BadRequestException(`Unknown status "${status}"`);
    }
    return this.service.changeStatus(req.user.tenant_id, id, req.user.id, target);
  }

  // ── NOC clearances ────────────────────────────────────────────────────────

  /** POST /api/building-permits/:id/nocs */
  @Post(':id/nocs')
  addNoc(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AddNocDto,
  ) {
    return this.service.addNoc(req.user.tenant_id, id, req.user.id, dto);
  }

  /** PUT /api/building-permits/:id/nocs/:nocId — record a department's decision. */
  @Put(':id/nocs/:nocId')
  updateNoc(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Param('nocId', ParseIntPipe) nocId: number,
    @Body() dto: UpdateNocDto,
  ) {
    return this.service.updateNoc(req.user.tenant_id, id, nocId, req.user.id, dto);
  }

  // ── Site inspections ──────────────────────────────────────────────────────

  /** POST /api/building-permits/:id/inspections */
  @Post(':id/inspections')
  scheduleInspection(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ScheduleInspectionDto,
  ) {
    return this.service.scheduleInspection(
      req.user.tenant_id,
      id,
      req.user.id,
      dto,
    );
  }

  /** PUT /api/building-permits/:id/inspections/:inspectionId */
  @Put(':id/inspections/:inspectionId')
  recordInspection(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Param('inspectionId', ParseIntPipe) inspectionId: number,
    @Body() dto: RecordInspectionDto,
  ) {
    return this.service.recordInspection(
      req.user.tenant_id,
      id,
      inspectionId,
      req.user.id,
      dto,
    );
  }

  // ── Fees ──────────────────────────────────────────────────────────────────

  /** POST /api/building-permits/:id/payments */
  @Post(':id/payments')
  recordPayment(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RecordPaymentDto,
  ) {
    return this.service.recordPayment(req.user.tenant_id, id, req.user.id, dto);
  }

  // ── Decision ──────────────────────────────────────────────────────────────

  /** POST /api/building-permits/:id/approve */
  @Post(':id/approve')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'town_planning_officer',
  )
  approve(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ApprovePermitDto,
  ) {
    return this.service.approve(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/building-permits/:id/reject */
  @Post(':id/reject')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'town_planning_officer',
  )
  reject(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RejectPermitDto,
  ) {
    return this.service.reject(req.user.tenant_id, id, req.user.id, dto);
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  /**
   * POST /api/building-permits/:id/documents — blueprint, NOC letter, site photo.
   * Stored through the shared DMS so the file inherits versioning, tagging and
   * soft-delete rather than living in a module-specific table.
   */
  @Post(':id/documents')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: PLAN_UPLOAD_LIMIT } }),
  )
  async uploadDocument(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @UploadedFile() file: UploadedImageFile | undefined,
    @Body('title') title?: string,
  ) {
    if (!file?.buffer?.length) {
      throw new BadRequestException('No file received');
    }
    if (file.mimetype && !ALLOWED_PLAN_MIME.includes(file.mimetype)) {
      throw new BadRequestException(
        `Unsupported file type "${file.mimetype}". Upload a PDF or an image.`,
      );
    }

    // Proves the permit exists and belongs to this tenant before we store bytes.
    const permit = await this.service.getById(req.user.tenant_id, id);

    return this.documents.upload({
      tenantId: req.user.tenant_id,
      orgUnitId: permit.org_unit_id,
      title: title?.trim() || file.originalname,
      fileName: file.originalname,
      buffer: file.buffer,
      mimeType: file.mimetype ?? 'application/octet-stream',
      uploadedBy: req.user.id,
      module: 'building_permits',
      entityType: 'building_permit',
      entityId: id,
    });
  }
}
