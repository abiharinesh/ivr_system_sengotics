import { Test, TestingModule } from '@nestjs/testing';
import { ContractorService } from './contractor.service';
import { PrismaService } from '../prisma/prisma.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { AuditService } from '../core/audit/audit.service';
import { BranchHierarchyService } from '../core/tenant/branch-hierarchy.service';

describe('ContractorService', () => {
  let service: ContractorService;

  const mockPrisma = {
    contractor: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    workOrder: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
  };

  const mockNumberGen = { generateWorkOrderNumber: jest.fn().mockResolvedValue('WO-2026-0001') };
  const mockAudit = { log: jest.fn().mockResolvedValue(true) };
  const mockHierarchy = { getVisibleBranchIds: jest.fn().mockResolvedValue([1]) };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ContractorService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: NumberGenService, useValue: mockNumberGen },
        { provide: AuditService, useValue: mockAudit },
        { provide: BranchHierarchyService, useValue: mockHierarchy },
      ],
    }).compile();

    service = module.get<ContractorService>(ContractorService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createContractor', () => {
    it('should create contractor record', async () => {
      const dto = { name: 'ABC Infra', phone: '9876543210', registrationNumber: 'REG-101' };
      mockPrisma.contractor.create.mockResolvedValueOnce({ id: 1, ...dto, is_active: true });

      const res = await service.createContractor('default', dto);
      expect(res.name).toBe('ABC Infra');
      expect(mockPrisma.contractor.create).toHaveBeenCalledTimes(1);
    });
  });
});
