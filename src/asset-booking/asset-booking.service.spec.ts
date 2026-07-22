import { Test, TestingModule } from '@nestjs/testing';
import { AssetBookingService } from './asset-booking.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException, BadRequestException } from '@nestjs/common';

describe('AssetBookingService', () => {
  let service: AssetBookingService;
  let prisma: any;

  const mockPrisma = {
    panchayatAsset: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    assetBooking: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AssetBookingService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<AssetBookingService>(AssetBookingService);
    prisma = module.get<PrismaService>(PrismaService);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('checkAvailability', () => {
    it('should throw BadRequestException if start >= end', async () => {
      await expect(
        service.checkAvailability(1, '2026-06-10', '2026-06-05'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should return true if no conflicting bookings found', async () => {
      mockPrisma.assetBooking.findMany.mockResolvedValueOnce([]);
      const available = await service.checkAvailability(1, '2026-06-01', '2026-06-03');
      expect(available).toBe(true);
    });
  });

  describe('confirmBooking', () => {
    it('should update booking status to confirmed', async () => {
      mockPrisma.assetBooking.findUnique.mockResolvedValueOnce({ id: 5 });
      mockPrisma.assetBooking.update.mockResolvedValueOnce({
        id: 5,
        booking_status: 'confirmed',
        payment_ref: 'BOOK-PAY-88',
      });

      const res = await service.confirmBooking(5, 'BOOK-PAY-88');
      expect(res.booking_status).toBe('confirmed');
      expect(res.payment_ref).toBe('BOOK-PAY-88');
    });

    it('should throw NotFoundException if booking is missing', async () => {
      mockPrisma.assetBooking.findUnique.mockResolvedValueOnce(null);
      await expect(service.confirmBooking(99, 'REF')).rejects.toThrow(NotFoundException);
    });
  });
});
