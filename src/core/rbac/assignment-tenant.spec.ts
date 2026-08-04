import { ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { RbacAdminService } from './rbac-admin.service';

/**
 * A role assignment carries its own tenant.
 *
 * It used to be reachable only transitively, through the role and the branch,
 * so every authorization query had to join two tables to establish the
 * boundary — and nothing stopped a role from one tenant being assigned at
 * another tenant's branch. A database trigger now refuses a mismatched row;
 * these cover the application side that has to populate it correctly.
 */
describe('RbacAdminService.assignRole — tenant on the assignment', () => {
  let service: RbacAdminService;

  const prisma = {
    user: { findFirst: jest.fn() },
    role: { findFirst: jest.fn() },
    orgUnit: { findFirst: jest.fn() },
    userRole: { upsert: jest.fn(), updateMany: jest.fn() },
  };
  const audit = { log: jest.fn() };

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

    prisma.user.findFirst.mockResolvedValue({ id: 42, tenant_id: 'tn_govt' });
    prisma.role.findFirst.mockResolvedValue({
      id: 7,
      name: 'registrar',
      display_name: 'Registrar',
      applicable_branch_types: [],
    });
    prisma.orgUnit.findFirst.mockResolvedValue({
      id: 10,
      tenant_id: 'tn_govt',
      branch_type: 'MUNICIPALITY',
    });
    prisma.userRole.upsert.mockResolvedValue({ id: 1 });
    prisma.userRole.updateMany.mockResolvedValue({ count: 0 });
  });

  it("stamps the branch's tenant onto the assignment", async () => {
    await service.assignRole('tn_govt', 42, 1, 7, 10);

    const created = prisma.userRole.upsert.mock.calls[0][0].create;
    expect(created.tenant_id).toBe('tn_govt');
  });

  it('takes the tenant from the branch, not from the caller', async () => {
    // The branch is the authoritative owner of a posting. Trusting the
    // caller's own tenant would let a stale token write a mismatched row that
    // the database then refuses, turning a clear refusal into a 500.
    prisma.orgUnit.findFirst.mockResolvedValue({
      id: 10,
      tenant_id: 'tn_govt',
      branch_type: 'MUNICIPALITY',
    });

    await service.assignRole('tn_govt', 42, 1, 7, 10);

    expect(prisma.userRole.upsert.mock.calls[0][0].create.tenant_id).toBe('tn_govt');
  });

  it('refuses a branch outside the caller tenant before writing anything', async () => {
    prisma.orgUnit.findFirst.mockResolvedValue(null);

    await expect(service.assignRole('tn_govt', 42, 1, 7, 99)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(prisma.userRole.upsert).not.toHaveBeenCalled();
  });

  it('still records who granted it and at which branch', async () => {
    await service.assignRole('tn_govt', 42, 1, 7, 10, true);

    const created = prisma.userRole.upsert.mock.calls[0][0].create;
    expect(created).toMatchObject({
      user_id: 42,
      role_id: 7,
      org_unit_id: 10,
      granted_by: 1,
      is_primary: true,
    });
  });

  it('clears any previous primary before setting a new one', async () => {
    await service.assignRole('tn_govt', 42, 1, 7, 10, true);

    // Two primaries would make the working branch ambiguous, and the
    // entitlement resolver reads provisioning from the primary assignment.
    expect(prisma.userRole.updateMany).toHaveBeenCalledWith({
      where: { user_id: 42 },
      data: { is_primary: false },
    });
  });
});
