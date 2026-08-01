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
  ParseIntPipe,
  UseGuards,
  Req,
  Res,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import type { Response } from 'express';
import { PanchayatAdminService } from './panchayat-admin.service';
import { ElectricianOpsService } from '../field-ops/field-ops.service';
import { PlumberOpsService } from '../plumber/plumber-ops.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    panchayat_id: number | null;
    tenant_id: string;
    user_type: string;
    employee_id: number | null;
    access_scope: string;
  };
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin', 'municipal_commissioner', 'municipal_engineer', 'assistant_engineer', 'junior_engineer', 'i3c_staff', 'health_officer')
@Controller('api/admin')
export class PanchayatAdminController {
  constructor(
    private readonly service: PanchayatAdminService,
    private readonly electricianOps: ElectricianOpsService,
    private readonly plumberOps: PlumberOpsService,
  ) {}

  /**
   * Extract the caller's org unit id from the JWT user.
   * Throws rather than silently defaulting — a null primary_org_unit_id means
   * the account is misconfigured (or is a super admin with no org-unit
   * context), and defaulting to org unit #1 would silently leak/mutate the
   * wrong tenant's data.
   */
  private getPanchayatId(req: AuthenticatedRequest): number {
    if (!req.user.panchayat_id) {
      throw new ForbiddenException(
        'Your account has no assigned panchayat/branch. Contact your administrator.',
      );
    }
    return req.user.panchayat_id;
  }

  // ── Profile ────────────────────────────────────────────────────────────
  @Get('me')
  getMe(@Req() req: AuthenticatedRequest) {
    return this.service.getMe(req.user.id);
  }

  @Get('branding')
  getBranding(@Req() req: AuthenticatedRequest) {
    const pid = this.getPanchayatId(req);
    return this.service.getBranding(pid);
  }

  @Put('profile')
  updateProfile(
    @Req() req: AuthenticatedRequest,
    @Body()
    body: {
      officer_name?: string;
      email?: string;
      phone?: string;
      panchayat_name?: string;
      photo_url?: string;
      // Branding & panchayat config fields
      logo_url?: string;
      secondary_logo_url?: string;
      favicon_url?: string;
      software_name_ta?: string;
      software_name_en?: string;
      software_tagline_ta?: string;
      software_tagline_en?: string;
      primary_color?: string;
      secondary_color?: string;
      welcome_audio_url?: string;
      contact_phone?: string;
      contact_email?: string;
      address?: string;
      ivr_number?: string;
      district?: string;
      taluk?: string;
      branch_code?: string;
    },
  ) {
    return this.service.updateProfile(req.user.id, body);
  }

  // ── Stats ──────────────────────────────────────────────────────────────
  @Get('dashboard/insights')
  async getDashboardInsights(@Req() req: AuthenticatedRequest) {
    const pid = this.getPanchayatId(req);
    return this.service.getDashboardInsights(
      pid,
      req.user.tenant_id,
      req.user.access_scope,
    );
  }

  @Get('stats')
  async getStats(@Req() req: AuthenticatedRequest) {
    const pid = this.getPanchayatId(req);
    return this.service.getStats(
      pid,
      req.user.tenant_id,
      req.user.access_scope,
    );
  }

  // ── Pole Management ─────────────────────────────────────────────────────
  @Post('poles')
  async createPole(
    @Req() req: AuthenticatedRequest,
    @Body()
    body: {
      pole_number?: string;
      keypad_id?: string;
      latitude?: number;
      longitude?: number;
      landmarks?: string[];
    },
  ) {
    const pid = this.getPanchayatId(req);
    return this.service.createPole(pid, body);
  }

  @Get('poles')
  async listPoles(@Req() req: AuthenticatedRequest) {
    const pid = this.getPanchayatId(req);
    return this.service.listPoles(
      pid,
      req.user.tenant_id,
      req.user.access_scope,
    );
  }

