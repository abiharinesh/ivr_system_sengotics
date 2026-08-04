import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { RbacAdminService } from './rbac-admin.service';

/**
 * A tenant defining its own designation.
 *
 * Before this there was only `cloneRole`: a council could copy one of the
 * shipped roles but never define one. Every job title the seeded roster
 * happens not to have — which is most of them once you leave the six Tamil
 * Nadu body types — had to come back to the platform operator.
 */
describe('RbacAdminService.createRole', () => {
  let service: RbacAdminService;

  const prisma = {
    role: { findFirst: jest.fn(), create: jest.fn(), findUnique: jest.fn() },
  };
  const audit = { log: jest.fn() };

  const input = {
    name: 'ward_committee_secretary',
    display_name: 'Ward Committee Secretary',
  };

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

    prisma.role.findFirst.mockResolvedValue(null); // no clash
    prisma.role.create.mockResolvedValue({ id: 99 });
    // `createRole` returns via getRole.
    prisma.role.findFirst.mockImplementation(async (args: any) =>
      args?.where?.id === 99
        ? {
            id: 99,
            tenant_id: 'tn_govt',
            name: input.name,
            display_name: input.display_name,
            permissions: [],
            screen_access: [],
            _count: { user_roles: 0 },
          }
        : null,
    );
  });

  const created = () => prisma.role.create.mock.calls[0][0].data;

  it('creates the role inside the caller tenant', async () => {
    await service.createRole('tn_govt', 1, input);

    expect(created()).toMatchObject({
      tenant_id: 'tn_govt',
      name: 'ward_committee_secretary',
      display_name: 'Ward Committee Secretary',
      org_unit_id: null,
    });
  });

  it('starts with no grants at all', async () => {
    await service.createRole('tn_govt', 1, input);

    // A new designation that could see everything by default would be a way
    // to escalate by creating rather than by being granted.
    const data = created();
    expect(data.permissions).toBeUndefined();
    expect(data.screen_access).toBeUndefined();
    expect(data.is_super_admin).toBe(false);
  });

  it('is deletable by the tenant that made it', async () => {
    await service.createRole('tn_govt', 1, input);
    expect(created().is_system).toBe(false);
  });

  describe('the name', () => {
    it('is normalised to a decorator-safe form', async () => {
      await service.createRole('tn_govt', 1, {
        ...input,
        name: 'Ward Committee-Secretary!',
      });
      expect(created().name).toBe('ward_committee_secretary_');
    });

    it('is required', async () => {
      await expect(
        service.createRole('tn_govt', 1, { ...input, name: '   ' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('cannot collide with a shipped role', async () => {
      // A collision would silently inherit that role's API access, because
      // `@Roles()` matches on the name string.
      prisma.role.findFirst.mockResolvedValue({
        id: 3,
        tenant_id: '__system__',
        name: 'registrar',
      });

      await expect(
        service.createRole('tn_govt', 1, { ...input, name: 'registrar' }),
      ).rejects.toThrow(/shipped role name/i);
    });

    it('cannot collide with one the tenant already has', async () => {
      prisma.role.findFirst.mockResolvedValue({
        id: 4,
        tenant_id: 'tn_govt',
        name: 'ward_committee_secretary',
      });

      await expect(service.createRole('tn_govt', 1, input)).rejects.toThrow(
        /already has a role named/i,
      );
    });

    it('is refused when absurdly long', async () => {
      await expect(
        service.createRole('tn_govt', 1, { ...input, name: 'a'.repeat(80) }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('the display name', () => {
    it('is required', async () => {
      await expect(
        service.createRole('tn_govt', 1, { ...input, display_name: '  ' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('hierarchy level', () => {
    it('defaults to staff level', async () => {
      await service.createRole('tn_govt', 1, input);
      expect(created().hierarchy_level).toBe(5);
    });

    it('refuses level 0, which is the platform operator rung', async () => {
      await expect(
        service.createRole('tn_govt', 1, { ...input, hierarchy_level: 0 }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('refuses a level past the bottom of the chain', async () => {
      await expect(
        service.createRole('tn_govt', 1, { ...input, hierarchy_level: 11 }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  it('records the creation in the audit log', async () => {
    await service.createRole('tn_govt', 1, input);

    expect(audit.log).toHaveBeenCalledWith(
      expect.objectContaining({
        module: 'rbac',
        action: 'role_created',
        tenantId: 'tn_govt',
      }),
    );
  });
});
