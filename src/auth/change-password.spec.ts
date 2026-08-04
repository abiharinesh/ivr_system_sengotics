import {
  BadRequestException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { WhatsAppService } from '../whatsapp/whatsapp.service';
import { AuditService } from '../core/audit/audit.service';
import { RbacService } from '../core/rbac/rbac.service';
import { AuthService } from './auth.service';

/**
 * Covers the gate that had no endpoint behind it: accounts are provisioned
 * with `must_change_password = true`, and this is what clears it.
 */
describe('AuthService.changePassword', () => {
  let service: AuthService;

  const CURRENT = 'Issued#Temp42x';
  const NEXT = 'Kovai#Ward91z';

  const prisma = {
    user: { findUnique: jest.fn(), update: jest.fn() },
  };
  const jwt = { sign: jest.fn(() => 'signed.jwt.token') };
  const audit = { log: jest.fn() };
  const rbac = {
    entitlementsFor: jest.fn(async () => ({
      permissions: [],
      screens: [],
      roles: [],
      isSuperAdmin: false,
    })),
    platformScreens: jest.fn(async () => []),
  };

  const user = async (over: Record<string, any> = {}) => ({
    id: 42,
    tenant_id: 'default',
    email: 'registrar.annur@example.gov.in',
    role: 'registrar',
    user_type: 'employee',
    primary_org_unit_id: 7,
    password_hash: await bcrypt.hash(CURRENT, 4),
    must_change_password: true,
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
        { provide: AuditService, useValue: audit },
      ],
    }).compile();

    service = module.get(AuthService);
    jest.clearAllMocks();
    prisma.user.update.mockResolvedValue({});
  });

  it('clears the flag and stores a hash, never the password itself', async () => {
    prisma.user.findUnique.mockResolvedValue(await user());

    const r = await service.changePassword(42, CURRENT, NEXT);

    expect(r.success).toBe(true);
    expect(r.must_change_password).toBe(false);

    const data = prisma.user.update.mock.calls[0][0].data;
    expect(data.must_change_password).toBe(false);
    expect(data.password_hash).not.toBe(NEXT);
    expect(await bcrypt.compare(NEXT, data.password_hash)).toBe(true);
  });

  it('issues a fresh token so the client stops carrying the flagged one', async () => {
    prisma.user.findUnique.mockResolvedValue(await user());

    const r = await service.changePassword(42, CURRENT, NEXT);

    expect(r.access_token).toBe('signed.jwt.token');
    expect(jwt.sign).toHaveBeenCalled();
  });

  it('records the change without putting the password in the audit log', async () => {
    prisma.user.findUnique.mockResolvedValue(await user());

    await service.changePassword(42, CURRENT, NEXT);

    expect(audit.log).toHaveBeenCalledWith(
      expect.objectContaining({
        module: 'auth',
        action: 'password_changed',
        entityId: '42',
      }),
    );
    const entry = JSON.stringify(audit.log.mock.calls[0][0]);
    expect(entry).not.toContain(NEXT);
    expect(entry).not.toContain(CURRENT);
  });

  it('resets the failed-attempt counter', async () => {
    prisma.user.findUnique.mockResolvedValue(await user({ failed_attempts: 3 }));

    await service.changePassword(42, CURRENT, NEXT);

    expect(prisma.user.update.mock.calls[0][0].data.failed_attempts).toBe(0);
  });

  describe('refusals', () => {
    it('requires the current password even when the flag is set', async () => {
      // A session left open on a shared office machine must not be enough to
      // take the account over.
      prisma.user.findUnique.mockResolvedValue(await user());

      await expect(
        service.changePassword(42, 'not-the-password', NEXT),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('rejects a new password that fails the policy', async () => {
      prisma.user.findUnique.mockResolvedValue(await user());

      await expect(
        service.changePassword(42, CURRENT, 'password123'),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.user.update).not.toHaveBeenCalled();
    });

    it('refuses to set the password back to the current one', async () => {
      prisma.user.findUnique.mockResolvedValue(await user());

      await expect(
        service.changePassword(42, CURRENT, CURRENT),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('refuses a password built out of the account email', async () => {
      prisma.user.findUnique.mockResolvedValue(await user());

      await expect(
        service.changePassword(42, CURRENT, 'Registrar#42xy'),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('surfaces every failing rule in one message', async () => {
      prisma.user.findUnique.mockResolvedValue(await user());

      await expect(
        service.changePassword(42, CURRENT, 'abcdefghij'),
      ).rejects.toThrow(/uppercase.*digit|digit.*uppercase/i);
    });

    it('reports a missing account rather than a credential failure', async () => {
      prisma.user.findUnique.mockResolvedValue(null);

      await expect(
        service.changePassword(999, CURRENT, NEXT),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
