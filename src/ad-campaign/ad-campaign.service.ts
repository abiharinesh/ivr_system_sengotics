import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdCampaignService {
  private readonly logger = new Logger(AdCampaignService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── Ad Serving (called when QR is scanned) ──────────────────────────────────

  /**
   * Fetch the active ad campaign for a given pole.
   * Priority: pole-targeted > zone-targeted > panchayat-wide.
   */
  async getActiveAdForPole(poleId: number, orgUnitId: number) {
    const now = new Date();

    // 1. Check for pole-targeted campaign first
    const poleTargeted = await this.prisma.adCampaign.findFirst({
      where: {
        org_unit_id: orgUnitId,
        is_active: true,
        starts_at: { lte: now },
        ends_at: { gte: now },
        target_pole_ids: { has: poleId },
      },
      orderBy: { amount_paid: 'desc' }, // Higher paying campaign wins
    });
    if (poleTargeted) return poleTargeted;

    // 2. Fallback: panchayat-wide campaign (no targeting)
    const panchayatWide = await this.prisma.adCampaign.findFirst({
      where: {
        org_unit_id: orgUnitId,
        is_active: true,
        starts_at: { lte: now },
        ends_at: { gte: now },
        target_pole_ids: { isEmpty: true },
        target_zone_ids: { isEmpty: true },
      },
      orderBy: { amount_paid: 'desc' },
    });

    return panchayatWide ?? null;
  }

  // ─── Impression Tracking ─────────────────────────────────────────────────────

  /** Record a QR scan impression for a campaign. */
  async recordImpression(campaignId: number, poleId?: number, deviceIp?: string) {
    await this.prisma.$transaction([
      this.prisma.adImpression.create({
        data: {
          campaign_id: campaignId,
          pole_id: poleId,
          device_ip: deviceIp,
        },
      }),
      this.prisma.adCampaign.update({
        where: { id: campaignId },
        data: { total_impressions: { increment: 1 } },
      }),
    ]);
  }

  /** Record a click on a campaign ad. */
  async recordClick(campaignId: number) {
    await this.prisma.adCampaign.update({
      where: { id: campaignId },
      data: { total_clicks: { increment: 1 } },
    });
  }

  // ─── Admin CRUD ──────────────────────────────────────────────────────────────

  /** List all campaigns for a panchayat. */
  async listCampaigns(orgUnitId: number) {
    return this.prisma.adCampaign.findMany({
      where: { org_unit_id: orgUnitId },
      orderBy: { created_at: 'desc' },
    });
  }

  /** Get campaign by ID with impression stats. */
  async getCampaignById(id: number) {
    const campaign = await this.prisma.adCampaign.findUnique({
      where: { id },
      include: {
        _count: { select: { impressions: true } },
      },
    });
    if (!campaign) throw new NotFoundException(`Campaign #${id} not found`);
    return campaign;
  }

  /** Create a new ad campaign. */
  async createCampaign(data: {
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
    return this.prisma.adCampaign.create({
      data: {
        org_unit_id: data.org_unit_id,
        advertiser_name: data.advertiser_name,
        advertiser_phone: data.advertiser_phone,
        title: data.title,
        description: data.description,
        image_url: data.image_url,
        link_url: data.link_url,
        campaign_type: data.campaign_type ?? 'standard',
        target_zone_ids: data.target_zone_ids ?? [],
        target_pole_ids: data.target_pole_ids ?? [],
        amount_paid: data.amount_paid,
        starts_at: new Date(data.starts_at),
        ends_at: new Date(data.ends_at),
      },
    });
  }

  /** Update an existing campaign. */
  async updateCampaign(id: number, data: Partial<{
    title: string;
    description: string;
    image_url: string;
    link_url: string;
    is_active: boolean;
    starts_at: string;
    ends_at: string;
    amount_paid: number;
  }>) {
    const campaign = await this.prisma.adCampaign.findUnique({ where: { id } });
    if (!campaign) throw new NotFoundException(`Campaign #${id} not found`);

    return this.prisma.adCampaign.update({
      where: { id },
      data: {
        ...(data.title !== undefined && { title: data.title }),
        ...(data.description !== undefined && { description: data.description }),
        ...(data.image_url !== undefined && { image_url: data.image_url }),
        ...(data.link_url !== undefined && { link_url: data.link_url }),
        ...(data.is_active !== undefined && { is_active: data.is_active }),
        ...(data.starts_at !== undefined && { starts_at: new Date(data.starts_at) }),
        ...(data.ends_at !== undefined && { ends_at: new Date(data.ends_at) }),
        ...(data.amount_paid !== undefined && { amount_paid: data.amount_paid }),
      },
    });
  }

  /** Delete a campaign and its impressions. */
  async deleteCampaign(id: number) {
    const campaign = await this.prisma.adCampaign.findUnique({ where: { id } });
    if (!campaign) throw new NotFoundException(`Campaign #${id} not found`);

    return this.prisma.adCampaign.delete({ where: { id } });
  }

  // ─── Analytics ───────────────────────────────────────────────────────────────

  /** Get campaign performance analytics. */
  async getCampaignAnalytics(campaignId: number) {
    const campaign = await this.prisma.adCampaign.findUnique({
      where: { id: campaignId },
    });
    if (!campaign) throw new NotFoundException(`Campaign #${campaignId} not found`);

    const impressionsByDay = await this.prisma.adImpression.groupBy({
      by: ['scanned_at'],
      where: { campaign_id: campaignId },
      _count: { id: true },
    });

    const totalImpressions = campaign.total_impressions;
    const totalClicks = campaign.total_clicks;
    const ctr = totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0;

    return {
      campaign_id: campaignId,
      title: campaign.title,
      total_impressions: totalImpressions,
      total_clicks: totalClicks,
      click_through_rate: `${ctr.toFixed(2)}%`,
      amount_paid: campaign.amount_paid,
      cost_per_impression: totalImpressions > 0
        ? (Number(campaign.amount_paid) / totalImpressions).toFixed(2)
        : '0',
      starts_at: campaign.starts_at,
      ends_at: campaign.ends_at,
      is_active: campaign.is_active,
    };
  }
}
