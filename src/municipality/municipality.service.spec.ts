import { Test, TestingModule } from '@nestjs/testing';
import { MunicipalityService } from './municipality.service';
import { PrismaService } from '../prisma/prisma.service';
import { ForbiddenException } from '@nestjs/common';

describe('MunicipalityService', () => {
  let service: MunicipalityService;

  const mockPrisma = {
    branchFeatureConfig: {
      findUnique: jest.fn(),
    },
    formTemplate: {
      findFirst: jest.fn(),
      create: jest.fn(),
    },
    formSubmission: {
      create: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MunicipalityService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<MunicipalityService>(MunicipalityService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('checkFeatureEnabled', () => {
    it('should return true if feature is enabled', async () => {
      mockPrisma.branchFeatureConfig.findUnique.mockResolvedValueOnce({
        org_unit_id: 1,
        solid_waste_mgmt: true,
      });

      const res = await service.checkFeatureEnabled(1, 'solid_waste_mgmt');
      expect(res).toBe(true);
    });

    it('should throw ForbiddenException if feature disabled or missing', async () => {
      mockPrisma.branchFeatureConfig.findUnique.mockResolvedValueOnce(null);

      await expect(
        service.checkFeatureEnabled(1, 'solid_waste_mgmt'),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
