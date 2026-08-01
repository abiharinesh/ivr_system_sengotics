import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Patch,
  Body,
  Param,
  Query,
  Req,
  Res,
  ParseIntPipe,
  UseGuards,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import type { Response } from 'express';
import { SuperAdminService } from './super-admin.service';
import { ElectricianOpsService } from '../field-ops/field-ops.service';
import { PlumberOpsService } from '../plumber/plumber-ops.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { DocumentTemplateSettingsService } from '../tender/pdf/document-template-settings.service';
import { validateTemplateId } from '../tender/tender-status';
import { TenderService } from '../tender/tender.service';
import { ContractorDirectoryService } from '../tender/contractor-directory.service';
import { MilestoneService } from '../tender/milestone.service';
import { TenderAuditService } from '../tender/audit.service';
import { TenderPdfService } from '../tender/pdf/pdf.service';
import { FieldVerificationService } from '../tender/field-verification.service';
import { TenderShareTokenService } from '../tender/pdf/share-token.service';
import { PrismaService } from '../prisma/prisma.service';

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function formatStamp(d: Date): string {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${yyyy}${mm}${dd}_${hh}${mi}`;
}

function resolveOrigin(req: any): string {
  const xfProto = req.headers['x-forwarded-proto']?.split(',')[0]?.trim();
  const xfHost = req.headers['x-forwarded-host']?.split(',')[0]?.trim();
  const host = xfHost ?? req.get('host') ?? 'localhost:3000';
  const proto = xfProto ?? (req.protocol || 'http');
  return `${proto}://${host}`;
}

const SHARE_TOKEN_DEFAULT_MINUTES = 15;
const SHARE_TOKEN_MAX_MINUTES = 1440;

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin')
@Controller('api/superadmin')
export class SuperAdminController {
  constructor(
    private readonly superAdminService: SuperAdminService,
    private readonly electricianOps: ElectricianOpsService,
    private readonly plumberOps: PlumberOpsService,
    private readonly documentTemplateSettings: DocumentTemplateSettingsService,
    private readonly tenders: TenderService,
    private readonly vendors: ContractorDirectoryService,
    private readonly milestones: MilestoneService,
    private readonly audit: TenderAuditService,
    private readonly pdfService: TenderPdfService,
    private readonly fieldVerification: FieldVerificationService,
    private readonly shareTokens: TenderShareTokenService,
    private readonly prisma: PrismaService,
  ) {}

  // ── Panchayat Management ────────────────────────────────────────────────
  @Post('panchayats')
  createPanchayat(
    @Body()
    body: {
      name: string;
      ivr_number?: string;
      center_lat?: number;
      center_lng?: number;
      tenant_id?: string;
      branch_type?: any;
      branch_status?: any;
      branch_code?: string;
      parent_branch_id?: number;
      district?: string;
      taluk?: string;
      block?: string;
      village?: string;
      ward_count?: number;
      gis_boundary?: any;
      area_sq_km?: number;
      contact_phone?: string;
      contact_email?: string;
      address?: string;
      logo_url?: string;
    },
  ) {
    return this.superAdminService.createPanchayat(body);
  }

  @Post('panchayats/unified')
  createUnifiedPanchayat(@Body() body: any) {
    return this.superAdminService.createUnifiedPanchayat(body);
  }

  @Get('panchayats')
  listPanchayats(@Query('tenant_id') tenantId?: string) {
    return this.superAdminService.listPanchayats(tenantId ?? 'default');
  }

  @Get('panchayats/:id')
  getPanchayat(@Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.getPanchayat(id);
  }

  @Put('panchayats/:id')
  updatePanchayat(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    return this.superAdminService.updatePanchayat(id, body);
  }

  @Delete('panchayats/:id')
  deletePanchayat(@Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.deletePanchayat(id);
  }

  @Get('panchayats/:id/features')
  getFeatureConfig(@Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.getFeatureConfig(id);
  }

  @Put('panchayats/:id/features')
  updateFeatureConfig(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    return this.superAdminService.updateFeatureConfig(id, body);
  }

  /** Apply a feature template to multiple branches at once. */
  @Post('features/bulk-update')
  bulkUpdateFeatures(
    @Body() body: { branch_ids: number[]; features: Record<string, boolean> },
  ) {
    if (!Array.isArray(body?.branch_ids) || body.branch_ids.length === 0) {
      throw new BadRequestException('branch_ids array is required');
    }
    return this.superAdminService.bulkUpdateFeatureConfig(
      body.branch_ids,
      body.features ?? {},
    );
  }

