import { Controller, Get, Post, Body, Req, Query, UseGuards, BadRequestException } from '@nestjs/common';
import { SyncService, SyncPayloadDto } from './sync.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

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

@UseGuards(JwtAuthGuard)
@Controller('api/sync')
export class SyncController {
  constructor(private readonly service: SyncService) {}

  @Post('upload')
  upload(
    @Req() req: AuthenticatedRequest,
    @Body() dto: SyncPayloadDto,
  ) {
    const branchId = req.user.panchayat_id;
    if (!branchId) {
      throw new BadRequestException('Your user context has no branch associated');
    }
    return this.service.processSyncUpload(req.user.tenant_id, branchId, req.user.id, dto);
  }

  @Get('delta')
  getDelta(
    @Req() req: AuthenticatedRequest,
    @Query('lastSyncTime') lastSyncTime: string,
  ) {
    const branchId = req.user.panchayat_id;
    if (!branchId) {
      throw new BadRequestException('Your user context has no branch associated');
    }
    if (!lastSyncTime) {
      throw new BadRequestException('lastSyncTime query parameter is required');
    }
    return this.service.getSyncDelta(req.user.tenant_id, branchId, lastSyncTime);
  }
}
