import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Req,
  ParseIntPipe,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { WorkflowService } from './workflow.service';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';

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
@Roles('super_admin', 'panchayat_admin', 'municipal_commissioner', 'municipal_engineer')
@Controller('api/workflows')
export class WorkflowController {
  constructor(private readonly service: WorkflowService) {}

  @Post('templates')
  createTemplate(@Req() req: AuthenticatedRequest, @Body() body: any) {
    const orgUnitId = body.org_unit_id ?? req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Panchayat ID is required');
    }
    return this.service.createTemplate(req.user.tenant_id, {
      ...body,
      org_unit_id: orgUnitId,
    });
  }

  @Post('steps')
  createStep(@Body() body: any) {
    return this.service.createStep(body);
  }

  @Post('rules')
  createRule(@Body() body: any) {
    return this.service.createRule(body);
  }

  @Post('actions')
  processAction(
    @Req() req: AuthenticatedRequest,
    @Body()
    body: {
      instanceId: number;
      action: 'approved' | 'rejected' | 'returned' | 'escalated' | 'executed';
      comments?: string;
    },
  ) {
    if (!body.instanceId || !body.action) {
      throw new BadRequestException('Instance ID and action are required');
    }
    return this.service.processAction(
      req.user.tenant_id,
      body.instanceId,
      req.user.id,
      body.action,
      body.comments,
    );
  }

  @Get('pending')
  getPending(@Req() req: AuthenticatedRequest) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Your user context has no branch associated');
    }
    return this.service.getPendingForRole(
      req.user.tenant_id,
      orgUnitId,
      req.user.role,
    );
  }

  @Get('timeline/:entityType/:entityId')
  getTimeline(
    @Req() req: AuthenticatedRequest,
    @Param('entityType') entityType: string,
    @Param('entityId', ParseIntPipe) entityId: number,
  ) {
    return this.service.getTimeline(req.user.tenant_id, entityType, entityId);
  }
}
