import { BadRequestException } from '@nestjs/common';
import { TenderPublicService } from './public.service';

describe('TenderPublicService', () => {
  const makeService = () => {
    const prisma: any = {
      tender: { findUnique: jest.fn() },
      tenderLineItem: { findMany: jest.fn() },
      tenderQuotation: {
        count: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      tenderVendorInvite: { findFirst: jest.fn(), update: jest.fn() },
    };
    const storage: any = { saveBuffer: jest.fn() };
    const milestones: any = { resolveForTender: jest.fn() };
    const audit: any = { record: jest.fn() };
    const vendors: any = { upsertStubByPhone: jest.fn() };
    const service = new TenderPublicService(
      prisma,
      storage,
      milestones,
      audit,
      vendors,
    );
    return { service, prisma, milestones };
  };

  it('marks invite as opened during invite read', async () => {
    const { service, prisma, milestones } = makeService();
    prisma.tenderVendorInvite.findFirst.mockResolvedValue({
      id: 77,
      tender_id: 7,
      invite_token: 'inv123',
      invite_opened_at: null,
      invite_submitted_at: null,
      invite_expires_at: null,
      vendor: {
        id: 3,
        name: 'Vendor One',
        phone_e164: '+919000000001',
        place: 'Town',
      },
      tender: {
        id: 7,
        title_ta: null,
        title_en: 'Street light work',
        narrative_ta: null,
        narrative_en: null,
        status: 'published',
        anchor_date: null,
        quotation_access_mode: 'invited_only',
        panchayat: { id: 1, name: 'Test Panchayat' },
      },
    });
    prisma.tenderLineItem.findMany.mockResolvedValue([]);
    prisma.tenderQuotation.count.mockResolvedValue(0);
    milestones.resolveForTender.mockResolvedValue({ dates: {} });

    const out = await service.readInvite('inv123');
    expect(out.access_type).toBe('invite_only');
    expect(prisma.tenderVendorInvite.update).toHaveBeenCalledTimes(1);
  });

  it('rejects open submissions when tender is invite-only', async () => {
    const { service, prisma } = makeService();
    prisma.tender.findUnique.mockResolvedValue({
      id: 5,
      panchayat_id: 1,
      panchayat: { id: 1, name: 'Panchayat' },
      status: 'published',
      quotation_access_mode: 'invited_only',
    });

    await expect(
      service.submitOpenQuotation({
        publicToken: 'pub123',
        body: { name: 'A', phone: '9876543210', amount: '1000' },
        ipAddress: '127.0.0.1',
        attachment: null,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects open submissions after quotation deadline', async () => {
    const { service, prisma, milestones } = makeService();
    prisma.tender.findUnique.mockResolvedValue({
      id: 9,
      panchayat_id: 1,
      panchayat: { id: 1, name: 'Panchayat' },
      status: 'published',
      quotation_access_mode: 'open_with_phone',
    });
    milestones.resolveForTender.mockResolvedValue({
      dates: { quotation_deadline: '2000-01-01T00:00:00.000Z' },
    });

    await expect(
      service.submitOpenQuotation({
        publicToken: 'open123',
        body: { name: 'B', phone: '9876543210', amount: '1200' },
        ipAddress: '127.0.0.1',
        attachment: null,
      }),
    ).rejects.toThrow(BadRequestException);
  });
});
