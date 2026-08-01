import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { TenantAnalyticsService } from './tenant-analytics.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin')
@Controller('api/superadmin/analytics/tenants')
export class TenantAnalyticsController {
  constructor(private readonly analytics: TenantAnalyticsService) {}

  @Get('overview')
  overview() {
    return this.analytics.overview();
  }
}
