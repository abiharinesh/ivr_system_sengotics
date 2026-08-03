import { Test, TestingModule } from '@nestjs/testing';
import { FEATURE_DEFAULTS, MunicipalityService } from './municipality.service';
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

    it('should throw ForbiddenException if the feature is switched off', async () => {
      mockPrisma.branchFeatureConfig.findUnique.mockResolvedValueOnce({
        org_unit_id: 1,
        solid_waste_mgmt: false,
      });

      await expect(
        service.checkFeatureEnabled(1, 'solid_waste_mgmt'),
      ).rejects.toThrow(ForbiddenException);
    });

    // A missing row means the branch predates the module, not that it was
    // refused — so the schema default decides. Failing closed here would take
    // a working feature away from every branch provisioned before the module
    // shipped.
    it('falls back to the schema default when the branch has no config row', async () => {
      mockPrisma.branchFeatureConfig.findUnique.mockResolvedValueOnce(null);

      expect(FEATURE_DEFAULTS.solid_waste_mgmt).toBe(true);
      await expect(
        service.checkFeatureEnabled(1, 'solid_waste_mgmt'),
      ).resolves.toBe(true);
    });

    it('still refuses an unbuilt module when there is no config row', async () => {
      mockPrisma.branchFeatureConfig.findUnique.mockResolvedValueOnce(null);

      expect(FEATURE_DEFAULTS.cemetery_mgmt).toBe(false);
      await expect(
        service.checkFeatureEnabled(1, 'cemetery_mgmt'),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