  @Get('panchayats/:id/lifecycle')
  getLifecycleEvents(
    @Param('id', ParseIntPipe) id: number,
    @Query('tenant_id') tenantId?: string,
  ) {
    return this.superAdminService.getLifecycleEvents(tenantId ?? 'default', id);
  }


  @Post('poles')
  createPole(
    @Body()
    body: {
      org_unit_id: number;
      pole_number?: string;
      keypad_id?: string;
      latitude?: number;
      longitude?: number;
      landmarks?: string[];
    },
  ) {
    return this.superAdminService.createPole(body);
  }

  @Get('poles')
  listPoles(@Query('org_unit_id') pid?: string) {
    const orgUnitId = pid ? parseInt(pid, 10) : undefined;
    return this.superAdminService.listPoles(
      isNaN(orgUnitId as number) ? undefined : orgUnitId,
    );
  }

  @Put('poles/:id')
  updatePole(
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      org_unit_id?: number;
      pole_number?: string;
      keypad_id?: string;
      latitude?: number;
      longitude?: number;
      landmarks?: string[];
    },
  ) {
    return this.superAdminService.updatePole(id, body);
  }

  @Delete('poles/:id')
  deletePole(@Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.deletePole(id);
  }

  // ── Admin User Management ──────────────────────────────────────────────
  @Post('users')
  createPanchayatAdmin(
    @Body() body: { email: string; password: string; org_unit_id: number },
  ) {
    return this.superAdminService.createPanchayatAdmin(body);
  }

  @Post('users/staff')
  createStaffUser(
    @Body()
    body: {
      email: string;
      password: string;
      role: string;
      org_unit_id: number;
      phone_e164?: string;
    },
  ) {
    return this.superAdminService.createStaffUser(body);
  }

  @Get('users')
  listUsers() {
    return this.superAdminService.listUsers();
  }

  @Delete('users/:id')
  deleteUser(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.deleteUser(id, req.user?.id);
  }

  // ── Complaints (all panchayats) ─────────────────────────────────────────
  @Get('complaints')
  listComplaints(
    @Query('status') status?: string,
    @Query('org_unit_id') pid?: string,
  ) {
    const orgUnitId = pid ? parseInt(pid, 10) : undefined;
    return this.superAdminService.listComplaints(
      status,
      isNaN(orgUnitId as number) ? undefined : orgUnitId,
    );
  }

  @Post('complaints')
  createComplaint(
    @Body()
    body: {
      pole_id: number;
      complaint_type?: string;
      description?: string;
      urgency_level?: string;
      caller_language?: string;
      caller_emotion?: string;
    },
  ) {
    return this.superAdminService.createComplaint(body);
  }

  @Patch('complaints/:id/status')
  updateComplaintStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { status: string },
  ) {
    return this.superAdminService.updateComplaintStatus(id, body.status);
  }

  /** Assign a pole to a manual_review complaint + auto-learn the caller's landmark. */
  @Patch('complaints/:id/resolve')
  resolveComplaint(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { pole_id: number },
  ) {
    return this.superAdminService.resolveComplaint(id, body.pole_id);
  }

  @Patch('complaints/:id/assign-electrician')
  assignElectricianSa(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { electrician_user_id: number },
  ) {
    return this.superAdminService.assignElectricianGlobal(
      id,
      body.electrician_user_id,
    );
  }

  // ── STT Provider Settings ────────────────────────────────────────────────
  @Get('settings/stt-provider')
  getSttProvider() {
    return this.superAdminService.getSttProvider();
  }

  @Put('settings/stt-provider')
  setSttProvider(@Body() body: { provider: string }) {
    return this.superAdminService.setSttProvider(body.provider);
  }

  // ── LLM Provider Settings ────────────────────────────────────────────────
  @Get('settings/llm-provider')
  getLlmProvider() {
    return this.superAdminService.getLlmProvider();
  }

  @Put('settings/llm-provider')
  setLlmProvider(@Body() body: { provider: string }) {
    return this.superAdminService.setLlmProvider(body.provider);
  }

  // ── API Key Management ──────────────────────────────────────────────
  @Get('settings/api-keys')
  getApiKeys() {
    return this.superAdminService.getApiKeys();
  }

  @Put('settings/api-keys')
  setApiKeys(@Body() body: { rapidapi_key?: string }) {
    return this.superAdminService.setApiKeys(body);
  }

  // ── Document template defaults (platform-wide) ─────────────────────────
  @Get('settings/document-templates')
  getDocumentTemplateDefaults() {
    return this.documentTemplateSettings.getGlobalSettings();
  }

  @Put('settings/document-templates')
  updateDocumentTemplateDefaults(@Body() body: { templates?: unknown }) {
    return this.documentTemplateSettings.updateGlobalSettings(body);
  }

  @Post('settings/document-templates/:templateId/design')
  saveDocumentTemplateDesign(
    @Param('templateId') templateId: string,
    @Body() body: { fabric_scene?: unknown; overlay_svg?: unknown },
  ) {
    validateTemplateId(templateId);
    return this.documentTemplateSettings.saveGlobalDesign(templateId, body);
  }

  @Post('settings/document-templates/:templateId/preview')
  async previewDocumentTemplate(
    @Param('templateId') templateId: string,
    @Body()
    body: {
      org_unit_id?: number;
      tender_id?: number;
      contractor_id?: number;
    } = {},
    @Res() res: Response,
  ) {
    validateTemplateId(templateId);
    const orgUnitId = body.org_unit_id ?? 1;
    if (!Number.isFinite(orgUnitId) || orgUnitId <= 0) {
      throw new BadRequestException('org_unit_id is required for preview');
    }
    const html = await this.documentTemplateSettings.buildPreviewHtml(
      Math.floor(orgUnitId),
      templateId,
      { tender_id: body.tender_id, contractor_id: body.contractor_id },
    );
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(html);
  }

  // ── Stats ──────────────────────────────────────────────────────────────
  @Get('dashboard/insights')
  getDashboardInsights() {
    return this.superAdminService.getDashboardInsights();
  }

  @Get('stats')
  getStats() {
    return this.superAdminService.getStats();
  }

  // Backward-compatible alias used by some dashboard clients.
  @Get('state')
  getState() {
    return this.superAdminService.getState();
  }

  // ── Electricians & ZIP exports (global) ─────────────────────────────
  @Get('electricians')
  listElectricians(@Query('org_unit_id') pid?: string) {
    const orgUnitId = pid ? parseInt(pid, 10) : undefined;
    return this.electricianOps.listAllElectricians(
      isNaN(orgUnitId as number) ? undefined : orgUnitId,
    );
  }

  @Post('electricians')
  createElectricianGlobal(
    @Body()
    body: {
      org_unit_id: number;
      email: string;
      password: string;
      phone_e164?: string;
    },
  ) {
    return this.electricianOps.createElectricianForPanchayat(
      body.org_unit_id,
      {
        email: body.email,
        password: body.password,
        phone_e164: body.phone_e164,
      },
    );
  }

  @Get('electricians/:id/stats')
  electricianStats(
    @Param('id', ParseIntPipe) id: number,
    @Query('preset') preset: string,
    @Query('date_from') dateFrom?: string,
    @Query('date_to') dateTo?: string,
  ) {
    if (!preset) throw new BadRequestException('preset query required');
    return this.electricianOps.getElectricianStats(
      id,
      null,
      preset,
      dateFrom,
      dateTo,
    );
  }

  @Post('exports/electrician-resolved')
  startElectricianExport(
    @Req() req: any,
    @Body()
    body: {
      electrician_user_id: number;
      preset: string;
      date_from?: string;
      date_to?: string;
    },
  ) {
    return this.electricianOps.createResolvedExportJob({
      createdByUserId: req.user?.id,
      scopedPanchayatId: null,
      electricianId: body.electrician_user_id,
      preset: body.preset,
      dateFrom: body.date_from,
      dateTo: body.date_to,
    });
  }

  @Get('exports/:jobId')
  getExportJob(@Req() req: any, @Param('jobId', ParseIntPipe) jobId: number) {
    return this.electricianOps.getExportJob(jobId, {
      id: req.user?.id,
      role: req.user?.role,
      org_unit_id: req.user?.org_unit_id,
    });
  }

  @Get('exports/:jobId/download')
  async downloadExport(
    @Req() req: any,
    @Res() res: Response,
    @Param('jobId', ParseIntPipe) jobId: number,
  ) {
    const meta = await this.electricianOps.getExportJob(jobId, {
      id: req.user?.id,
      role: req.user?.role,
      org_unit_id: req.user?.org_unit_id,
    });
    if (meta.status !== 'ready' || !meta.download_url) {
      throw new BadRequestException('Export not ready or failed');
    }
    const abs = this.electricianOps.resolveExportAbsolutePath(
      meta.download_url,
    );
    res.download(abs, `electrician-export-job-${jobId}.zip`);
  }

  // ── Plumbers (global) ──────────────────────────────────────────────────
  @Get('plumbers')
  listPlumbers(@Query('org_unit_id') pid?: string) {
    const orgUnitId = pid ? parseInt(pid, 10) : undefined;
    return this.plumberOps.listAllPlumbers(
      isNaN(orgUnitId as number) ? undefined : orgUnitId,
    );
  }

  @Post('plumbers')
  createPlumberGlobal(
    @Body()
    body: {
      org_unit_id: number;
      email: string;
      password: string;
      phone_e164?: string;
    },
  ) {
    return this.plumberOps.createPlumberForPanchayat(
      body.org_unit_id,
      {
        email: body.email,
        password: body.password,
        phone_e164: body.phone_e164,
      },
    );
  }

  @Get('plumbers/:id/stats')
  plumberStats(
    @Param('id', ParseIntPipe) id: number,
    @Query('preset') preset: string,
    @Query('date_from') dateFrom?: string,
    @Query('date_to') dateTo?: string,
  ) {
    if (!preset) throw new BadRequestException('preset query required');
    return this.plumberOps.getPlumberStats(
      id,
      null,
      preset,
      dateFrom,
      dateTo,
    );
  }

  @Patch('complaints/:id/assign-plumber')
  assignPlumberSa(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { plumber_user_id: number; org_unit_id: number },
  ) {
    return this.plumberOps.assignPlumber(
      body.org_unit_id,
      id,
      body.plumber_user_id,
    );
  }

  // ── Global Scoping & Support Resolvers ───────────────────────────────────
  private async getTenderPanchayatId(tenderId: number): Promise<number> {
    const t = await this.prisma.tender.findUnique({ where: { id: tenderId } });
    if (!t) throw new NotFoundException(`Tender #${tenderId} not found`);
    return t.org_unit_id;
  }

  private async getVendorPanchayatId(contractorId: number): Promise<number> {
    const v = await this.prisma.contractor.findUnique({ where: { id: contractorId } });
    if (!v) throw new NotFoundException(`Contractor #${contractorId} not found`);
    // org_unit_id is nullable since the Vendor/Contractor merge: null means the
    // contractor is empanelled tenant-wide rather than at one org unit, so it
    // has no single org unit to scope a share token to.
    if (v.org_unit_id == null) {
      throw new BadRequestException(
        `Contractor #${contractorId} is empanelled tenant-wide and is not scoped to a single org unit`,
      );
    }
    return v.org_unit_id;
  }

  private clampTtl(raw: unknown): number {
    if (raw == null) return SHARE_TOKEN_DEFAULT_MINUTES;
    const n = typeof raw === 'number' ? raw : Number(raw);
    if (!Number.isFinite(n) || n <= 0) {
      throw new BadRequestException('ttl_minutes must be a positive number');
    }
    return Math.min(SHARE_TOKEN_MAX_MINUTES, Math.max(1, Math.floor(n)));
  }

  // ── Vendor Management (Global) ───────────────────────────────────────────
  @Get('vendors')
  listVendors(
    @Query('org_unit_id') pid?: string,
    @Query('active') active?: string,
  ) {
    const orgUnitId = pid ? parseInt(pid, 10) : undefined;
    return this.vendors.list(
      isNaN(orgUnitId as number) ? undefined : orgUnitId,
      { active: active == null ? undefined : active === 'true' },
    );
  }

  @Post('vendors')
  createVendor(@Body() body: any) {
    if (!body.org_unit_id)
      throw new BadRequestException('org_unit_id is required');
    return this.vendors.create(body.org_unit_id, body);
  }

  @Get('vendors/:id')
  async getVendor(@Param('id', ParseIntPipe) id: number) {
    const pid = await this.getVendorPanchayatId(id);
    return this.vendors.get(pid, id);
  }

  @Patch('vendors/:id')
  async updateVendor(@Param('id', ParseIntPipe) id: number, @Body() body: any) {
    const pid = await this.getVendorPanchayatId(id);
    return this.vendors.update(pid, id, body);
  }

  @Delete('vendors/:id')
  async deactivateVendor(@Param('id', ParseIntPipe) id: number) {
    const pid = await this.getVendorPanchayatId(id);
    return this.vendors.deactivate(pid, id);
  }

  // ── Tender Management (Global) ───────────────────────────────────────────
  @Get('tenders')
  listTenders(
    @Query('org_unit_id') pid?: string,
    @Query('status') status?: string,
  ) {
    const orgUnitId = pid ? parseInt(pid, 10) : undefined;
    return this.tenders.list(
      isNaN(orgUnitId as number) ? undefined : orgUnitId,
      { status },
    );
  }

  @Post('tenders')
  createTender(@Req() req: any, @Body() body: any) {
    if (!body.org_unit_id)
      throw new BadRequestException('org_unit_id is required');
    return this.tenders.create(body.org_unit_id, req.user.id, body);
  }

  @Get('tenders/:id')
  async getTender(@Param('id', ParseIntPipe) id: number) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.getDetail(pid, id);
  }

  @Patch('tenders/:id/quotation-access-mode')
  async setQuotationAccessMode(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { quotation_access_mode?: string },
  ) {
    if (!body?.quotation_access_mode)
      throw new BadRequestException('quotation_access_mode required');
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.setQuotationAccessMode(
      pid,
      id,
      req.user.id,
      body.quotation_access_mode,
    );
  }

  @Patch('tenders/:id')
  async patchTender(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.patch(pid, id, req.user.id, body);
  }

  @Get('tenders/:id/timeline')
  async timeline(@Param('id', ParseIntPipe) id: number) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders
      .getDetail(pid, id)
      .then(() => this.milestones.resolveForTender(id));
  }

  @Get('tenders/:id/audit')
  async listAudit(@Param('id', ParseIntPipe) id: number) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.getDetail(pid, id).then(() => this.audit.list(id));
  }

  @Post('tenders/:id/line-items')
  async addLine(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.addLineItem(pid, id, req.user.id, body);
  }

  @Patch('tenders/:id/line-items/:itemId')
  async updateLine(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('itemId', ParseIntPipe) itemId: number,
    @Body() body: any,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.updateLineItem(pid, id, itemId, req.user.id, body);
  }

  @Delete('tenders/:id/line-items/:itemId')
  async deleteLine(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('itemId', ParseIntPipe) itemId: number,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.deleteLineItem(pid, id, itemId, req.user.id);
  }

  @Post('tenders/:id/invites')
  async setInvites(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { contractor_ids: number[] },
  ) {
    if (!Array.isArray(body?.contractor_ids))
      throw new BadRequestException('contractor_ids array required');
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.setInvites(pid, id, req.user.id, body.contractor_ids);
  }

  @Post('tenders/:id/publish')
  async publish(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.publish(pid, id, req.user.id);
  }

  @Post('tenders/:id/close-quotations')
  async closeQuotations(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.closeQuotations(pid, id, req.user.id);
  }

  @Post('tenders/:id/award')
  async award(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { quotation_id: number },
  ) {
    if (!body?.quotation_id)
      throw new BadRequestException('quotation_id required');
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.award(pid, id, req.user.id, body.quotation_id);
  }

  @Post('tenders/:id/work-completion')
  async workCompletion(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { work_completed_at?: string; inspection_notes?: string },
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.recordWorkCompletion(pid, id, req.user.id, body ?? {});
  }

  @Post('tenders/:id/payment')
  async payment(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { payment_meta: Record<string, unknown>; close?: boolean },
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.recordPayment(pid, id, req.user.id, body);
  }

  @Post('tenders/:id/quotations')
  async addOfficerQuotation(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.tenders.addOfficerQuotation(pid, id, req.user.id, body);
  }

  // ── Tender Documents & PDF ───────────────────────────────────────────────
  @Post('tenders/:id/documents/:templateId/generate')
  async generateDocument(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('templateId') templateId: string,
    @Body()
    body: {
      contractor_id?: number;
      field_overrides?: Record<string, unknown>;
    } = {},
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.pdfService.generate({
      orgUnitId: pid,
      tenderId: id,
      actorUserId: req.user.id,
      templateId,
      contractorId: body.contractor_id ?? null,
      fieldOverrides: body.field_overrides ?? null,
    });
  }

  @Get('tenders/:id/documents')
  async listDocuments(@Param('id', ParseIntPipe) id: number) {
    const pid = await this.getTenderPanchayatId(id);
    return this.pdfService.list(pid, id);
  }

  @Get('tenders/:id/documents/:docId/preview')
  async previewDocument(
    @Res() res: Response,
    @Param('id', ParseIntPipe) id: number,
    @Param('docId', ParseIntPipe) docId: number,
  ) {
    try {
      const pid = await this.getTenderPanchayatId(id);
      const storagePath = await this.pdfService.getDownloadStoragePath(
        pid,
        id,
        docId,
      );
      const ext = storagePath.toLowerCase().endsWith('.html') ? 'html' : 'pdf';
      const bytes = await this.pdfService.readDocumentBytes(storagePath);
      res.setHeader(
        'Content-Type',
        ext === 'html' ? 'text/html; charset=utf-8' : 'application/pdf',
      );
      res.setHeader(
        'Content-Disposition',
        ext === 'html' ? 'inline' : 'inline; filename="preview.pdf"',
      );
      res.send(bytes);
    } catch (err: any) {
      if (!res.headersSent) {
        res.status(err?.status ?? 500).json({
          error: 'Document preview failed',
          message: err?.message ?? 'Unknown error',
        });
      }
    }
  }

  @Get('tenders/:id/documents/:docId/download')
  async downloadDocument(
    @Res() res: Response,
    @Param('id', ParseIntPipe) id: number,
    @Param('docId', ParseIntPipe) docId: number,
    @Query('format') format?: string,
  ) {
    try {
      const pid = await this.getTenderPanchayatId(id);
      const doc = await this.prisma.tenderDocument.findUnique({
        where: { id: docId },
      });
      const tender = await this.prisma.tender.findUnique({
        where: { id },
        include: { org_unit: { select: { name: true } } },
      });
      const panchayatName = slugify(tender?.org_unit?.name ?? 'panchayat');
      const templateName = slugify(doc?.template_id ?? 'document');
      const version = doc?.version ?? 1;
      const stamp = formatStamp(doc?.generated_at ?? new Date());

      if (format === 'pdf' || format === 'html' || format === 'docx') {
        const result = await this.pdfService.getDocumentInFormat(
          pid,
          id,
          docId,
          format,
        );
        const filename = `${panchayatName}-${id}-${templateName}-v${version}-${stamp}.${result.ext}`;
        res.setHeader('Content-Type', result.contentType);
        res.setHeader(
          'Content-Disposition',
          `attachment; filename="${filename}"`,
        );
        res.send(result.bytes);
        return;
      }

      const storagePath = await this.pdfService.getDownloadStoragePath(
        pid,
        id,
        docId,
      );
      const ext = storagePath.toLowerCase().endsWith('.html') ? 'html' : 'pdf';
      const filename = `${panchayatName}-${id}-${templateName}-v${version}-${stamp}.${ext}`;
      const bytes = await this.pdfService.readDocumentBytes(storagePath);
      res.setHeader(
        'Content-Type',
        ext === 'html' ? 'text/html; charset=utf-8' : 'application/pdf',
      );
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${filename}"`,
      );
      res.send(bytes);
    } catch (err: any) {
      if (!res.headersSent) {
        res.status(err?.status ?? 500).json({
          error: 'Document download failed',
          message: err?.message ?? 'Unknown error',
        });
      }
    }
  }

  @Get('tenders/:id/documents/:docId/html-content')
  async getDocumentHtmlContent(
    @Param('id', ParseIntPipe) id: number,
    @Param('docId', ParseIntPipe) docId: number,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    const html = await this.pdfService.getHtmlContent(pid, id, docId);
    return { html };
  }

  @Post('tenders/:id/documents/:docId/content')
  async saveDocumentContent(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('docId', ParseIntPipe) docId: number,
    @Body() body: { html: string },
  ) {
    if (!body?.html || typeof body.html !== 'string') {
      throw new BadRequestException('html field is required');
    }
    const pid = await this.getTenderPanchayatId(id);
    return this.pdfService.saveEditedHtml({
      orgUnitId: pid,
      tenderId: id,
      docId,
      html: body.html,
      actorUserId: req.user.id,
    });
  }

  @Get('tenders/:id/documents/:docId/canvas')
  async getCanvasState(
    @Param('id', ParseIntPipe) id: number,
    @Param('docId', ParseIntPipe) docId: number,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.pdfService.getCanvasState(pid, id, docId);
  }

  @Post('tenders/:id/documents/:docId/canvas')
  async saveCanvasState(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('docId', ParseIntPipe) docId: number,
    @Body() body: { layers?: Array<Record<string, unknown>> } = {},
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.pdfService.saveCanvasState({
      orgUnitId: pid,
      tenderId: id,
      docId,
      layers: body.layers ?? [],
      actorUserId: req.user.id,
    });
  }

  @Post('tenders/:id/documents/:docId/canvas/merge')
  async mergeCanvasState(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('docId', ParseIntPipe) docId: number,
    @Body() body: { layers?: Array<Record<string, unknown>> } = {},
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.pdfService.mergeCanvasState({
      orgUnitId: pid,
      tenderId: id,
      docId,
      layers: body.layers ?? [],
      actorUserId: req.user.id,
    });
  }

  @Get('tenders/:id/documents.zip')
  async zipBundle(@Res() res: Response, @Param('id', ParseIntPipe) id: number) {
    const pid = await this.getTenderPanchayatId(id);
    const tender = await this.prisma.tender.findUnique({
      where: { id },
      include: { org_unit: { select: { name: true } } },
    });
    const panchayatName = slugify(tender?.org_unit?.name ?? 'panchayat');
    const stamp = formatStamp(new Date());
    const zipName = `${panchayatName}-${id}-documents-${stamp}.zip`;
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${zipName}"`);
    await this.pdfService.streamLatestZip(pid, id, res);
  }

  @Post('tenders/:id/documents/:docId/share-link')
  async mintDocShareLink(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('docId', ParseIntPipe) docId: number,
    @Body() body: { ttl_minutes?: number } = {},
  ) {
    const pid = await this.getTenderPanchayatId(id);
    await this.pdfService.getDownloadStoragePath(pid, id, docId);
    const ttl = this.clampTtl(body?.ttl_minutes);
    const { token, expiresAt } = this.shareTokens.sign(
      { kind: 'doc', tenderId: id, docId },
      ttl,
    );
    const origin = resolveOrigin(req);
    const url = `${origin}/public/tenders/${id}/documents/${docId}/download?sig=${encodeURIComponent(token)}`;
    await this.audit.record({
      tenderId: id,
      actorUserId: req.user.id,
      event: 'doc:share_link_minted',
      payload: {
        kind: 'doc',
        doc_id: docId,
        ttl_minutes: ttl,
        expires_at: expiresAt.toISOString(),
      },
    });
    return { url, expires_at: expiresAt.toISOString(), ttl_minutes: ttl };
  }

  @Post('tenders/:id/documents.zip/share-link')
  async mintZipShareLink(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { ttl_minutes?: number } = {},
  ) {
    const pid = await this.getTenderPanchayatId(id);
    const ttl = this.clampTtl(body?.ttl_minutes);
    const { token, expiresAt } = this.shareTokens.sign(
      { kind: 'zip', tenderId: id },
      ttl,
    );
    const origin = resolveOrigin(req);
    const url = `${origin}/public/tenders/${id}/documents.zip?sig=${encodeURIComponent(token)}`;
    await this.audit.record({
      tenderId: id,
      actorUserId: req.user.id,
      event: 'doc:share_link_minted',
      payload: {
        kind: 'zip',
        ttl_minutes: ttl,
        expires_at: expiresAt.toISOString(),
      },
    });
    return { url, expires_at: expiresAt.toISOString(), ttl_minutes: ttl };
  }

  // ── Field Verification (Global) ──────────────────────────────────────────
  @Get('tenders/:id/checklist')
  async getChecklist(@Param('id', ParseIntPipe) id: number) {
    const pid = await this.getTenderPanchayatId(id);
    return this.fieldVerification.getChecklist(pid, id);
  }

  @Patch('tenders/:id/checklist/:itemId')
  async patchChecklist(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('itemId', ParseIntPipe) itemId: number,
    @Body() body: any,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.fieldVerification.patchChecklistItem(
      pid,
      id,
      itemId,
      req.user.id,
      body,
    );
  }

  @Post('tenders/:id/verification-sessions')
  async createSession(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.fieldVerification.createSession(pid, id, req.user.id, body);
  }

  @Post('tenders/:id/verification-uploads/:uploadId/assign')
  async assignUpload(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('uploadId', ParseIntPipe) uploadId: number,
    @Body() body: any,
  ) {
    const pid = await this.getTenderPanchayatId(id);
    return this.fieldVerification.assignUpload(
      pid,
      id,
      uploadId,
      req.user.id,
      body,
    );
  }

  @Post('tenders/:id/confirm-verification')
  async confirm(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    const pid = await this.getTenderPanchayatId(id);
    return this.fieldVerification.confirmVerification(pid, id, req.user.id);
  }

  // ── RBAC: Permissions (read-only, system-seeded) ──────────────────────
  @Get('permissions')
  listPermissions() {
    return this.superAdminService.listPermissions();
  }

  // ── RBAC: Permission Groups ───────────────────────────────────────────
  @Get('permission-groups')
  listPermissionGroups() {
    return this.superAdminService.listPermissionGroups();
  }

  @Post('permission-groups')
  createPermissionGroup(
    @Body() body: { name: string; permissions: string[] },
  ) {
    return this.superAdminService.createPermissionGroup(body);
  }

  @Put('permission-groups/:id')
  updatePermissionGroup(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { name?: string; permissions?: string[] },
  ) {
    return this.superAdminService.updatePermissionGroup(id, body);
  }

  @Delete('permission-groups/:id')
  deletePermissionGroup(@Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.deletePermissionGroup(id);
  }

  // ── RBAC: Roles ───────────────────────────────────────────────────────
  @Get('roles')
  listRoles(@Query('org_unit_id') orgUnitId?: string) {
    const bid = orgUnitId ? parseInt(orgUnitId, 10) : undefined;
    return this.superAdminService.listRoles(
      'default',
      isNaN(bid as number) ? undefined : bid,
    );
  }

  @Post('roles')
  createRole(@Body() body: any) {
    return this.superAdminService.createRole(body);
  }

  @Put('roles/:id')
  updateRole(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    return this.superAdminService.updateRole(id, body);
  }

  @Delete('roles/:id')
  deleteRole(@Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.deleteRole(id);
  }

  // ── RBAC: User Role Assignments ───────────────────────────────────────
  @Get('users/:userId/roles')
  listUserRoles(@Param('userId', ParseIntPipe) userId: number) {
    return this.superAdminService.listUserRoles(userId);
  }

  @Post('users/:userId/roles')
  assignUserRole(
    @Req() req: any,
    @Param('userId', ParseIntPipe) userId: number,
    @Body()
    body: {
      role_id: number;
      org_unit_id: number;
      is_temporary?: boolean;
      valid_until?: string;
    },
  ) {
    return this.superAdminService.assignUserRole({
      user_id: userId,
      role_id: body.role_id,
      org_unit_id: body.org_unit_id,
      is_temporary: body.is_temporary,
      valid_until: body.valid_until,
      granted_by: req.user?.id,
    });
  }

  @Delete('user-roles/:id')
  revokeUserRole(@Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.revokeUserRole(id);
  }

  // ── Dynamic Branch Naming & Branding Configuration ─────────────────────
  @Get('panchayats/:id/branding')
  getBranchBranding(@Param('id', ParseIntPipe) id: number) {
    return this.superAdminService.getBranchBranding(id);
  }

  @Put('panchayats/:id/branding')
  updateBranchBranding(
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      software_name_ta?: string;
      software_name_en?: string;
      software_tagline_ta?: string;
      software_tagline_en?: string;
      logo_url?: string;
      secondary_logo_url?: string;
      favicon_url?: string;
      primary_color?: string;
      secondary_color?: string;
      welcome_audio_url?: string;
    },
  ) {
    return this.superAdminService.updateBranchBranding(id, body);
  }
}
