import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { RoleDashboardController } from './role-dashboard.controller';
import { RoleDashboardService } from './role-dashboard.service';

@Module({
  imports: [PrismaModule],
  controllers: [RoleDashboardController],
  providers: [RoleDashboardService],
  exports: [RoleDashboardService],
})
export class RoleDashboardModule {}
