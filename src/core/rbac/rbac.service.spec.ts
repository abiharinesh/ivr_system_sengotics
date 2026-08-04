import { Test, TestingModule } from '@nestjs/testing';
import { RbacService } from './rbac.service';
import { FeatureAccessService } from './feature-access.service';
import { PrismaService } from '../../prisma/prisma.service';

const role = (over: Record<string, any> = {}) => ({
  id: 1,
  name: 'municipal_engineer',
  display_name: 'Municipal Engineer',
  is_super_admin: false,
  is_active: true,
  ...over,
});

describe('RbacService', () => {
  let service: RbacService;

  const prisma = {
    userRole: { findMany: jest.fn() },
    role: { findMany: jest.fn() },
    rolePermission: { findMany: jest.fn() },
    roleScreenAccess: { findMany: jest.fn() },
    appScreen: { findMany: jest.fn() },
    orgUnit: { findUnique: jest.fn() },
    branchFeatureConfig: { findUnique: jest.fn(), findFirst: jest.fn() },
    tenantFeatureConfig: { findUnique: jest.fn() },
  };

  /** A provisioning row shaped like the real table. */
  const config = (over: Record<string, boolean> = {}) => ({
    id: 1,
    org_unit_id: 10,
    complaint_mgmt: true,
    water_supply_mgmt: true,
    solid_waste_mgmt: true,
    trade_licence: true,
    property_tax: true,
    ...over,
  });

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RbacService,
        FeatureAccessService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(RbacService);
    jest.clearAllMocks();

    prisma.role.findMany.mockResolvedValue([]);
    prisma.rolePermission.findMany.mockResolvedValue([]);
    prisma.roleScreenAccess.findMany.mockResolvedValue([]);
    prisma.appScreen.findMany.mockResolvedValue([]);
    // No provisioning rows by default, so a deployment that does not use
    // feature gating behaves exactly as it did before gating existed.
    prisma.orgUnit.findUnique.mockResolvedValue({ tenant_id: 'default' });
    prisma.branchFeatureConfig.findUnique.mockResolvedValue(null);
    prisma.branchFeatureConfig.findFirst.mockResolvedValue(null);
    prisma.tenantFeatureConfig.findUnique.mockResolvedValue(null);
  });

  describe('entitlementsFor', () => {
    it('returns permissions and screens for an ordinary role', async () => {
      prisma.userRole.findMany.mockResolvedValue([{ role: role() }]);
      prisma.rolePermission.findMany.mockResolvedValue([
        { permission: { code: 'water_supply.read' } },
        { permission: { code: 'complaints.read' } },
      ]);
      prisma.roleScreenAccess.findMany.mockResolvedValue([
        { screen: { key: 'water_supply', module: 'water_supply', is_active: true } },
        { screen: { key: 'complaints', module: 'complaints', is_active: true } },
      ]);

      const ent = await service.entitlementsFor(7);

      expect(ent.isSuperAdmin).toBe(false);
      expect(ent.permissions).toEqual(['complaints.read', 'water_supply.read']);
      expect(ent.screens).toEqual(['complaints', 'water_supply']);
    });

    it('hides a screen whose registry entry has been deactivated', async () => {
      prisma.userRole.findMany.mockResolvedValue([{ role: role() }]);
      prisma.roleScreenAccess.findMany.mockResolvedValue([
        { screen: { key: 'water_supply', module: 'water_supply', is_active: true } },
        { screen: { key: 'retired_module', module: 'retired_module', is_active: false } },
      ]);

      const ent = await service.entitlementsFor(7);

      expect(ent.screens).toEqual(['water_supply']);
    });

    it('only counts access rows that are switched on', async () => {
      prisma.userRole.findMany.mockResolvedValue([{ role: role() }]);
      await service.entitlementsFor(7);

      // Revoking access flips can_view rather than deleting the row, so the
      // query has to filter on it or a revoked screen stays visible.
      expect(prisma.roleScreenAccess.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ can_view: true }),
        }),
      );
    });

    it('short-circuits for a super admin without expanding grants', async () => {
      prisma.userRole.findMany.mockResolvedValue([
        { role: role({ is_super_admin: true, name: 'super_admin' }) },
      ]);

      const ent = await service.entitlementsFor(1);

      expect(ent.isSuperAdmin).toBe(true);
      // The guards bypass on is_super_admin, so materialising every code would
      // only bloat the token.
      expect(prisma.rolePermission.findMany).not.toHaveBeenCalled();
    });

    it('grants nothing to a user with no role assignment', async () => {
      prisma.userRole.findMany.mockResolvedValue([]);

      const ent = await service.entitlementsFor(99);

      expect(ent.permissions).toEqual([]);
      expect(ent.screens).toEqual([]);
      expect(ent.isSuperAdmin).toBe(false);
    });

    it('ignores a deactivated role', async () => {
      prisma.userRole.findMany.mockResolvedValue([
        { role: role({ is_active: false }) },
      ]);

      const ent = await service.entitlementsFor(7);

      expect(ent.roles).toEqual([]);
      expect(ent.screens).toEqual([]);
    });

    it('excludes an expired temporary assignment at the query level', async () => {
      prisma.userRole.findMany.mockResolvedValue([]);
      await service.entitlementsFor(7);

      const where = prisma.userRole.findMany.mock.calls[0][0].where;
      expect(where.OR).toEqual([
        { valid_until: null },
        { valid_until: { gte: expect.any(Date) } },
      ]);
    });

    it('follows role inheritance upwards', async () => {
      prisma.userRole.findMany.mockResolvedValue([{ role: role({ id: 3 }) }]);
      // 3 inherits from 2, 2 inherits from 1.
      prisma.role.findMany
        .mockResolvedValueOnce([{ inherits_from_role_id: 2 }])
        .mockResolvedValueOnce([{ inherits_from_role_id: 1 }])
        .mockResolvedValue([]);

      await service.entitlementsFor(7);

      const ids = prisma.rolePermission.findMany.mock.calls[0][0].where.role_id.in;
      expect(ids.sort()).toEqual([1, 2, 3]);
    });

    it('does not hang on an inheritance cycle', async () => {
      prisma.userRole.findMany.mockResolvedValue([{ role: role({ id: 1 }) }]);
      // 1 -> 2 -> 1 -> ... A naive walk would never terminate.
      prisma.role.findMany.mockImplementation(({ where }: any) => {
        const id = where.id.in[0];
        return Promise.resolve([{ inherits_from_role_id: id === 1 ? 2 : 1 }]);
      });

      const ent = await service.entitlementsFor(7);

      expect(ent).toBeDefined();
      const ids = prisma.rolePermission.findMany.mock.calls[0][0].where.role_id.in;
      expect(ids.sort()).toEqual([1, 2]);
    });

    it('merges entitlements across two roles without duplicating', async () => {
      prisma.userRole.findMany.mockResolvedValue([
        { role: role({ id: 1, name: 'revenue_officer' }) },
        { role: role({ id: 2, name: 'licensing_clerk' }) },
      ]);
      prisma.rolePermission.findMany.mockResolvedValue([
        { permission: { code: 'trade_licences.read' } },
        { permission: { code: 'trade_licences.read' } },
        { permission: { code: 'property_tax.read' } },
      ]);
      prisma.roleScreenAccess.findMany.mockResolvedValue([
        { screen: { key: 'trade_licences', module: 'trade_licences', is_active: true } },
        { screen: { key: 'trade_licences', module: 'trade_licences', is_active: true } },
      ]);

      const ent = await service.entitlementsFor(7);

      expect(ent.permissions).toEqual(['property_tax.read', 'trade_licences.read']);
      expect(ent.screens).toEqual(['trade_licences']);
    });

    it('survives a database without the RBAC tables', async () => {
      prisma.userRole.findMany.mockRejectedValue(new Error('relation does not exist'));

      // Login must not fail on a database that has not had the migration.
      const ent = await service.entitlementsFor(7);
      expect(ent.screens).toEqual([]);
    });
  });

  describe('provisioning gate', () => {
    /** A role granted three screens across three different modules. */
    const grantedThree = () => {
      prisma.userRole.findMany.mockResolvedValue([
        { org_unit_id: 10, is_primary: true, role: role() },
      ]);
      prisma.roleScreenAccess.findMany.mockResolvedValue([
        { screen: { key: 'complaints', module: 'complaint_mgmt', is_active: true } },
        { screen: { key: 'solid_waste', module: 'solid_waste_mgmt', is_active: true } },
        { screen: { key: 'home', module: 'core', is_active: true } },
      ]);
      prisma.branchFeatureConfig.findFirst.mockResolvedValue(config());
    };

    it('hides a granted screen whose module the branch has switched off', async () => {
      grantedThree();
      prisma.branchFeatureConfig.findUnique.mockResolvedValue(
        config({ solid_waste_mgmt: false }),
      );

      const ent = await service.entitlementsFor(7);

      // The grant is not wrong — the same role is reused at branches that do
      // run solid waste. The branch decides.
      expect(ent.screens).toEqual(['complaints', 'home']);
    });

    it("hides a screen the tenant's plan does not include, whatever the branch says", async () => {
      grantedThree();
      prisma.branchFeatureConfig.findUnique.mockResolvedValue(config());
      prisma.tenantFeatureConfig.findUnique.mockResolvedValue(
        config({ solid_waste_mgmt: false }),
      );

      const ent = await service.entitlementsFor(7);

      // The plan is a ceiling: a branch cannot switch on what was not licensed.
      expect(ent.screens).not.toContain('solid_waste');
    });

    it('never hides core screens, so a branch cannot lock itself out', async () => {
      grantedThree();
      prisma.branchFeatureConfig.findUnique.mockResolvedValue(
        config({ complaint_mgmt: false, solid_waste_mgmt: false }),
      );

      const ent = await service.entitlementsFor(7);

      expect(ent.screens).toEqual(['home']);
    });

    it('leaves a module the config tables cannot express alone', async () => {
      // A screen shipped ahead of its feature column must stay visible, or
      // every new module is invisible until somebody adds a column.
      prisma.userRole.findMany.mockResolvedValue([
        { org_unit_id: 10, is_primary: true, role: role() },
      ]);
      prisma.roleScreenAccess.findMany.mockResolvedValue([
        { screen: { key: 'brand_new', module: 'not_a_column', is_active: true } },
      ]);
      prisma.branchFeatureConfig.findFirst.mockResolvedValue(config());
      prisma.branchFeatureConfig.findUnique.mockResolvedValue(config());

      const ent = await service.entitlementsFor(7);

      expect(ent.screens).toEqual(['brand_new']);
    });

    it('does not filter when no provisioning rows exist at all', async () => {
      grantedThree();
      prisma.branchFeatureConfig.findUnique.mockResolvedValue(null);
      prisma.tenantFeatureConfig.findUnique.mockResolvedValue(null);

      const ent = await service.entitlementsFor(7);

      expect(ent.screens).toEqual(['complaints', 'home', 'solid_waste']);
    });

    it('does not empty the menu when the config lookup fails', async () => {
      grantedThree();
      prisma.branchFeatureConfig.findUnique.mockRejectedValue(new Error('down'));
      prisma.tenantFeatureConfig.findUnique.mockRejectedValue(new Error('down'));

      const ent = await service.entitlementsFor(7);

      // Briefly showing a module they cannot open beats blanking the product.
      // The API guards still refuse the underlying calls.
      expect(ent.screens).toEqual(['complaints', 'home', 'solid_waste']);
    });

    it('reads provisioning from the primary assignment, not just any', async () => {
      prisma.userRole.findMany.mockResolvedValue([
        { org_unit_id: 99, is_primary: false, role: role({ id: 2 }) },
        { org_unit_id: 10, is_primary: true, role: role({ id: 1 }) },
      ]);
      prisma.roleScreenAccess.findMany.mockResolvedValue([]);
      prisma.branchFeatureConfig.findFirst.mockResolvedValue(config());

      await service.entitlementsFor(7);

      expect(prisma.orgUnit.findUnique).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: 10 } }),
      );
    });

    it('is skipped entirely for a super admin', async () => {
      prisma.userRole.findMany.mockResolvedValue([
        { org_unit_id: 10, is_primary: true, role: role({ is_super_admin: true }) },
      ]);

      const ent = await service.entitlementsFor(1);

      // The platform operator turns modules on; gating them out of the screen
      // that does it would be a trap.
      expect(ent.isSuperAdmin).toBe(true);
      expect(prisma.branchFeatureConfig.findUnique).not.toHaveBeenCalled();
    });
  });

  describe('platformScreens', () => {
    it('returns every active screen so a new module needs no ticking', async () => {
      prisma.appScreen.findMany.mockResolvedValue([
        { key: 'complaints' },
        { key: 'trade_licences' },
      ]);

      expect(await service.platformScreens()).toEqual([
        'complaints',
        'trade_licences',
      ]);
      expect(prisma.appScreen.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ is_active: true }),
        }),
      );
    });

    it('returns empty rather than throwing when the registry is missing', async () => {
      prisma.appScreen.findMany.mockRejectedValue(new Error('no table'));
      expect(await service.platformScreens()).toEqual([]);
    });
  });
});
