import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  ParseIntPipe,
  Body,
  Query,
  UseGuards,
  Req,
  Res,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import * as express from 'express';
import { ReportsService, CreateSavedReportDto } from './reports.service';
import { ServiceAnalyticsService } from './service-analytics.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    // Every read here is tenant-scoped. Leaving it off the type is how the
    // handlers below ended up passing a literal `'default'` instead.
    tenant_id: string;
    org_unit_id: number | null;
  };
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin', 'super_admin', 'municipal_commissioner', 'revenue_officer', 'revenue_inspector', 'municipal_engineer')
@Controller('api/admin/reports')
export class ReportsController {
  constructor(
    private readonly service: ReportsService,
    private readonly analytics: ServiceAnalyticsService,
  ) {}

  private getPanchayatId(req: AuthenticatedRequest): number {
    if (req.user.role === 'super_admin') {
      // Super admins default to a generic admin ID or from query
      return 1;
    }
    if (!req.user.org_unit_id) {
      throw new ForbiddenException(
        'Your account is not associated with any panchayat',
      );
    }
    return req.user.org_unit_id;
  }

  @Get('preview')
  async getPreview(
    @Req() req: AuthenticatedRequest,
    @Query('service') service: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('status') status?: string,
    @Query('category') category?: string,
    @Query('minConfidence') minConfidence?: string,
    @Query('zone') zone?: string,
    @Query('minComplaints') minComplaints?: string,
    @Query('role') role?: string,
    @Query('activeOnly') activeOnly?: string,
  ) {
    if (!service)
      throw new BadRequestException('service query parameter is required');
    const pId = this.getPanchayatId(req);
    const filters = {
      startDate,
      endDate,
      status,
      category,
      minConfidence: minConfidence ? Number(minConfidence) : undefined,
      zone,
      minComplaints: minComplaints ? Number(minComplaints) : undefined,
      role,
      activeOnly: activeOnly === 'true',
    };

    switch (service) {
      case 'complaints':
        return this.service.getComplaintsData(pId, filters);
      case 'ivrCalls':
        return this.service.getIvrTrafficData(filters);
      case 'poles':
        return this.service.getPolesData(pId, filters);
      case 'tenders':
        return this.service.getTendersData(pId, filters);
      case 'fieldOps':
        return this.service.getFieldStaffData(pId, filters);
      case 'zones':
        return this.service.getZonesData(pId, filters);
      default:
        throw new BadRequestException('Invalid service type');
    }
  }

  @Get('download')
  async download(
    @Req() req: AuthenticatedRequest,
    @Res() res: express.Response,
    @Query('service') service: string,
    @Query('format') format: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('status') status?: string,
    @Query('category') category?: string,
    @Query('minConfidence') minConfidence?: string,
    @Query('zone') zone?: string,
    @Query('minComplaints') minComplaints?: string,
    @Query('role') role?: string,
    @Query('activeOnly') activeOnly?: string,
  ) {
    if (!service)
      throw new BadRequestException('service parameter is required');
    if (!format) throw new BadRequestException('format parameter is required');
    const pId = this.getPanchayatId(req);
    const filters = {
      startDate,
      endDate,
      status,
      category,
      minConfidence: minConfidence ? Number(minConfidence) : undefined,
      zone,
      minComplaints: minComplaints ? Number(minComplaints) : undefined,
      role,
      activeOnly: activeOnly === 'true',
    };

    const dateStr = new Date().toISOString().split('T')[0];
    const filename = `report_${service}_${dateStr}.${format.toLowerCase()}`;

    if (format.toUpperCase() === 'CSV') {
      const data = await this.service.buildCSV(service, pId, filters);
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${filename}"`,
      );
      res.send(Buffer.from(data, 'utf-8'));
    } else {
      const data = await this.service.buildHTML(service, pId, filters);
      res.setHeader('Content-Type', 'text/html');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${filename}"`,
      );
      res.send(Buffer.from(data, 'utf-8'));
    }
  }

  // Widget and role-dashboard endpoints used to live here. They duplicated
  // `/api/dashboard`, which is what the console actually calls, and every one
  // of them passed a literal `'default'` as the tenant — so a second client's
  // administrator would have been reading and writing the first client's
  // dashboards. Removed rather than fixed twice.

  /**
   * GET /api/reports/service-analytics?days=30
   *
   * Complaint volume, resolution time, SLA compliance and satisfaction for
   * the caller's branch. The Insights hub used to hardcode all four.
   */
  @Get('service-analytics')
  serviceAnalytics(
    @Req() req: AuthenticatedRequest,
    @Query('days') days?: string,
  ) {
    const window = Math.min(Math.max(Number(days) || 30, 7), 180);
    return this.analytics.overview(req.user.org_unit_id, window);
  }

  // ── Saved Reports Endpoints ──────────────────────────────────────────────

  @Post('saved')
  createSavedReport(@Req() req: AuthenticatedRequest, @Body() dto: CreateSavedReportDto) {
    const orgUnitId = req.user.org_unit_id ?? 1;
    return this.service.createSavedReport(req.user.tenant_id, orgUnitId, {
      ...dto,
      created_by: req.user.id,
    });
  }

  @Get('saved')
  listSavedReports(@Req() req: AuthenticatedRequest) {
    const orgUnitId = req.user.org_unit_id ?? 1;
    return this.service.getSavedReports(req.user.tenant_id, orgUnitId);
  }

  @Post('saved/:id/generate')
  generateSavedReport(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.triggerReportGeneration(req.user.tenant_id, id);
  }
}
