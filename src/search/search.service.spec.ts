import { Test, TestingModule } from '@nestjs/testing';
import { SearchService } from './search.service';
import { PrismaService } from '../prisma/prisma.service';

describe('SearchService', () => {
  let service: SearchService;

  const mockPrisma = {
    complaint: { findMany: jest.fn().mockResolvedValue([]) },
    asset: { findMany: jest.fn().mockResolvedValue([]) },
    tender: { findMany: jest.fn().mockResolvedValue([]) },
    workOrder: { findMany: jest.fn().mockResolvedValue([]) },
    contractor: { findMany: jest.fn().mockResolvedValue([]) },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SearchService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<SearchService>(SearchService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('universalSearch', () => {
    it('should return empty arrays if query is blank', async () => {
      const res = await service.universalSearch('default', '');
      expect(res.complaints).toEqual([]);
      expect(res.contractors).toEqual([]);
      expect(mockPrisma.complaint.findMany).not.toHaveBeenCalled();
    });

    it('should search across entities when query is provided', async () => {
      mockPrisma.complaint.findMany.mockResolvedValueOnce([{ id: 1, description: 'Light broke' }]);
      mockPrisma.contractor.findMany.mockResolvedValueOnce([{ id: 2, name: 'Sengotics Builders' }]);

      const res = await service.universalSearch('default', 'Light');
      expect(res.complaints.length).toBe(1);
      expect(res.contractors.length).toBe(1);
      expect(mockPrisma.complaint.findMany).toHaveBeenCalledTimes(1);
    });
  });
});
