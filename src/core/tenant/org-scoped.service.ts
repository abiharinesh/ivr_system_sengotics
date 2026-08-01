import { ForbiddenException } from '@nestjs/common';
import { OrgHierarchyService } from './org-hierarchy.service';

/**
 * Base class for services that must enforce hierarchy-aware access scope
 * (own_org_unit / child_org_units / all_org_units) before acting on a given
 * org unit. Centralizes the check that today only `panchayat-admin.service.ts`
 * performs manually — everywhere else does flat org-unit-id equality with no
 * hierarchy awareness. New services should extend this and call
 * `assertAccess()` at the top of every method that takes a caller-supplied
 * org unit id.
 */
export abstract class OrgScopedService {
  protected constructor(protected readonly hierarchy: OrgHierarchyService) {}

  protected async assertAccess(
    tenantId: string,
    callerOrgUnitId: number,
    accessScope: string,
    targetOrgUnitId: number,
  ): Promise<void> {
    const allowed = await this.hierarchy.canAccessOrgUnit(
      tenantId,
      callerOrgUnitId,
      accessScope,
      targetOrgUnitId,
    );
    if (!allowed) {
      throw new ForbiddenException(
        `You do not have access to org unit #${targetOrgUnitId}`,
      );
    }
  }
}
