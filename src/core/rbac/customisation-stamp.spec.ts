import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { RbacAdminService } from './rbac-admin.service';

/**
 * The moment a council makes a shipped role their own.
 *
 * A role provisioned from a template starts identical to it, and a template
 * sync may carry later improvements across. That stops being welcome the
 * instant the council edits the grants themselves: a sync would then revert a
 * deliberate decision, and unlike being left on an old default that is
 * invisible until somebody loses access they were given on purpose.
 *
 * So the first edit stamps `customised_at`, and the sync skips anything
 * stamped. These tests pin the stamping — the skipping is pinned in
 * `role-template.service.spec.ts`.
 */
describe('RbacAdminService — customisation stamp', () => {
  let service: RbacAdminService;

  const prisma = {
    role: { findUnique: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
    appScreen: { findMany: jest.fn() },
    permission: { findMany: jest.fn() },
    roleScreenAccess: { findMany: jest.fn(), upsert: jest.fn() },
    rolePermission: { findMany: jest.fn(), deleteMany: jest.fn(), createMany: jest.fn() },
    $transaction: jest.fn().mockResolvedValue([]),
  };
  const audit = { log: jest.fn() };

  /** The role `editableRole` will load. */
  function editing(over: Record<string, unknown> = {}) {
    prisma.role.findUnique.mockResolvedValue({
      id: 5,
      tenant_id: 'coimbatore',
      name: 'health_officer',
      display_name: 'City Health Officer',
      is_super_admin: false,
      template_id: 100,
      customised_at: null,
      ...over,
    });
  }

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RbacAdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditService, useValue: audit },
      ],
    }).compile();

    service = module.get(RbacAdminService);
    jest.clearAllMocks();

    prisma.appScreen.findMany.mockResolvedValue([
      { id: 1, key: 'complaints', is_platform_only: false },
      { id: 2, key: 'water_quality', is_platform_only: false },
    ]);
    prisma.permission.findMany.mockResolvedValue([
      { id: 1, code: 'complaints.read' },
    ]);
    prisma.roleScreenAccess.findMany.mockResolvedValue([]);
    prisma.roleScreenAccess.upsert.mockResolvedValue({});
    prisma.rolePermission.findMany.mockResolvedValue([]);
    prisma.role.update.mockResolvedValue({});

    // Both setters return via getRole, which reads with findFirst.
    prisma.role.findFirst.mockResolvedValue({
      id: 5,
      tenant_id: 'coimbatore',
      name: 'health_officer',
      permissions: [],
      screen_access: [],
      _count: { user_roles: 0 },
    });
  });

  it('stamps the role the first time its screens are changed', async () => {
    editing();

    await service.setRoleScreens('coimbatore', 5, 9, ['complaints']);

    expect(prisma.role.update).toHaveBeenCalledWith({
      where: { id: 5 },
      data: { customised_at: expect.any(Date) },
    });
  });

  it('stamps the role the first time its permissions are changed', async () => {
    editing();

    await service.setRolePermissions('coimbatore', 5, 9, ['complaints.read']);

    expect(prisma.role.update).toHaveBeenCalledWith({
      where: { id: 5 },
      data: { customised_at: expect.any(Date) },
    });
  });

  it('does not re-stamp a role that is already customised', async () => {
    // Re-stamping would move the date forward on every edit and lose when the
    // council first departed from the shipped default.
    editing({ customised_at: new Date('2026-07-01T00:00:00Z') });

    await service.setRoleScreens('coimbatore', 5, 9, ['complaints']);

    expect(prisma.role.update).not.toHaveBeenCalled();
  });

  it('does not stamp a role the tenant invented', async () => {
    // No template means nothing to drift from, and nothing a sync would touch.
    editing({ template_id: null });

    await service.setRoleScreens('coimbatore', 5, 9, ['complaints']);

    expect(prisma.role.update).not.toHaveBeenCalled();
  });

  it('still applies the grants it was asked to apply', async () => {
    // The stamp is a side effect; it must not replace the actual edit.
    editing();

    await service.setRoleScreens('coimbatore', 5, 9, ['complaints']);

    expect(prisma.roleScreenAccess.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { role_id_screen_id: { role_id: 5, screen_id: 1 } },
        update: { can_view: true, granted_by: 9 },
      }),
    );
    expect(prisma.roleScreenAccess.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { role_id_screen_id: { role_id: 5, screen_id: 2 } },
        update: { can_view: false, granted_by: 9 },
      }),
    );
  });
});
