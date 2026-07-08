import { Module } from '@nestjs/common';
import { AdCampaignService } from './ad-campaign.service';
import { AdCampaignController } from './ad-campaign.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [AdCampaignController],
  providers: [AdCampaignService],
  exports: [AdCampaignService],
})
export class AdCampaignModule {}
