import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export type MunicipalityFeature =
  | 'solid_waste_mgmt'
  | 'drainage_mgmt'
  | 'road_mgmt'
  | 'parks_mgmt'
  | 'public_health'
  | 'building_permit'
  | 'birth_death_reg'
  | 'vehicle_fleet_mgmt'
  | 'cemetery_mgmt'
  | 'encroachment_mgmt';

/**
 * Mirrors the `BranchFeatureConfig` column defaults, for branches provisioned
 * before a module existed and so having no row for it.
 *
 * Keep in step with the schema: a module with a working implementation
 * defaults to `true` so enforcing the gate never takes a live feature away,
 * and everything still unbuilt stays `false`.
 */
export const FEATURE_DEFAULTS: Record<MunicipalityFeature, boolean> = {
  solid_waste_mgmt: true,
  building_permit: true,
  birth_death_reg: true,
  drainage_mgmt: false,
  road_mgmt: false,
  parks_mgmt: false,
  public_health: false,
  vehicle_fleet_mgmt: false,
  cemetery_mgmt: false,
  encroachment_mgmt: false,
};

@Injectable()
export class MunicipalityService {
  constructor(private prisma: PrismaService) {}

  /**
   * Check if a specific municipality feature is enabled for the branch.
   */
  async checkFeatureEnabled(orgUnitId: number, feature: MunicipalityFeature): Promise<boolean> {
    const config = await this.prisma.branchFeatureConfig.findUnique({
      where: { org_unit_id: orgUnitId },
    });

    // No row means the branch predates this module, not that it was refused —
    // fall back to the schema default rather than denying. See FEATURE_DEFAULTS.
    const enabled = config ? Boolean(config[feature]) : FEATURE_DEFAULTS[feature];

    if (!enabled) {
      throw new ForbiddenException(
        `Feature "${feature}" is currently disabled for branch ID ${orgUnitId}. Contact Super Admin for provisioning.`,
      );
    }
    return true;
  }

  /**
   * Record a generic transaction for a municipality module (e.g. scheduling, permit submission).
   * Validates feature flag toggle before execution.
   */
  async recordTransaction(
    tenantId: string,
    orgUnitId: number,
    feature: MunicipalityFeature,
    userId: number,
    data: any,
  ) {
    // 1. Enforce feature gating check
    await this.checkFeatureEnabled(orgUnitId, feature);

    // 2. Submit details to FormSubmission (re-using Phase 5 builder engine)
    // Find or create a default form template for the feature if it doesn't exist
    let template = await this.prisma.formTemplate.findFirst({
      where: { tenant_id: tenantId, code: `muni_${feature}` },
    });

    if (!template) {
      template = await this.prisma.formTemplate.create({
        data: {
          tenant_id: tenantId,
          code: `muni_${feature}`,
          name: `Default Form for ${feature}`,
          module: 'municipality',
          version: 1,
          is_active: true,
        },
      });
    }

    const submission = await this.prisma.formSubmission.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        template_id: template.id,
        submitted_by: userId,
        data: data as any,
        status: 'submitted',
        entity_type: `muni_${feature}`,
      },
    });

    return submission;
  }

  /**
   * List logged transactions for a specific municipality feature.
   */
  async getTransactions(tenantId: string, orgUnitId: number, feature: MunicipalityFeature) {
    await this.checkFeatureEnabled(orgUnitId, feature);

    const template = await this.prisma.formTemplate.findFirst({
      where: { tenant_id: tenantId, code: `muni_${feature}` },
    });

    if (!template) return [];

    return this.prisma.formSubmission.findMany({
      where: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        template_id: template.id,
      },
      orderBy: { submitted_at: 'desc' },
    });
  }
}
