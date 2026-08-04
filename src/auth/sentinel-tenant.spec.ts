import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { WhatsAppService } from '../whatsapp/whatsapp.service';
import { AuditService } from '../core/audit/audit.service';
import { RbacService } from '../core/rbac/rbac.service';
import { AuthService } from './auth.service';

/**
 * `__system__` holds cross-tenant role templates. It owns no org units and no
 * records, and every service scopes its reads by the caller's tenant — so an
 * account issued there signs in and finds an empty product: no roles, no
 * colleagues, no dashboard panels.
 *
 * That is exactly what happened to `superadmin@sengotics.com`. It looked fine
 * only because `listRoles` reads `tenant_id IN (yours, '__system__')` and the
 * whole role roster used to live there too; once the roster moved into the
 * operating tenant so it could be edited, every screen went blank.
 */
describe('AuthService — sentinel tenant placement', () => {
  let service: AuthService;
  let signed: Record<string, any>;

  const PASSWORD = 'Kovai#Ward42x';

  const prisma = {
    user: { findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
    orgUnit: { findUnique: jest.fn(), findFirst: jest.fn() },
    employee: { findFirst: jest.fn() },
    userRole: { findFirst: jest.fn(), findMany: jest.fn() },
  };
  const jwt = {
    sign: jest.fn((p: Record<string, any>) => {
      signed = p;
      return 'signed.jwt';
    }),
  };
  const rbac = {
    entitlementsFor: jest.fn(async () => ({
      permissions: [], screens: [], roles: [], isSuperAdmin: true,
    })),
    platformScreens: jest.fn(async () => []),
  };

  const user = (over: Record<string, any> = {}) => ({
    id: 8,
    email: 'superadmin@sengotics.com',
    role: 'super_admin',
    user_type: 'employee',
    tenant_id: '__system__',
    primary_org_unit_id: 10,
    password_hash: 'x',
    must_change_password: false,
    ...over,
  });

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwt },
        { provide: WhatsAppService, useValue: { sendText: jest.fn() } },
        { provide: RbacService, useValue: rbac },
        { provide: AuditService, useValue: { log: jest.fn() } },
      ],
    }).compile();

    service = module.get(AuthService);
    jest.clearAllMocks();
    signed = {};
    prisma.employee.findFirst.mockResolvedValue(null);
    prisma.userRole.findFirst.mockResolvedValue(null);
    prisma.userRole.findMany.mockResolvedValue([]);
    prisma.orgUnit.findUnique.mockResolvedValue(null);
  });

  /**
   * `buildJwtPayload` is private, so the claims it signs are the observable.
   * Driven through `login`, which is the path that actually mints a token for
   * a signing-in user.
   */
  const tokenFor = async (u: Record<string, any>) => {
    prisma.user.findFirst.mockResolvedValue({
      ...u,
      password_hash: await bcrypt.hash(PASSWORD, 4),
    });
    prisma.user.update.mockResolvedValue({});
    await service.login(u.email, PASSWORD);
    return signed;
  };

  it('scopes a sentinel-placed account to its branch tenant, not the sentinel', async () => {
    prisma.orgUnit.findUnique.mockResolvedValue({ tenant_id: 'default' });

    const payload = await tokenFor(user());

    expect(payload.tenant_id).toBe('default');
    expect(payload.tenant_id).not.toBe('__system__');
  });

  it('falls back to the operating tenant when the account has no branch', async () => {
    const payload = await tokenFor(user({ primary_org_unit_id: null }));

    expect(payload.tenant_id).toBe('default');
  });

  it('does not trust a branch that is itself in the sentinel tenant', async () => {
    prisma.orgUnit.findUnique.mockResolvedValue({ tenant_id: '__system__' });

    const payload = await tokenFor(user());

    expect(payload.tenant_id).toBe('default');
  });

  it('survives the branch lookup failing rather than issuing a sentinel token', async () => {
    prisma.orgUnit.findUnique.mockRejectedValue(new Error('connection lost'));

    const payload = await tokenFor(user());

    expect(payload.tenant_id).toBe('default');
  });

  it('leaves a correctly placed account alone', async () => {
    // The branch here belongs to a different tenant than the user. A sound
    // account must keep its own tenant regardless — the resolver only runs
    // for sentinel placements, so the branch must not override it.
    prisma.orgUnit.findUnique.mockResolvedValue({ tenant_id: 'default' });

    const payload = await tokenFor(user({ tenant_id: 'tn_govt' }));

    expect(payload.tenant_id).toBe('tn_govt');
  });
});
