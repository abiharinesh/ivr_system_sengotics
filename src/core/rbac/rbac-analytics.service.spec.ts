import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { RbacAnalyticsService } from './rbac-analytics.service';

/**
 * The aggregation is the whole service — every figure the console draws is
 * derived here rather than queried, so the arithmetic is what needs covering.
 */

const screen = (
  id: number,
  key: string,
  group_key: string,
  over: Record<string, any> = {},
) => ({
  id,
  key,
  group_key,
  label_en: key,
  module: 'core',
  is_platform_only: false,
  ...over,
});

const role = (
  id: number,
  name: string,
  screenIds: number[],
  over: Record<string, any> = {},
) => ({
  id,
  tenant_id: 'default',
  name,
  display_name: name,
  department: null,
  hierarchy_level: 3,
  is_super_admin: false,
  is_active: true,
  inherits_from_role_id: null,
  screen_access: screenIds.map((screen_id) => ({ screen_id, can_view: true })),
  permissions: [],
  ...over,
});

const orgUnit = (id: number, name: string, over: Record<string, any> = {}) => ({
  id,
  name,
  branch_type: 'MUNICIPALITY',
  branch_status: 'ACTIVE',
  district: 'Coimbatore',
  center_lat: 11.0,
  center_lng: 77.0,
  ward_count: 20,
  ...over,
});

const user = (id: number, over: Record<string, any> = {}) => ({
  id,
  email: `u${id}@example.gov.in`,
  is_active: true,
  last_login_at: new Date(),
  must_change_password: false,
  user_type: 'employee',
  primary_org_unit_id: 1,
  ...over,
});

