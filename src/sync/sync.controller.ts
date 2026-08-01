import { Controller, Get, Post, Body, Req, Query, UseGuards, BadRequestException } from '@nestjs/common';
import { SyncService, SyncPayloadDto } from './sync.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

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

@UseGuards(JwtAuthGuard)
@Controller('api/sync')
export class SyncController {
  constructor(private readonly service: SyncService) {}

  @Post('upload')
  upload(
    @Req() req: AuthenticatedRequest,
    @Body() dto: SyncPayloadDto,
  ) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Your user context has no branch associated');
    }
    return this.service.processSyncUpload(req.user.tenant_id, orgUnitId, req.user.id, dto);
  }

  @Get('delta')
  getDelta(
    @Req() req: AuthenticatedRequest,
    @Query('lastSyncTime') lastSyncTime: string,
  ) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new BadRequestException('Your user context has no branch associated');
    }
    if (!lastSyncTime) {
      throw new BadRequestException('lastSyncTime query parameter is required');
    }
    return this.service.getSyncDelta(req.user.tenant_id, orgUnitId, lastSyncTime);
  }
}
