import { Test, TestingModule } from '@nestjs/testing';
import { CertificateService } from './certificate.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

describe('CertificateService', () => {
  let service: CertificateService;
  let prisma: any;

  const mockPrisma = {
    certificateRequest: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CertificateService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<CertificateService>(CertificateService);
    prisma = module.get<PrismaService>(PrismaService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createRequest', () => {
    it('should create certificate request with default unpaid status', async () => {
      const input = {
        panchayat_id: 1,
        certificate_type: 'birth',
        applicant_name: 'John Doe',
        fee_amount: 50,
      };
      mockPrisma.certificateRequest.create.mockImplementation((args) =>
        Promise.resolve({ id: 101, ...args.data }),
      );

      const result = await service.createRequest(input);
      expect(result.id).toBe(101);
      expect(result.payment_status).toBe('unpaid');
      expect(result.review_status).toBe('pending');
    });
  });

  describe('recordPayment', () => {
    it('should update payment status to paid', async () => {
      mockPrisma.certificateRequest.findUnique.mockResolvedValueOnce({ id: 101 });
      mockPrisma.certificateRequest.update.mockResolvedValueOnce({
        id: 101,
        payment_status: 'paid',
        payment_ref: 'PAY-123',
      });

      const res = await service.recordPayment(101, 'PAY-123');
      expect(res.payment_status).toBe('paid');
      expect(res.payment_ref).toBe('PAY-123');
    });

    it('should throw NotFoundException if request not found', async () => {
      mockPrisma.certificateRequest.findUnique.mockResolvedValueOnce(null);
      await expect(service.recordPayment(999, 'PAY-123')).rejects.toThrow(NotFoundException);
    });
  });

  describe('approveRequest', () => {
    it('should approve request and assign QR token', async () => {
      mockPrisma.certificateRequest.findUnique.mockResolvedValueOnce({ id: 101 });
      mockPrisma.certificateRequest.update.mockImplementation((args) =>
        Promise.resolve({ id: 101, ...args.data }),
      );

      const res = await service.approveRequest(101, { reviewer_notes: 'All documents verified' });
      expect(res.review_status).toBe('approved');
      expect(res.reviewer_notes).toBe('All documents verified');
      expect(res.certificate_qr).toBeDefined();
    });
  });
});
