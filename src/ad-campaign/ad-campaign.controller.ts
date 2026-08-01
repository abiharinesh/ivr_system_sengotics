import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  ParseIntPipe,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { AdCampaignService } from './ad-campaign.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin', 'revenue_officer', 'revenue_inspector')
@Controller('ad-campaigns')
export class AdCampaignController {
  constructor(private readonly adCampaignService: AdCampaignService) {}

  // ─── Public: Ad Serving (called from QR scan page) ───────────────────────────

  /** GET /ad-campaigns/serve?pole_id=123&org_unit_id=1 */
  @Get('serve')
  async serveAd(
    @Query('pole_id', ParseIntPipe) poleId: number,
    @Query('org_unit_id', ParseIntPipe) orgUnitId: number,
  ) {
    const ad = await this.adCampaignService.getActiveAdForPole(poleId, orgUnitId);
    if (!ad) return { ad: null };
    return {
      ad: {
        id: ad.id,
        title: ad.title,
        description: ad.description,
        image_url: ad.image_url,
        link_url: ad.link_url,
        campaign_type: ad.campaign_type,
      },
    };
  }

  /** POST /ad-campaigns/:id/impression — track a QR scan view */
  @Post(':id/impression')
  async trackImpression(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { pole_id?: number },
    @Req() req: any,
  ) {
    const ip = req.ip || req.connection?.remoteAddress;
    await this.adCampaignService.recordImpression(id, body.pole_id, ip);
    return { success: true };
  }

  /** POST /ad-campaigns/:id/click — track an ad click */
  @Post(':id/click')
  async trackClick(@Param('id', ParseIntPipe) id: number) {
    await this.adCampaignService.recordClick(id);
    return { success: true };
  }

  // ─── Admin: Campaign Management ──────────────────────────────────────────────

  /** GET /ad-campaigns?org_unit_id=1 */
  @Get()
  async listCampaigns(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.adCampaignService.listCampaigns(orgUnitId);
  }

  /** GET /ad-campaigns/:id */
  @Get(':id')
  async getCampaign(@Param('id', ParseIntPipe) id: number) {
    return this.adCampaignService.getCampaignById(id);
  }

  /** GET /ad-campaigns/:id/analytics */
  @Get(':id/analytics')
  async getCampaignAnalytics(@Param('id', ParseIntPipe) id: number) {
    return this.adCampaignService.getCampaignAnalytics(id);
  }

  /** POST /ad-campaigns */
  @Post()
  async createCampaign(@Body() body: {
    org_unit_id: number;
    advertiser_name: string;
    advertiser_phone?: string;
    title: string;
    description?: string;
    image_url?: string;
    link_url?: string;
    campaign_type?: string;
    target_zone_ids?: number[];
    target_pole_ids?: number[];
    amount_paid: number;
    starts_at: string;
    ends_at: string;
  }) {
    return this.adCampaignService.createCampaign(body);
  }

  /** PUT /ad-campaigns/:id */
  @Put(':id')
  async updateCampaign(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: Partial<{
      title: string;
      description: string;
      image_url: string;
      link_url: string;
      is_active: boolean;
      starts_at: string;
      ends_at: string;
      amount_paid: number;
    }>,
  ) {
    return this.adCampaignService.updateCampaign(id, body);
  }

  /** DELETE /ad-campaigns/:id */
  @Delete(':id')
  async deleteCampaign(@Param('id', ParseIntPipe) id: number) {
    return this.adCampaignService.deleteCampaign(id);
  }
}
