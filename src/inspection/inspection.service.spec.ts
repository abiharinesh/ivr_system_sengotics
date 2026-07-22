import { Test, TestingModule } from '@nestjs/testing';
import { InspectionService } from './inspection.service';
import { PrismaService } from '../prisma/prisma.service';
import { BranchHierarchyService } from '../core/tenant/branch-hierarchy.service';
import { NotFoundException } from '@nestjs/common';

describe('InspectionService', () => {
  let service: InspectionService;

  const mockPrisma = {
    inspectionTemplate: {
      create: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
    },
    fieldInspection: {
      create: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
    },
  };

  const mockHierarchy = { getVisibleBranchIds: jest.fn().mockResolvedValue([1]) };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InspectionService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: BranchHierarchyService, useValue: mockHierarchy },
      ],
    }).compile();

    service = module.get<InspectionService>(InspectionService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createTemplate', () => {
    it('should create inspection template', async () => {
      const dto = { name: 'Pole Quality Checklist', checklistItems: [{ item: 'Visual Damage', type: 'yes_no' }] };
      mockPrisma.inspectionTemplate.create.mockResolvedValueOnce({ id: 10, ...dto, is_active: true });

      const result = await service.createTemplate('default', dto);
      expect(result.name).toBe('Pole Quality Checklist');
    });
  });

  describe('getTemplate', () => {
    it('should throw NotFoundException if template missing', async () => {
      mockPrisma.inspectionTemplate.findFirst.mockResolvedValueOnce(null);
      await expect(service.getTemplate('default', 99)).rejects.toThrow(NotFoundException);
    });
  });
});
