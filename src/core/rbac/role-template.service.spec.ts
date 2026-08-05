import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { RoleTemplateService } from './role-template.service';

/** A role row shaped the way the service's includes return it. */
function role(over: Partial<Record<string, unknown>> = {}) {
  return {
    id: 1,
    tenant_id: 'coimbatore',
    name: 'health_officer',
    display_name: 'City Health Officer',
    display_name_ta: null,
    department: 'public_health',
    hierarchy_level: 4,
    is_super_admin: false,
    can_approve: true,
    is_system: true,
    is_active: true,
    applicable_branch_types: [],
    template_id: 100,
    customised_at: null,
    screen_access: [] as unknown[],
    permissions: [] as unknown[],
    ...over,
  };
}

const screens = (...keys: string[]) =>
  keys.map((key, i) => ({ can_view: true, screen_id: i + 1, screen: { key } }));

const perms = (...codes: string[]) =>
  codes.map((code, i) => ({ permission_id: i + 1, permission: { code } }));

describe('RoleTemplateService', () => {
  let service: RoleTemplateService;
  let prisma: {
    role: Record<string, jest.Mock>;
    roleScreenAccess: Record<string, jest.Mock>;
    rolePermission: Record<string, jest.Mock>;
    appScreen: Record<string, jest.Mock>;
    $transaction: jest.Mock;
  };
  let audit: { log: jest.Mock };

  beforeEach(async () => {
    prisma = {
      role: {
        findMany: jest.fn().mockResolvedValue([]),
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        findUniqueOrThrow: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      roleScreenAccess: {
        findMany: jest.fn().mockResolvedValue([]),
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      rolePermission: {
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      appScreen: { findMany: jest.fn().mockResolvedValue([]) },
      $transaction: jest.fn((fn: (tx: unknown) => unknown) => fn(prisma)),
    };
    audit = { log: jest.fn().mockResolvedValue(undefined) };

    const mod = await Test.createTestingModule({
      providers: [
        RoleTemplateService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditService, useValue: audit },
      ],
    }).compile();

    service = mod.get(RoleTemplateService);
  });

  // ── The rule that matters most ────────────────────────────────────────────

  describe('syncTenant', () => {
    it('leaves a role the tenant has customised completely alone', async () => {
      const customisedAt = new Date('2026-07-01T10:00:00Z');
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({
            id: 5,
            customised_at: customisedAt,
            screen_access: screens('complaints'),
            permissions: perms('complaints.read'),
          }),
        ])
        // The templates lookup.
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            screen_access: screens('complaints', 'water_quality'),
            permissions: perms('complaints.read', 'water.read'),
          }),
        ]);

      const report = await service.syncTenant('coimbatore', 9);

      expect(report.updated).toHaveLength(0);
      expect(report.skipped_customised).toEqual([
        { role_id: 5, name: 'health_officer', customised_at: customisedAt },
      ]);
      // Nothing was written, even though the template plainly differs.
      expect(prisma.roleScreenAccess.updateMany).not.toHaveBeenCalled();
      expect(prisma.rolePermission.deleteMany).not.toHaveBeenCalled();
    });

    it('updates an untouched role and reports exactly what changed', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({
            id: 5,
            customised_at: null,
            screen_access: screens('complaints', 'legacy_screen'),
            permissions: perms('complaints.read'),
          }),
        ])
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            screen_access: screens('complaints', 'water_quality'),
            permissions: perms('complaints.read', 'water.read'),
          }),
        ]);
      prisma.role.findUniqueOrThrow.mockResolvedValue({
        id: 100,
        screen_access: [
          { screen_id: 1, can_view: true },
          { screen_id: 2, can_view: true },
        ],
        permissions: [{ permission_id: 1 }, { permission_id: 2 }],
      });

      const report = await service.syncTenant('coimbatore', 9);

      expect(report.updated).toHaveLength(1);
      expect(report.updated[0]).toMatchObject({
        role_id: 5,
        name: 'health_officer',
        screens_added: ['water_quality'],
        screens_removed: ['legacy_screen'],
        permissions_added: ['water.read'],
        permissions_removed: [],
      });
      expect(prisma.rolePermission.deleteMany).toHaveBeenCalled();
    });

    it('never touches a role the tenant invented', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([role({ id: 7, template_id: null, name: 'ward_liaison' })])
        .mockResolvedValueOnce([]);

      const report = await service.syncTenant('coimbatore', 9);

      expect(report.untemplated).toBe(1);
      expect(report.updated).toHaveLength(0);
      expect(report.skipped_customised).toHaveLength(0);
    });

    it('counts a role that already matches as unchanged and writes nothing', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({ id: 5, screen_access: screens('complaints'), permissions: perms('complaints.read') }),
        ])
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            screen_access: screens('complaints'),
            permissions: perms('complaints.read'),
          }),
        ]);

      const report = await service.syncTenant('coimbatore', 9);

      expect(report.unchanged).toBe(1);
      expect(report.updated).toHaveLength(0);
      expect(prisma.rolePermission.deleteMany).not.toHaveBeenCalled();
      // Nothing changed, so there is nothing to record.
      expect(audit.log).not.toHaveBeenCalled();
    });

    it('a dry run reports the same changes but writes none of them', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({ id: 5, screen_access: [], permissions: [] }),
        ])
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            screen_access: screens('complaints'),
            permissions: perms('complaints.read'),
          }),
        ]);

      const report = await service.syncTenant('coimbatore', 9, { dryRun: true });

      expect(report.dry_run).toBe(true);
      expect(report.updated[0].screens_added).toEqual(['complaints']);
      expect(prisma.roleScreenAccess.createMany).not.toHaveBeenCalled();
      expect(prisma.rolePermission.createMany).not.toHaveBeenCalled();
      expect(audit.log).not.toHaveBeenCalled();
    });

    it('records a sync that changed something', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([role({ id: 5, screen_access: [], permissions: [] })])
        .mockResolvedValueOnce([
          role({ id: 100, tenant_id: '__system__', screen_access: screens('complaints'), permissions: [] }),
        ]);
      prisma.role.findUniqueOrThrow.mockResolvedValue({
        id: 100,
        screen_access: [{ screen_id: 1, can_view: true }],
        permissions: [],
      });

      await service.syncTenant('coimbatore', 9);

      expect(audit.log).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'roles_synced_from_templates',
          tenantId: 'coimbatore',
          userId: 9,
        }),
      );
    });

    it('a screen switched off in the template is revoked, not left enabled', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({ id: 5, screen_access: screens('complaints', 'tenders'), permissions: [] }),
        ])
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            // `tenders` present but switched off — the console revokes by
            // flipping can_view, so a template can say "no longer this one".
            screen_access: [
              { can_view: true, screen_id: 1, screen: { key: 'complaints' } },
              { can_view: false, screen_id: 2, screen: { key: 'tenders' } },
            ],
            permissions: [],
          }),
        ]);
      prisma.role.findUniqueOrThrow.mockResolvedValue({
        id: 100,
        screen_access: [
          { screen_id: 1, can_view: true },
          { screen_id: 2, can_view: false },
        ],
        permissions: [],
      });
      prisma.roleScreenAccess.findMany.mockResolvedValue([
        { screen_id: 1 },
        { screen_id: 2 },
      ]);

      const report = await service.syncTenant('coimbatore', 9);

      expect(report.updated[0].screens_removed).toEqual(['tenders']);
      expect(prisma.roleScreenAccess.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { role_id: 5, screen_id: { in: [2] } },
          data: { can_view: false },
        }),
      );
    });
  });

  // ── Provisioning ──────────────────────────────────────────────────────────

  describe('applyTemplates', () => {
    it('copies templates the body type allows and skips the rest', async () => {
      prisma.role.findMany
        // Templates.
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            name: 'municipal_commissioner',
            applicable_branch_types: ['MUNICIPAL_CORPORATION'],
            screen_access: [{ can_view: true, screen_id: 1 }],
            permissions: [{ permission_id: 1 }],
          }),
          role({
            id: 101,
            tenant_id: '__system__',
            name: 'panchayat_president',
            applicable_branch_types: ['VILLAGE_PANCHAYAT'],
            screen_access: [{ can_view: true, screen_id: 2 }],
            permissions: [],
          }),
          role({
            id: 102,
            tenant_id: '__system__',
            name: 'clerk',
            applicable_branch_types: [], // every body type
            screen_access: [],
            permissions: [],
          }),
        ])
        // What the tenant already holds.
        .mockResolvedValueOnce([]);
      prisma.role.create.mockImplementation(({ data }: { data: { name: string } }) =>
        Promise.resolve({ id: data.name.length, ...data }),
      );

      const out = await service.applyTemplates('village-x', 'VILLAGE_PANCHAYAT' as never);

      expect(out.created.sort()).toEqual(['clerk', 'panchayat_president']);
      expect(out.created).not.toContain('municipal_commissioner');
    });

    it('links every copy back to the template it came from', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({ id: 100, tenant_id: '__system__', screen_access: [], permissions: [] }),
        ])
        .mockResolvedValueOnce([]);
      prisma.role.create.mockResolvedValue({ id: 7 });

      await service.applyTemplates('coimbatore', null);

      expect(prisma.role.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            tenant_id: 'coimbatore',
            template_id: 100,
            customised_at: null,
          }),
        }),
      );
    });

    it('does not disturb a role the tenant already has', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({ id: 100, tenant_id: '__system__', name: 'clerk', screen_access: [], permissions: [] }),
        ])
        .mockResolvedValueOnce([{ name: 'clerk' }]);

      const out = await service.applyTemplates('coimbatore', null);

      expect(out.created).toEqual([]);
      expect(out.already_present).toBe(1);
      expect(prisma.role.create).not.toHaveBeenCalled();
    });

    it('copies grants in bulk rather than one statement at a time', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            name: 'a',
            screen_access: [
              { can_view: true, screen_id: 1 },
              { can_view: true, screen_id: 2 },
            ],
            permissions: [{ permission_id: 1 }],
          }),
          role({
            id: 101,
            tenant_id: '__system__',
            name: 'b',
            screen_access: [{ can_view: true, screen_id: 3 }],
            permissions: [{ permission_id: 2 }],
          }),
        ])
        .mockResolvedValueOnce([]);
      prisma.role.create
        .mockResolvedValueOnce({ id: 10 })
        .mockResolvedValueOnce({ id: 11 });

      await service.applyTemplates('coimbatore', null);

      // One call each, carrying every row — not one call per grant. A
      // provisioning transaction that issues 700 statements times out.
      expect(prisma.roleScreenAccess.createMany).toHaveBeenCalledTimes(1);
      expect(prisma.rolePermission.createMany).toHaveBeenCalledTimes(1);
      expect(prisma.roleScreenAccess.createMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: [
            { role_id: 10, screen_id: 1, can_view: true },
            { role_id: 10, screen_id: 2, can_view: true },
            { role_id: 11, screen_id: 3, can_view: true },
          ],
        }),
      );
    });

    it('never provisions a platform role into a client', async () => {
      // `super_admin` is offered for every body type because the platform
      // operator administers every body type. Copying it would give the client
      // its own role carrying `is_super_admin`, and a council administrator —
      // who can already assign roles inside their own tenant — could grant it
      // to themselves and step outside the tenant boundary.
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({ id: 102, tenant_id: '__system__', name: 'clerk', screen_access: [], permissions: [] }),
        ])
        .mockResolvedValueOnce([]);
      prisma.role.create.mockResolvedValue({ id: 10 });

      await service.applyTemplates('village-x', null);

      // The exclusion is in the query, so assert the query asked for it.
      expect(prisma.role.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            tenant_id: '__system__',
            is_super_admin: false,
          }),
        }),
      );
    });

    it('does not copy a platform-only screen into a client role', async () => {
      prisma.appScreen.findMany.mockResolvedValue([{ id: 9 }]); // `tenants`
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            screen_access: [
              { can_view: true, screen_id: 1 },
              { can_view: true, screen_id: 9 },
            ],
            permissions: [],
          }),
        ])
        .mockResolvedValueOnce([]);
      prisma.role.create.mockResolvedValue({ id: 10 });

      await service.applyTemplates('village-x', null);

      expect(prisma.roleScreenAccess.createMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: [{ role_id: 10, screen_id: 1, can_view: true }],
        }),
      );
    });

    it('does not copy a screen the template has switched off', async () => {
      prisma.role.findMany
        .mockResolvedValueOnce([
          role({
            id: 100,
            tenant_id: '__system__',
            screen_access: [
              { can_view: true, screen_id: 1 },
              { can_view: false, screen_id: 2 },
            ],
            permissions: [],
          }),
        ])
        .mockResolvedValueOnce([]);
      prisma.role.create.mockResolvedValue({ id: 10 });

      await service.applyTemplates('coimbatore', null);

      expect(prisma.roleScreenAccess.createMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: [{ role_id: 10, screen_id: 1, can_view: true }],
        }),
      );
    });
  });

  // ── Reads ─────────────────────────────────────────────────────────────────

  describe('diff', () => {
    it('reports how a role differs from its template', async () => {
      prisma.role.findFirst.mockResolvedValue(
        role({
          id: 5,
          screen_access: screens('complaints'),
          permissions: perms('complaints.read'),
        }),
      );
      prisma.role.findUnique.mockResolvedValue(
        role({
          id: 100,
          tenant_id: '__system__',
          screen_access: screens('complaints', 'water_quality'),
          permissions: perms('complaints.read'),
        }),
      );

      const d = await service.diff('coimbatore', 5);

      expect(d.template).toEqual({ id: 100, name: 'health_officer' });
      expect(d.screens_added).toEqual(['water_quality']);
      expect(d.screens_removed).toEqual([]);
    });

    it('returns an empty delta for a role with no template', async () => {
      prisma.role.findFirst.mockResolvedValue(
        role({ id: 7, template_id: null, screen_access: screens('x'), permissions: [] }),
      );

      const d = await service.diff('coimbatore', 7);

      expect(d.template).toBeNull();
      expect(d.screens_added).toEqual([]);
      expect(d.screens_removed).toEqual([]);
    });

    it('refuses to read a role belonging to another tenant', async () => {
      // findFirst is scoped by tenant_id, so a foreign role simply is not found.
      prisma.role.findFirst.mockResolvedValue(null);

      await expect(service.diff('coimbatore', 5)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('listTemplates', () => {
    it('narrows the catalogue to one body type, keeping the universal ones', async () => {
      prisma.role.findMany.mockResolvedValue([
        {
          ...role({ id: 100, name: 'municipal_commissioner', applicable_branch_types: ['MUNICIPAL_CORPORATION'] }),
          _count: { screen_access: 20, permissions: 40, instances: 3 },
        },
        {
          ...role({ id: 101, name: 'clerk', applicable_branch_types: [] }),
          _count: { screen_access: 5, permissions: 8, instances: 9 },
        },
      ]);

      const out = await service.listTemplates('VILLAGE_PANCHAYAT' as never);

      expect(out.map((t) => t.name)).toEqual(['clerk']);
      expect(out[0].in_use_by).toBe(9);
    });
  });
});