describe('RbacAnalyticsService', () => {
  let service: RbacAnalyticsService;

  const prisma = {
    role: { findMany: jest.fn() },
    appScreen: { findMany: jest.fn() },
    permission: { findMany: jest.fn() },
    userRole: { findMany: jest.fn() },
    orgUnit: { findMany: jest.fn() },
    user: { findMany: jest.fn() },
    auditLog: { findMany: jest.fn() },
  };

  const SCREENS = [
    screen(1, 'home', 'OVERVIEW'),
    screen(2, 'complaints', 'CITIZEN SERVICES'),
    screen(3, 'search', 'CITIZEN SERVICES'),
    screen(4, 'property_tax', 'REVENUE'),
    screen(5, 'tenants', 'ADMINISTRATION', { is_platform_only: true }),
  ];

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RbacAnalyticsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(RbacAnalyticsService);
    jest.clearAllMocks();

    prisma.role.findMany.mockResolvedValue([]);
    prisma.appScreen.findMany.mockResolvedValue(SCREENS);
    prisma.permission.findMany.mockResolvedValue([
      { id: 1, code: 'complaints.read', module: 'complaints', action: 'read' },
      { id: 2, code: 'complaints.write', module: 'complaints', action: 'write' },
      { id: 3, code: 'property_tax.read', module: 'property_tax', action: 'read' },
    ]);
    prisma.userRole.findMany.mockResolvedValue([]);
    prisma.orgUnit.findMany.mockResolvedValue([orgUnit(1, 'Mettupalayam')]);
    prisma.user.findMany.mockResolvedValue([]);
    prisma.auditLog.findMany.mockResolvedValue([]);
  });

  describe('coverage matrix', () => {
    it('counts granted screens per sidebar group', async () => {
      prisma.role.findMany.mockResolvedValue([role(1, 'clerk', [1, 2])]);

      const r = await service.overview('default');
      const row = r.coverage.roles[0];

      expect(row.screen_count).toBe(2);
      expect(row.cells).toEqual(
        expect.arrayContaining([
          { group_key: 'OVERVIEW', granted: 1, total: 1 },
          { group_key: 'CITIZEN SERVICES', granted: 1, total: 2 },
          { group_key: 'REVENUE', granted: 0, total: 1 },
        ]),
      );
    });

    it('gives a super admin every screen without needing grant rows', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'super_admin', [], { is_super_admin: true }),
      ]);

      const r = await service.overview('default');

      expect(r.coverage.roles[0].screen_count).toBe(SCREENS.length);
      // The permission catalogue comes with it, not just the screens.
      expect(r.coverage.roles[0].permission_count).toBe(3);
    });

    it('resolves screens inherited from a parent role', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'engineer', [1, 2]),
        role(2, 'assistant', [4], { inherits_from_role_id: 1 }),
      ]);

      const r = await service.overview('default');
      const assistant = r.coverage.roles.find((x) => x.name === 'assistant');

      expect(assistant?.screen_count).toBe(3);
    });

    it('does not hang on a circular inheritance chain', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'a', [1], { inherits_from_role_id: 2 }),
        role(2, 'b', [2], { inherits_from_role_id: 1 }),
      ]);

      const r = await service.overview('default');

      expect(r.coverage.roles).toHaveLength(2);
    });
  });

  describe('screen reach', () => {
    it('counts the distinct people who can open each screen', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'clerk', [1, 2]),
        role(2, 'officer', [2]),
      ]);
      prisma.userRole.findMany.mockResolvedValue([
        { id: 1, user_id: 10, role_id: 1, org_unit_id: 1, is_primary: true, created_at: new Date() },
        { id: 2, user_id: 11, role_id: 2, org_unit_id: 1, is_primary: true, created_at: new Date() },
        // The same person holding both roles must not be counted twice.
        { id: 3, user_id: 10, role_id: 2, org_unit_id: 1, is_primary: false, created_at: new Date() },
      ]);

      const r = await service.overview('default');
      const complaints = r.screen_reach.find((s) => s.key === 'complaints');

      expect(complaints?.role_count).toBe(2);
      expect(complaints?.user_count).toBe(2);
    });

    it('flags a screen no role grants, ignoring platform-only ones', async () => {
      prisma.role.findMany.mockResolvedValue([role(1, 'clerk', [1])]);

      const r = await service.overview('default');
      const unreachable = r.risks.find((x) => x.code === 'screen_unreachable');

      // complaints, search and property_tax are unreachable; `tenants` is
      // platform-only and is not a finding.
      expect(unreachable?.count).toBe(3);
    });
  });

  describe('findings', () => {
    it('reports a role whose holders would land on an empty menu', async () => {
      prisma.role.findMany.mockResolvedValue([role(1, 'ghost', [])]);
      prisma.userRole.findMany.mockResolvedValue([
        { id: 1, user_id: 10, role_id: 1, org_unit_id: 1, is_primary: true, created_at: new Date() },
      ]);
      prisma.user.findMany.mockResolvedValue([user(10)]);

      const r = await service.overview('default');

      expect(r.risks.find((x) => x.code === 'role_no_screens')?.count).toBe(1);
    });

    it('reports an active account holding no role at all', async () => {
      prisma.role.findMany.mockResolvedValue([role(1, 'clerk', [1, 2, 3, 4])]);
      prisma.user.findMany.mockResolvedValue([user(10), user(11)]);

      const r = await service.overview('default');

      expect(r.risks.find((x) => x.code === 'user_no_role')?.count).toBe(2);
      expect(r.totals.users_without_role).toBe(2);
    });

    it('reports a non-super-admin role holding almost every permission', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'shadow_admin', [1], {
          permissions: [
            { permission_id: 1 },
            { permission_id: 2 },
            { permission_id: 3 },
          ],
        }),
      ]);

      const r = await service.overview('default');

      expect(r.risks.find((x) => x.code === 'role_over_privileged')?.count).toBe(1);
    });

    it('stays silent when a super admin holds every permission', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'super_admin', [], { is_super_admin: true }),
      ]);

      const r = await service.overview('default');

      expect(r.risks.find((x) => x.code === 'role_over_privileged')).toBeUndefined();
    });

    it('orders findings by severity', async () => {
      prisma.role.findMany.mockResolvedValue([role(1, 'ghost', [])]);
      prisma.userRole.findMany.mockResolvedValue([
        { id: 1, user_id: 10, role_id: 1, org_unit_id: 1, is_primary: true, created_at: new Date() },
      ]);
      prisma.user.findMany.mockResolvedValue([
        user(10, { must_change_password: true }),
      ]);

      const r = await service.overview('default');
      const severities = r.risks.map((x) => x.severity);

      expect(severities).toEqual([...severities].sort((a, b) =>
        ({ high: 0, medium: 1, low: 2 })[a] - ({ high: 0, medium: 1, low: 2 })[b],
      ));
      expect(severities[0]).toBe('high');
    });
  });

  describe('role overlap', () => {
    it('reports two roles granting the same screens', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'a', [1, 2, 3]),
        role(2, 'b', [1, 2, 3]),
      ]);

      const r = await service.overview('default');

      expect(r.role_overlaps).toHaveLength(1);
      expect(r.role_overlaps[0].similarity).toBe(100);
      expect(r.role_overlaps[0].shared).toBe(3);
    });

    it('ignores a pair that shares little', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'a', [1, 2]),
        role(2, 'b', [3, 4]),
      ]);

      const r = await service.overview('default');

      expect(r.role_overlaps).toHaveLength(0);
    });

    it('leaves super admins out of the comparison', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'super_admin', [], { is_super_admin: true }),
        role(2, 'other', [1, 2, 3, 4, 5]),
      ]);

      const r = await service.overview('default');

      // Both resolve to every screen, but comparing the platform operator with
      // a branch role says nothing useful.
      expect(r.role_overlaps).toHaveLength(0);
    });
  });

  describe('geography', () => {
    it('measures what a branch\'s people can reach, excluding platform screens', async () => {
      prisma.role.findMany.mockResolvedValue([role(1, 'clerk', [1, 2])]);
      prisma.userRole.findMany.mockResolvedValue([
        { id: 1, user_id: 10, role_id: 1, org_unit_id: 1, is_primary: true, created_at: new Date() },
      ]);

      const r = await service.overview('default');
      const branch = r.branch_map[0];

      // 4 non-platform screens in the catalogue, 2 of them reachable here.
      expect(branch.screen_total).toBe(4);
      expect(branch.screen_reach).toBe(2);
      expect(branch.coverage_pct).toBe(50);
      expect(branch.user_count).toBe(1);
    });

    it('reports a branch with nobody assigned as empty rather than omitting it', async () => {
      prisma.role.findMany.mockResolvedValue([role(1, 'clerk', [1, 2])]);
      prisma.orgUnit.findMany.mockResolvedValue([
        orgUnit(1, 'Mettupalayam'),
        orgUnit(2, 'Annur', { branch_type: 'TOWN_PANCHAYAT' }),
      ]);

      const r = await service.overview('default');
      const annur = r.branch_map.find((b) => b.name === 'Annur');

      expect(annur).toBeDefined();
      expect(annur?.user_count).toBe(0);
      expect(annur?.coverage_pct).toBe(0);
    });
  });

  describe('activity', () => {
    it('buckets audit entries into a 30-day series', async () => {
      const today = new Date();
      prisma.auditLog.findMany.mockResolvedValue([
        {
          id: 1n,
          action: 'role_assigned',
          entity_type: 'user_role',
          entity_id: '5',
          user_id: 10,
          after_value: {},
          created_at: today,
        },
        {
          id: 2n,
          action: 'role_assigned',
          entity_type: 'user_role',
          entity_id: '6',
          user_id: null,
          after_value: {},
          created_at: today,
        },
      ]);
      prisma.user.findMany.mockResolvedValue([user(10)]);

      const r = await service.overview('default');

      expect(r.activity.days).toHaveLength(30);
      expect(r.activity.days.at(-1)?.count).toBe(2);
      expect(r.activity.by_action).toEqual([{ action: 'role_assigned', count: 2 }]);
      // An entry with no actor is the system acting, not a missing user.
      expect(r.activity.recent[1].actor).toBe('system');
    });
  });

  describe('totals', () => {
    it('reports screen coverage over non-platform screens only', async () => {
      prisma.role.findMany.mockResolvedValue([role(1, 'clerk', [1, 2])]);

      const r = await service.overview('default');

      // 2 of the 4 non-platform screens are granted to somebody.
      expect(r.totals.screen_coverage_pct).toBe(50);
    });

    it('excludes disabled roles from the active count', async () => {
      prisma.role.findMany.mockResolvedValue([
        role(1, 'clerk', [1]),
        role(2, 'retired', [1], { is_active: false }),
      ]);

      const r = await service.overview('default');

      expect(r.totals.roles).toBe(1);
      expect(r.totals.inactive_roles).toBe(1);
    });
  });
});
