import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { FeatureGateService, GateResult } from './feature-gate.service';
import { PermissionCacheService } from './permission-cache.service';

describe('FeatureGateService', () => {
  let service: FeatureGateService;

  const prisma = {
    user: { findUnique: jest.fn() },
    tenantFeatureConfig: { findUnique: jest.fn() },
    tenantRoleTemplate: { findMany: jest.fn() },
    rolePermission: { findMany: jest.fn() },
    branchFeatureConfig: { findUnique: jest.fn() },
  };
  const cache = {};

  const assignment = (over: Record<string, unknown> = {}) => ({
    tenant_id: 'tenant-a',
    role_id: 1,
    valid_until: null,
    role: {
      id: 1,
      tenant_id: 'tenant-a',
      template_id: null,
      is_active: true,
      is_super_admin: false,
    },
    ...over,
  });

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FeatureGateService,
        { provide: PrismaService, useValue: prisma },
        { provide: PermissionCacheService, useValue: cache },
      ],
    }).compile();
    service = module.get(FeatureGateService);
    jest.clearAllMocks();
    prisma.tenantFeatureConfig.findUnique.mockResolvedValue(null);
    prisma.tenantRoleTemplate.findMany.mockResolvedValue([]);
    prisma.rolePermission.findMany.mockResolvedValue([{ id: 1 }]);
    prisma.branchFeatureConfig.findUnique.mockResolvedValue(null);
  });

  it('denies a request evaluated against a tenant other than the user tenant', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 7,
      tenant_id: 'tenant-a',
      role: 'employee',
      user_roles: [assignment()],
    });

    await expect(
      service.evaluate({
        userId: 7,
        tenantId: 'tenant-b',
        permissionCode: 'users.read',
      }),
    ).resolves.toBe(GateResult.DENY);
  });

  it('removes a disabled template role but permits another active role with the grant', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 7,
      tenant_id: 'tenant-a',
      role: 'employee',
      user_roles: [
        assignment({
          role_id: 1,
          role: {
            id: 1,
            tenant_id: 'tenant-a',
            template_id: 10,
            is_active: true,
            is_super_admin: false,
          },
        }),
        assignment({
          role_id: 2,
          role: {
            id: 2,
            tenant_id: 'tenant-a',
            template_id: null,
            is_active: true,
            is_super_admin: false,
          },
        }),
      ],
    });
    prisma.tenantRoleTemplate.findMany.mockResolvedValue([
      { role_template_id: 10 },
    ]);

    await expect(
      service.evaluate({
        userId: 7,
        tenantId: 'tenant-a',
        permissionCode: 'users.read',
      }),
    ).resolves.toBe(GateResult.ALLOW);

    expect(prisma.rolePermission.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { role_id: { in: [2] }, permission: { code: 'users.read' } },
      }),
    );
  });
});
