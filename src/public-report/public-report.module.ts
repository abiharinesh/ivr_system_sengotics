import { Module } from '@nestjs/common';
import { PublicReportController } from './public-report.controller';
import { PublicReportService } from './public-report.service';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { AdCampaignModule } from '../ad-campaign/ad-campaign.module';

@Module({
  imports: [PrismaModule, AuthModule, AdCampaignModule],
  controllers: [PublicReportController],
  providers: [PublicReportService],
  exports: [PublicReportService],
})
export class PublicReportModule {}
