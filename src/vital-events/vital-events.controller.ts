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
import type { UploadedImageFile } from '../common/upload.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { FeatureGuard } from '../municipality/guards/feature.guard';
import { RequiresFeature } from '../municipality/decorators/requires-feature.decorator';
import { DocumentService } from '../core/document/document.service';
import { VitalEventsService } from './vital-events.service';
import {
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

interface AuthReq {
  user: {
    id: number;
    email: string;
    role: string;
    org_unit_id: number | null;
    tenant_id: string;
  };
}

const ATTACHMENT_LIMIT = 15 * 1024 * 1024;
const ALLOWED_MIME = [
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/tiff',
];

/**
 * Birth & death register (Screen Plan 14 §7).
 *
 * Intake is open to counter staff and hospital operators; the registrar's acts
 * — registering an entry, rejecting it, correcting it under s.15 — are
 * narrowed on the individual routes.
 */
@UseGuards(JwtAuthGuard, RolesGuard, FeatureGuard)
@RequiresFeature('birth_death_reg')
@Roles(
  'super_admin',
  'panchayat_admin',
  'municipal_commissioner',
  'registrar',
  'sub_registrar',
  'health_officer',
  'hospital_operator',
)
@Controller('api/vital-events')
export class VitalEventsController {
  constructor(
    private readonly service: VitalEventsService,
    private readonly documents: DocumentService,
  ) {}

  /** Non-super-admins are pinned to their own branch whatever the body says. */
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
        'Your account is not associated with any registration unit',
      );
    }
    return req.user.org_unit_id;
  }

  // ── Registry ──────────────────────────────────────────────────────────────

  /** GET /api/vital-events?event_type=BIRTH&q=kumar&from=2026-01-01 */
  @Get()
  list(@Req() req: AuthReq, @Query() query: ListVitalEventsDto) {
    return this.service.list(req.user.tenant_id, {
      ...query,
      org_unit_id:
        req.user.role === 'super_admin'
          ? query.org_unit_id
          : (req.user.org_unit_id ?? undefined),
    });
  }

  /** GET /api/vital-events/summary */
  @Get('summary')
  summary(@Req() req: AuthReq, @Query('org_unit_id') orgUnitId?: string) {
    const scope =
      req.user.role === 'super_admin'
        ? orgUnitId
          ? Number(orgUnitId)
          : undefined
        : (req.user.org_unit_id ?? undefined);
    return this.service.summary(req.user.tenant_id, scope);
  }

  /** GET /api/vital-events/:id */
  @Get(':id')
  getOne(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.getById(req.user.tenant_id, id);
  }

  // ── Intake ────────────────────────────────────────────────────────────────

  /** POST /api/vital-events — counter or field report. */
  @Post()
  report(@Req() req: AuthReq, @Body() dto: ReportVitalEventDto) {
    return this.service.reportEvent(
      req.user.tenant_id,
      this.resolveOrgUnitId(req, dto.org_unit_id),
      req.user.id,
      dto,
    );
  }

  /**
   * POST /api/vital-events/hospital-feed — bulk intake from a hospital system.
   *
   * Authenticated as a `hospital_operator` user today. A production
   * integration would more likely want per-hospital API keys; that belongs in
   * the integration framework rather than here.
   */
  @Post('hospital-feed')
  @Roles('super_admin', 'panchayat_admin', 'registrar', 'hospital_operator')
  hospitalFeed(@Req() req: AuthReq, @Body() dto: HospitalFeedDto) {
    return this.service.hospitalFeed(
      req.user.tenant_id,
      this.resolveOrgUnitId(req, dto.org_unit_id),
      req.user.id,
      dto,
    );
  }

  /** PUT /api/vital-events/:id — revise particulars before registration. */
  @Put(':id')
  updateParticulars(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateParticularsDto,
  ) {
    return this.service.updateParticulars(
      req.user.tenant_id,
      id,
      req.user.id,
      dto,
    );
  }

  // ── Registrar's acts ──────────────────────────────────────────────────────

  /** POST /api/vital-events/:id/verify */
  @Post(':id/verify')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'registrar',
    'sub_registrar',
  )
  verify(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.verifyEntry(req.user.tenant_id, id, req.user.id);
  }

  /** POST /api/vital-events/:id/register — allots the register serial number. */
  @Post(':id/register')
  @Roles('super_admin', 'panchayat_admin', 'municipal_commissioner', 'registrar')
  register(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RegisterEventDto,
  ) {
    return this.service.register(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/vital-events/:id/reject */
  @Post(':id/reject')
  @Roles('super_admin', 'panchayat_admin', 'municipal_commissioner', 'registrar')
  reject(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RejectEventDto,
  ) {
    return this.service.reject(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/vital-events/:id/correct — amendment under s.15. */
  @Post(':id/correct')
  @Roles('super_admin', 'panchayat_admin', 'municipal_commissioner', 'registrar')
  correct(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CorrectEventDto,
  ) {
    return this.service.correct(req.user.tenant_id, id, req.user.id, dto);
  }

  // ── Certificates ──────────────────────────────────────────────────────────

  /** POST /api/vital-events/:id/certificates */
  @Post(':id/certificates')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'registrar',
    'sub_registrar',
  )
  issueCertificate(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: IssueCertificateDto,
  ) {
    return this.service.issueCertificate(
      req.user.tenant_id,
      id,
      req.user.id,
      dto,
    );
  }

  /** PUT /api/vital-events/:id/certificates/:certificateId/cancel */
  @Put(':id/certificates/:certificateId/cancel')
  @Roles('super_admin', 'panchayat_admin', 'municipal_commissioner', 'registrar')
  cancelCertificate(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Param('certificateId', ParseIntPipe) certificateId: number,
    @Body() dto: CancelCertificateDto,
  ) {
    return this.service.cancelCertificate(
      req.user.tenant_id,
      id,
      certificateId,
      req.user.id,
      dto,
    );
  }

  // ── Supporting documents ──────────────────────────────────────────────────

  /**
   * POST /api/vital-events/:id/documents — hospital report, medical
   * certificate of cause of death, affidavit for a late entry.
   */
  @Post(':id/documents')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: ATTACHMENT_LIMIT } }),
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
    if (file.mimetype && !ALLOWED_MIME.includes(file.mimetype)) {
      throw new BadRequestException(
        `Unsupported file type "${file.mimetype}". Upload a PDF or an image.`,
      );
    }

    // Proves the entry exists in this tenant before we store bytes.
    const event = await this.service.getById(req.user.tenant_id, id);

    return this.documents.upload({
      tenantId: req.user.tenant_id,
      orgUnitId: event.org_unit_id,
      title: title?.trim() || file.originalname,
      fileName: file.originalname,
      buffer: file.buffer,
      mimeType: file.mimetype ?? 'application/octet-stream',
      uploadedBy: req.user.id,
      module: 'vital_events',
      entityType: 'vital_event',
      entityId: id,
    });
  }
}
