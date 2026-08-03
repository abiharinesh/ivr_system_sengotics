import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { FeatureGuard } from './feature.guard';
import { FEATURE_DEFAULTS } from '../municipality.service';

const contextFor = (user: any): ExecutionContext =>
  ({
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
    getHandler: () => () => undefined,
    getClass: () => class {},
  }) as unknown as ExecutionContext;

describe('FeatureGuard', () => {
  let guard: FeatureGuard;
  const reflector = { getAllAndOverride: jest.fn() };
  const prisma = { branchFeatureConfig: { findUnique: jest.fn() } };

  beforeEach(() => {
    jest.clearAllMocks();
    guard = new FeatureGuard(
      reflector as unknown as Reflector,
      prisma as any,
    );
    reflector.getAllAndOverride.mockReturnValue('solid_waste_mgmt');
  });

  it('lets through anything not marked with a feature', async () => {
    reflector.getAllAndOverride.mockReturnValue(undefined);

    await expect(
      guard.canActivate(contextFor({ role: 'sanitary_inspector', org_unit_id: 5 })),
    ).resolves.toBe(true);
    expect(prisma.branchFeatureConfig.findUnique).not.toHaveBeenCalled();
  });

  it('allows a branch that has the module enabled', async () => {
    prisma.branchFeatureConfig.findUnique.mockResolvedValue({
      solid_waste_mgmt: true,
    });

    await expect(
      guard.canActivate(contextFor({ role: 'sanitary_inspector', org_unit_id: 5 })),
    ).resolves.toBe(true);
  });

  it('refuses a branch that has the module switched off', async () => {
    prisma.branchFeatureConfig.findUnique.mockResolvedValue({
      solid_waste_mgmt: false,
    });

    await expect(
      guard.canActivate(contextFor({ role: 'sanitary_inspector', org_unit_id: 5 })),
    ).rejects.toThrow(ForbiddenException);
  });

  it('falls back to the schema default for a branch with no config row', async () => {
    prisma.branchFeatureConfig.findUnique.mockResolvedValue(null);

    // A branch provisioned before this module existed must not lose it.
    expect(FEATURE_DEFAULTS.solid_waste_mgmt).toBe(true);
    await expect(
      guard.canActivate(contextFor({ role: 'sanitary_inspector', org_unit_id: 5 })),
    ).resolves.toBe(true);
  });

  it('still refuses an unbuilt module when there is no config row', async () => {
    reflector.getAllAndOverride.mockReturnValue('cemetery_mgmt');
    prisma.branchFeatureConfig.findUnique.mockResolvedValue(null);

    expect(FEATURE_DEFAULTS.cemetery_mgmt).toBe(false);
    await expect(
      guard.canActivate(contextFor({ role: 'health_officer', org_unit_id: 5 })),
    ).rejects.toThrow(ForbiddenException);
  });

  it('lets super_admin through — it is the role that turns modules on', async () => {
    prisma.branchFeatureConfig.findUnique.mockResolvedValue({
      solid_waste_mgmt: false,
    });

    await expect(
      guard.canActivate(contextFor({ role: 'super_admin', org_unit_id: null })),
    ).resolves.toBe(true);
    expect(prisma.branchFeatureConfig.findUnique).not.toHaveBeenCalled();
  });

  it('refuses a user with no branch', async () => {
    await expect(
      guard.canActivate(contextFor({ role: 'sanitary_inspector', org_unit_id: null })),
    ).rejects.toThrow(/not associated with any branch/);
  });

  it('defers to JwtAuthGuard when there is no user on the request', async () => {
    await expect(guard.canActivate(contextFor(undefined))).resolves.toBe(true);
  });

  it('keeps FEATURE_DEFAULTS in step with the three built modules', () => {
    expect(FEATURE_DEFAULTS.building_permit).toBe(true);
    expect(FEATURE_DEFAULTS.birth_death_reg).toBe(true);
    expect(FEATURE_DEFAULTS.solid_waste_mgmt).toBe(true);
  });
});