  @Put('poles/:id')
  async updatePole(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      pole_number?: string;
      keypad_id?: string;
      latitude?: number;
      longitude?: number;
      landmarks?: string[];
    },
  ) {
    const pid = this.getPanchayatId(req);
    return this.service.updatePole(pid, id, body);
  }

  @Delete('poles/:id')
  async deletePole(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    const pid = this.getPanchayatId(req);
    return this.service.deletePole(pid, id);
  }

  // ── Complaint Management ────────────────────────────────────────────────
  @Get('complaints')
  async listComplaints(
    @Req() req: AuthenticatedRequest,
    @Query('status') status?: string,
  ) {
    const pid = this.getPanchayatId(req);
    return this.service.listComplaints(
      pid,
      req.user.tenant_id,
      req.user.access_scope,
      status,
    );
  }

  @Post('complaints')
  async createComplaint(
    @Req() req: AuthenticatedRequest,
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
    const pid = this.getPanchayatId(req);
    return this.service.createComplaint(pid, body);
  }

  @Patch('complaints/:id/status')
  async updateComplaintStatus(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { status: string },
  ) {
    const pid = this.getPanchayatId(req);
    return this.service.updateComplaintStatus(
      pid,
      id,
      body.status,
    );
  }

  /** Assign a pole to a manual_review complaint + auto-learn the caller's landmark. */
  @Patch('complaints/:id/resolve')
  async resolveComplaint(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { pole_id: number },
  ) {
    const pid = this.getPanchayatId(req);
    return this.service.resolveComplaint(
      pid,
      id,
      body.pole_id,
    );
  }

  /** Assign complaint to an electrician (same panchayat). */
  @Patch('complaints/:id/assign-electrician')
  async assignElectrician(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { electrician_user_id: number },
  ) {
    const pid = this.getPanchayatId(req);
    return this.service.assignElectrician(
      pid,
      id,
      body.electrician_user_id,
    );
  }

  // ── Field electricians & exports ─────────────────────────────────────
  @Get('electricians')
  async listElectricians(@Req() req: AuthenticatedRequest) {
    const pid = this.getPanchayatId(req);
    return this.electricianOps.listElectricians(pid);
  }

  @Post('electricians')
  async createElectrician(
    @Req() req: AuthenticatedRequest,
    @Body() body: { email: string; password: string; phone_e164?: string },
  ) {
    const pid = this.getPanchayatId(req);
    return this.electricianOps.createElectricianForPanchayat(
      pid,
      body,
    );
  }

  @Get('electricians/:id/stats')
  async electricianStats(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Query('preset') preset: string,
    @Query('date_from') dateFrom?: string,
    @Query('date_to') dateTo?: string,
  ) {
    if (!preset) throw new BadRequestException('preset query required');
    const pid = this.getPanchayatId(req);
    return this.electricianOps.getElectricianStats(
      id,
      pid,
      preset,
      dateFrom,
      dateTo,
    );
  }

  @Post('exports/electrician-resolved')
  async startElectricianExport(
    @Req() req: AuthenticatedRequest,
    @Body()
    body: {
      electrician_user_id: number;
      preset: string;
      date_from?: string;
      date_to?: string;
    },
  ) {
    const pid = this.getPanchayatId(req);
    return this.electricianOps.createResolvedExportJob({
      createdByUserId: req.user.id,
      scopedPanchayatId: pid,
      electricianId: body.electrician_user_id,
      preset: body.preset,
      dateFrom: body.date_from,
      dateTo: body.date_to,
    });
  }

  @Get('exports/:jobId')
  getExportJob(
    @Req() req: AuthenticatedRequest,
    @Param('jobId', ParseIntPipe) jobId: number,
  ) {
    return this.electricianOps.getExportJob(jobId, {
      id: req.user.id,
      role: req.user.role,
      panchayat_id: req.user.panchayat_id,
    });
  }

  @Get('exports/:jobId/download')
  async downloadExport(
    @Req() req: AuthenticatedRequest,
    @Res() res: Response,
    @Param('jobId', ParseIntPipe) jobId: number,
  ) {
    const meta = await this.electricianOps.getExportJob(jobId, {
      id: req.user.id,
      role: req.user.role,
      panchayat_id: req.user.panchayat_id,
    });
    if (meta.status !== 'ready' || !meta.download_url) {
      throw new BadRequestException('Export not ready or failed');
    }
    const abs = this.electricianOps.resolveExportAbsolutePath(
      meta.download_url,
    );
    res.download(abs, `electrician-export-job-${jobId}.zip`);
  }

  // ── Field plumbers ─────────────────────────────────────────────────────
  @Get('plumbers')
  async listPlumbers(@Req() req: AuthenticatedRequest) {
    const pid = this.getPanchayatId(req);
    return this.plumberOps.listPlumbers(pid);
  }

  @Post('plumbers')
  async createPlumber(
    @Req() req: AuthenticatedRequest,
    @Body() body: { email: string; password: string; phone_e164?: string },
  ) {
    const pid = this.getPanchayatId(req);
    return this.plumberOps.createPlumberForPanchayat(
      pid,
      body,
    );
  }

  @Get('plumbers/:id/stats')
  async plumberStats(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Query('preset') preset: string,
    @Query('date_from') dateFrom?: string,
    @Query('date_to') dateTo?: string,
  ) {
    if (!preset) throw new BadRequestException('preset query required');
    const pid = this.getPanchayatId(req);
    return this.plumberOps.getPlumberStats(
      id,
      pid,
      preset,
      dateFrom,
      dateTo,
    );
  }

  /** Assign complaint to a plumber (same panchayat). */
  @Patch('complaints/:id/assign-plumber')
  async assignPlumber(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { plumber_user_id: number },
  ) {
    const pid = this.getPanchayatId(req);
    return this.plumberOps.assignPlumber(
      pid,
      id,
      body.plumber_user_id,
    );
  }
}
