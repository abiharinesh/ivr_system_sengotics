import { Test, TestingModule } from '@nestjs/testing';
import { AdCampaignService } from './ad-campaign.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

describe('AdCampaignService', () => {
  let service: AdCampaignService;
  let prisma: any;

  const mockPrisma = {
    adCampaign: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    adImpression: {
      create: jest.fn(),
      groupBy: jest.fn(),
    },
    $transaction: jest.fn((promises) => Promise.all(promises)),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdCampaignService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<AdCampaignService>(AdCampaignService);
    prisma = module.get<PrismaService>(PrismaService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getActiveAdForPole', () => {
    it('should return pole-targeted campaign if found', async () => {
      const mockCampaign = { id: 10, title: 'Pole Specific Ad' };
      mockPrisma.adCampaign.findFirst.mockResolvedValueOnce(mockCampaign);

      const result = await service.getActiveAdForPole(1, 100);
      expect(result).toEqual(mockCampaign);
      expect(mockPrisma.adCampaign.findFirst).toHaveBeenCalledTimes(1);
    });

    it('should fallback to panchayat-wide campaign if pole-targeted is null', async () => {
      const mockFallback = { id: 20, title: 'Panchayat Wide Ad' };
      mockPrisma.adCampaign.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(mockFallback);

      const result = await service.getActiveAdForPole(1, 100);
      expect(result).toEqual(mockFallback);
      expect(mockPrisma.adCampaign.findFirst).toHaveBeenCalledTimes(2);
    });
  });

  describe('createCampaign', () => {
    it('should create campaign with default standard type', async () => {
      const data = {
        org_unit_id: 1,
        advertiser_name: 'Test Advertiser',
        title: 'Launch Offer',
        amount_paid: 1500,
        starts_at: '2026-01-01',
        ends_at: '2026-12-31',
      };
      mockPrisma.adCampaign.create.mockImplementation((args) => Promise.resolve({ id: 1, ...args.data }));

      const res = await service.createCampaign(data);
      expect(res.title).toBe('Launch Offer');
      expect(res.campaign_type).toBe('standard');
    });
  });

  describe('getCampaignById', () => {
    it('should throw NotFoundException if campaign missing', async () => {
      mockPrisma.adCampaign.findUnique.mockResolvedValueOnce(null);
      await expect(service.getCampaignById(999)).rejects.toThrow(NotFoundException);
    });
  });
});
