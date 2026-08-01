import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  Req,
  ParseIntPipe,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { InspectionService, CreateInspectionTemplateDto, CreateFieldInspectionDto } from './inspection.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    org_unit_id: number | null;
    tenant_id: string;
    user_type: string;
    employee_id: number | null;
    access_scope: string;
  };
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin', 'municipal_engineer', 'assistant_engineer', 'junior_engineer', 'health_officer', 'revenue_inspector')
@Controller('api/inspections')
export class InspectionController {
  constructor(private readonly service: InspectionService) {}

  // ── Template Endpoints ──────────────────────────────────────────────────

  @Post('templates')
  createTemplate(@Req() req: AuthenticatedRequest, @Body() dto: CreateInspectionTemplateDto) {
    return this.service.createTemplate(req.user.tenant_id, dto);
  }

  @Get('templates')
  listTemplates(@Req() req: AuthenticatedRequest) {
    return this.service.getTemplates(req.user.tenant_id);
  }

  @Get('templates/:id')
  getTemplate(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.getTemplate(req.user.tenant_id, id);
  }

  // ── Inspection Endpoints ────────────────────────────────────────────────

  @Post()
  createInspection(@Req() req: AuthenticatedRequest, @Body() dto: CreateFieldInspectionDto) {
    const orgUnitId = dto.orgUnitId ?? req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Branch ID is required');
    }
    return this.service.createInspection(req.user.tenant_id, {
      ...dto,
      orgUnitId,
      inspectorUserId: req.user.id,
    });
  }

  @Get()
  listInspections(
    @Req() req: AuthenticatedRequest,
    @Query('templateId') templateId?: string,
    @Query('assetId') assetId?: string,
  ) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Your user context has no branch associated');
    }
    const tid = templateId ? parseInt(templateId, 10) : undefined;
    const aid = assetId ? parseInt(assetId, 10) : undefined;

    return this.service.getInspections(
      req.user.tenant_id,
      orgUnitId,
      req.user.access_scope,
      {
        templateId: isNaN(tid as number) ? undefined : tid,
        assetId: isNaN(aid as number) ? undefined : aid,
      },
    );
  }

  @Get(':id')
  getInspection(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
    return this.service.getInspection(req.user.tenant_id, id);
  }
}
