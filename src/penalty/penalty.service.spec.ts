import { Test, TestingModule } from '@nestjs/testing';
import { PenaltyService } from './penalty.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

describe('PenaltyService', () => {
  let service: PenaltyService;

  const mockPrisma = {
    complaint: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
    },
    penaltyRule: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
      findMany: jest.fn(),
    },
    userPenalty: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PenaltyService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<PenaltyService>(PenaltyService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('upsertRule', () => {
    it('should upsert penalty rule for role and urgency level', async () => {
      mockPrisma.penaltyRule.upsert.mockResolvedValueOnce({
        id: 1,
        panchayat_id: 10,
        role: 'electrician',
        urgency_level: 'high',
        deadline_hours: 12,
        penalty_amount: 200,
      });

      const res = await service.upsertRule({
        panchayat_id: 10,
        role: 'electrician',
        urgency_level: 'high',
        deadline_hours: 12,
        penalty_amount: 200,
      });

      expect(res.penalty_amount).toBe(200);
      expect(mockPrisma.penaltyRule.upsert).toHaveBeenCalledTimes(1);
    });
  });

  describe('waivePenalty', () => {
    it('should waive a pending penalty record', async () => {
      mockPrisma.userPenalty.findUnique.mockResolvedValueOnce({ id: 50 });
      mockPrisma.userPenalty.update.mockResolvedValueOnce({
        id: 50,
        status: 'waived',
        waived_reason: 'Genuine medical delay',
      });

      const result = await service.waivePenalty(50, 'Genuine medical delay');
      expect(result.status).toBe('waived');
    });

    it('should throw NotFoundException if penalty missing', async () => {
      mockPrisma.userPenalty.findUnique.mockResolvedValueOnce(null);
      await expect(service.waivePenalty(999, 'Reason')).rejects.toThrow(NotFoundException);
    });
  });
});
