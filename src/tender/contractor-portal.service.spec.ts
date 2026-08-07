import { Test } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ContractorPortalService } from './contractor-portal.service';

/**
 * A contractor's own view, and the boundary around it.
 *
 * The interesting cases are all about what must *not* come back: another
 * firm's quotations, a tender they were never invited to, or anything at all
 * for a login that is not a registered contractor.
 */
describe('ContractorPortalService', () => {
  let service: ContractorPortalService;
  let prisma: {
    contractor: Record<string, jest.Mock>;
    tenderInvite: Record<string, jest.Mock>;
    tenderQuotation: Record<string, jest.Mock>;
  };

  const FIRM = { id: 7, name: 'Sree Enterprises', tenant_id: 'default', blacklisted: false };

  /**
   * An invite row shaped the way the service's include returns it.
   *
   * `tenderId` sets both the join column and the nested tender's own id — the
   * service reads the latter, and a fixture where the two disagree tests
   * nothing anybody will ever hit.
   */
  const invite = (over: Record<string, unknown> = {}, tenderId = 100) => ({
    id: 1,
    tender_id: tenderId,
    contractor_id: 7,
    created_at: new Date('2026-07-01'),
    invite_expires_at: new Date('2099-01-01'),
    invite_revoked_at: null,
    invite_opened_at: null,
    invite_submitted_at: null,
    tender: {
      id: tenderId,
      title_en: 'Street light LED replacement',
      title_ta: null,
      status: 'published',
      awarded_quotation_id: null,
      org_unit: { id: 1, name: 'Tiruppur City', district: 'Tiruppur' },
      line_items: [{ id: 1 }, { id: 2 }],
    },
    ...over,
  });

  beforeEach(async () => {
    prisma = {
      contractor: { findFirst: jest.fn().mockResolvedValue(FIRM) },
      tenderInvite: { findMany: jest.fn().mockResolvedValue([]), findFirst: jest.fn() },
      tenderQuotation: { findMany: jest.fn().mockResolvedValue([]) },
    };

    const mod = await Test.createTestingModule({
      providers: [
        ContractorPortalService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = mod.get(ContractorPortalService);
  });

  describe('who the caller is', () => {
    it('refuses a login not linked to a registered contractor', async () => {
      // Defaulting to "show everything" here would hand one firm the whole
      // procurement pipeline.
      prisma.contractor.findFirst.mockResolvedValue(null);

      await expect(service.myInvites(1)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('resolves the firm from the login, never from the request', async () => {
      await service.myInvites(42);

      expect(prisma.contractor.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ user_id: 42, is_deleted: false }),
        }),
      );
      expect(prisma.tenderInvite.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ contractor_id: FIRM.id }),
        }),
      );
    });

    it('ignores a soft-deleted contractor record', async () => {
      await service.myInvites(1);

      const where = prisma.contractor.findFirst.mock.calls[0][0].where;
      expect(where.is_deleted).toBe(false);
    });
  });

  describe('what state an invitation is in', () => {
    it('is awaiting a quote when nothing has been submitted', async () => {
      prisma.tenderInvite.findMany.mockResolvedValue([invite()]);

      const out = await service.myInvites(1);

      expect(out.tenders[0].state).toBe('awaiting_your_quote');
      expect(out.totals.awaiting).toBe(1);
    });

    it('is submitted once a quotation exists, even without the invite flag',
      async () => {
        // Quoting through the public link records the quotation but does not
        // always stamp the invite; the contractor has still answered.
        prisma.tenderInvite.findMany.mockResolvedValue([invite()]);
        prisma.tenderQuotation.findMany.mockResolvedValue([
          {
            tender_id: 100,
            amount: 760000,
            submitted_at: new Date('2026-07-10'),
            screening_outcome: 'pending',
          },
        ]);

        const out = await service.myInvites(1);

        expect(out.tenders[0].state).toBe('submitted');
        expect(out.tenders[0].my_quote).toEqual({
          amount: 760000,
          submitted_at: new Date('2026-07-10'),
          outcome: 'pending',
        });
      });

    it('is closed once the deadline has passed unanswered', async () => {
      prisma.tenderInvite.findMany.mockResolvedValue([
        invite({ invite_expires_at: new Date('2020-01-01') }),
      ]);

      const out = await service.myInvites(1);

      expect(out.tenders[0].state).toBe('closed');
    });

    it('is withdrawn when the council revoked it, whatever else is true',
      async () => {
        prisma.tenderInvite.findMany.mockResolvedValue([
          invite({
            invite_revoked_at: new Date('2026-07-05'),
            invite_submitted_at: new Date('2026-07-04'),
          }),
        ]);

        const out = await service.myInvites(1);

        expect(out.tenders[0].state).toBe('withdrawn');
      });
  });

  describe('ordering', () => {
    it('puts what needs answering first, soonest deadline at the top', async () => {
      prisma.tenderInvite.findMany.mockResolvedValue([
        invite({ id: 1, invite_submitted_at: new Date() }, 1),
        invite({ id: 2, invite_expires_at: new Date('2099-12-01') }, 2),
        invite({ id: 3, invite_expires_at: new Date('2099-01-01') }, 3),
        invite({ id: 4, invite_expires_at: new Date('2020-01-01') }, 4),
      ]);

      const out = await service.myInvites(1);

      // Two awaiting (soonest first), then submitted, then closed.
      expect(out.tenders.map((t) => t.tender_id)).toEqual([3, 2, 1, 4]);
    });
  });

  describe('what it does not return', () => {
    it('asks only for its own quotations', async () => {
      prisma.tenderInvite.findMany.mockResolvedValue([invite()]);

      await service.myInvites(1);

      // Scoped by contractor id, not just by tender — a bug in the tender
      // filter must not widen into another bidder's amounts.
      expect(prisma.tenderQuotation.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ contractor_id: FIRM.id }),
        }),
      );
    });

    it('does not claim a win when somebody else was awarded the tender',
      async () => {
        prisma.tenderInvite.findMany.mockResolvedValue([
          invite({ tender: { ...invite().tender, awarded_quotation_id: 999 } }),
        ]);
        prisma.tenderQuotation.findMany.mockResolvedValue([
          {
            tender_id: 100,
            amount: 800000,
            submitted_at: new Date(),
            screening_outcome: 'rejected',
          },
        ]);

        const out = await service.myInvites(1);

        expect(out.tenders[0].won).toBe(false);
      });
  });

  describe('myTender', () => {
    it('refuses a tender this contractor was not invited to', async () => {
      prisma.tenderInvite.findFirst.mockResolvedValue(null);

      await expect(service.myTender(1, 555)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('looks the tender up through the invite, not by id alone', async () => {
      prisma.tenderInvite.findFirst.mockResolvedValue(invite());

      await service.myTender(1, 100);

      expect(prisma.tenderInvite.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { contractor_id: FIRM.id, tender_id: 100 },
        }),
      );
    });

    it('returns the work but not who else is bidding', async () => {
      prisma.tenderInvite.findFirst.mockResolvedValue(invite());

      const out = await service.myTender(1, 100);

      expect(out.title).toBe('Street light LED replacement');
      expect(out.line_items).toHaveLength(2);
      expect(out).not.toHaveProperty('quotations');
      expect(out).not.toHaveProperty('invites');
    });
  });

  it('reports the firm and its standing alongside the list', async () => {
    prisma.contractor.findFirst.mockResolvedValue({ ...FIRM, blacklisted: true });

    const out = await service.myInvites(1);

    expect(out.contractor).toEqual({ id: 7, name: 'Sree Enterprises' });
    expect(out.blacklisted).toBe(true);
  });
});
