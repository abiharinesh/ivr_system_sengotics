import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';

/**
 * The configurable per-role dashboard.
 *
 * Distinct from {@link RoleDashboardModule}, which serves a handful of
 * hardcoded role-specific endpoints. This one reads `role_dashboards` and
 * computes whatever the super admin has arranged there.
 */
@Module({
  imports: [PrismaModule],
  controllers: [DashboardController],
  providers: [DashboardService],
  exports: [DashboardService],
})
export class DashboardModule {}
