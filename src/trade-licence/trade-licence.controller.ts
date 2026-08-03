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
import { DocumentService } from '../core/document/document.service';
import { TradeLicenceService } from './trade-licence.service';
import {
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
const ALLOWED_MIME = ['application/pdf', 'image/jpeg', 'image/png', 'image/tiff'];

/**
 * Trade licence & renewal (Screen Plan 16).
 *
 * Note there is no `@RequiresFeature` gate here: trade licensing has no
 * `BranchFeatureConfig` column of its own. Adding one is a schema change the
 * client should decide on, since it changes what a super admin can switch off.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(
  'super_admin',
  'panchayat_admin',
  'municipal_commissioner',
  'health_officer',
  'revenue_officer',
  'sanitary_inspector',
  'licensing_clerk',
)
@Controller('api/trade-licences')
export class TradeLicenceController {
  constructor(
    private readonly service: TradeLicenceService,
    private readonly documents: DocumentService,
  ) {}

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

  private scopeFor(req: AuthReq, requested?: number): number | undefined {
    return req.user.role === 'super_admin'
      ? requested
      : (req.user.org_unit_id ?? undefined);
  }

  // ── Register ──────────────────────────────────────────────────────────────

  /** GET /api/trade-licences?expiring_within_days=30 */
  @Get()
  list(@Req() req: AuthReq, @Query() query: ListTradeLicencesDto) {
    return this.service.list(req.user.tenant_id, {
      ...query,
      org_unit_id: this.scopeFor(req, query.org_unit_id),
    });
  }

  /** GET /api/trade-licences/summary */
  @Get('summary')
  summary(@Req() req: AuthReq, @Query('org_unit_id') orgUnitId?: string) {
    return this.service.summary(
      req.user.tenant_id,
      this.scopeFor(req, orgUnitId ? Number(orgUnitId) : undefined),
    );
  }

  /** GET /api/trade-licences/:id */
  @Get(':id')
  getOne(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.getById(req.user.tenant_id, id);
  }

  // ── Application ───────────────────────────────────────────────────────────

  /** POST /api/trade-licences */
  @Post()
  create(@Req() req: AuthReq, @Body() dto: CreateTradeLicenceDto) {
    return this.service.create(
      req.user.tenant_id,
      this.resolveOrgUnitId(req, dto.org_unit_id),
      req.user.id,
      dto,
    );
  }

  /** PUT /api/trade-licences/:id */
  @Put(':id')
  update(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateTradeLicenceDto,
  ) {
    return this.service.update(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/trade-licences/:id/submit */
  @Post(':id/submit')
  submit(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.submit(req.user.tenant_id, id, req.user.id);
  }

  // ── Inspections ───────────────────────────────────────────────────────────

  /** POST /api/trade-licences/:id/inspections */
  @Post(':id/inspections')
  scheduleInspection(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ScheduleLicenceInspectionDto,
  ) {
    return this.service.scheduleInspection(
      req.user.tenant_id,
      id,
      req.user.id,
      dto,
    );
  }

  /** PUT /api/trade-licences/:id/inspections/:inspectionId */
  @Put(':id/inspections/:inspectionId')
  recordInspection(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Param('inspectionId', ParseIntPipe) inspectionId: number,
    @Body() dto: RecordLicenceInspectionDto,
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

  /** POST /api/trade-licences/:id/payments */
  @Post(':id/payments')
  recordPayment(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RecordLicencePaymentDto,
  ) {
    return this.service.recordPayment(req.user.tenant_id, id, req.user.id, dto);
  }

  // ── Decisions ─────────────────────────────────────────────────────────────

  /** POST /api/trade-licences/:id/approve */
  @Post(':id/approve')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
  )
  approve(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ApproveLicenceDto,
  ) {
    return this.service.approve(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/trade-licences/:id/reject */
  @Post(':id/reject')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
  )
  reject(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RejectLicenceDto,
  ) {
    return this.service.reject(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/trade-licences/:id/renew — into the next licence year. */
  @Post(':id/renew')
  renew(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RenewLicenceDto,
  ) {
    return this.service.renew(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/trade-licences/:id/suspend */
  @Post(':id/suspend')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
  )
  suspend(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: SuspendLicenceDto,
  ) {
    return this.service.suspend(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/trade-licences/:id/restore */
  @Post(':id/restore')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
  )
  restore(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.restore(req.user.tenant_id, id, req.user.id);
  }

  /** POST /api/trade-licences/:id/cancel */
  @Post(':id/cancel')
  @Roles('super_admin', 'panchayat_admin', 'municipal_commissioner')
  cancel(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CancelLicenceDto,
  ) {
    return this.service.cancel(req.user.tenant_id, id, req.user.id, dto);
  }

  // ── Certificates ──────────────────────────────────────────────────────────

  /** POST /api/trade-licences/:id/certificates */
  @Post(':id/certificates')
  issueCertificate(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: IssueLicenceCertificateDto,
  ) {
    return this.service.issueCertificate(
      req.user.tenant_id,
      id,
      req.user.id,
      dto,
    );
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  /** POST /api/trade-licences/:id/documents — premises proof, NOCs, plans. */
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

    const licence = await this.service.getById(req.user.tenant_id, id);

    return this.documents.upload({
      tenantId: req.user.tenant_id,
      orgUnitId: licence.org_unit_id,
      title: title?.trim() || file.originalname,
      fileName: file.originalname,
      buffer: file.buffer,
      mimeType: file.mimetype ?? 'application/octet-stream',
      uploadedBy: req.user.id,
      module: 'trade_licences',
      entityType: 'trade_licence',
      entityId: id,
    });
  }
}
