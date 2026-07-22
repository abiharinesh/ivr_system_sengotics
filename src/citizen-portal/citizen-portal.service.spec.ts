import { Test, TestingModule } from '@nestjs/testing';
import { CitizenPortalService } from './citizen-portal.service';
import { PrismaService } from '../prisma/prisma.service';
import { BadRequestException } from '@nestjs/common';

describe('CitizenPortalService', () => {
  let service: CitizenPortalService;

  const mockPrisma = {
    citizenProfile: {
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    announcement: {
      create: jest.fn(),
      findMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CitizenPortalService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<CitizenPortalService>(CitizenPortalService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createProfile', () => {
    it('should create citizen profile if not existing', async () => {
      mockPrisma.citizenProfile.findUnique.mockResolvedValueOnce(null);
      mockPrisma.citizenProfile.create.mockResolvedValueOnce({
        id: 1,
        full_name: 'Sundar Pitchai',
        phone: '9876543210',
        branch_id: 1,
      });

      const dto = { fullName: 'Sundar Pitchai', phone: '9876543210', branchId: 1 };
      const res = await service.createProfile('default', 10, dto);
      expect(res.full_name).toBe('Sundar Pitchai');
    });

    it('should throw BadRequestException if profile already exists', async () => {
      mockPrisma.citizenProfile.findUnique.mockResolvedValueOnce({ id: 1 });
      const dto = { fullName: 'Sundar Pitchai', phone: '9876543210', branchId: 1 };

      await expect(service.createProfile('default', 10, dto)).rejects.toThrow(BadRequestException);
    });
  });
});
