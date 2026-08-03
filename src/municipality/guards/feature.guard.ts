import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import { FEATURE_KEY } from '../decorators/requires-feature.decorator';
import {
  FEATURE_DEFAULTS,
  type MunicipalityFeature,
} from '../municipality.service';

/**
 * Enforces per-branch module provisioning for anything marked with
 * `@RequiresFeature(...)`.
 *
 * Two deliberate behaviours:
 *
 * 1. `super_admin` bypasses. It is the platform operator's role — it manages
 *    provisioning and must be able to reach a module in order to turn it on.
 *
 * 2. A branch with no `BranchFeatureConfig` row falls back to the schema
 *    defaults rather than being denied. Branches provisioned before a module
 *    existed have no row for it, and failing closed would take a working
 *    feature away from every one of them on deploy.
 */
@Injectable()
export class FeatureGuard implements CanActivate {
  private readonly logger = new Logger(FeatureGuard.name);

  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const feature = this.reflector.getAllAndOverride<MunicipalityFeature>(
      FEATURE_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!feature) return true;

    const req = context.switchToHttp().getRequest();
    const user = req.user;
    if (!user) return true; // JwtAuthGuard runs first and owns this decision.

    if (user.role === 'super_admin') return true;

    const orgUnitId = user.org_unit_id;
    if (orgUnitId == null) {
      throw new ForbiddenException(
        'Your account is not associated with any branch',
      );
    }

    const config = await this.prisma.branchFeatureConfig.findUnique({
      where: { org_unit_id: orgUnitId },
      select: { [feature]: true } as any,
    });

    const enabled = config
      ? Boolean((config as Record<string, unknown>)[feature])
      : FEATURE_DEFAULTS[feature];

    if (!enabled) {
      throw new ForbiddenException(
        `The "${feature}" module is not enabled for your branch. Contact your administrator.`,
      );
    }

    return true;
  }
}
