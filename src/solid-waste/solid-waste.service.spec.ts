import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { SolidWasteService } from './solid-waste.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { SlaService } from '../core/sla/sla.service';

const TENANT = 'tenant-a';
const USER = 21;
const ORG = 5;

const binRow = (overrides: Record<string, any> = {}) => ({
  id: 1,
  tenant_id: TENANT,
  org_unit_id: ORG,
  bin_code: 'BIN-000001',
  bin_type: 'community',
  capacity_litres: 1100,
  fill_level: 'LOW',
  fill_pct: 20,
  status: 'ACTIVE',
  latitude: 11.01,
  longitude: 76.95,
  zone_id: null,
  ...overrides,
});

const routeRow = (overrides: Record<string, any> = {}) => ({
  id: 3,
  tenant_id: TENANT,
  org_unit_id: ORG,
  route_code: 'RTE-0003',
  name: 'Anna Nagar morning',
  shift: 'morning',
  is_active: true,
  default_vehicle_asset_id: null,
  distance_km: null,
  stops: [
    { id: 11, seq: 1, label: 'Stop 1', bin_id: 1 },
    { id: 12, seq: 2, label: 'Stop 2', bin_id: null },
  ],
  ...overrides,
});

const tripRow = (overrides: Record<string, any> = {}) => ({
  id: 7,
  tenant_id: TENANT,
  org_unit_id: ORG,
  route_id: 3,
  trip_number: 'TRIP-2026-27-000001',
  trip_date: new Date('2026-08-02'),
  shift: 'morning',
  status: 'IN_PROGRESS',
  stops_total: 2,
  stops_completed: 0,
  odometer_start_km: 1000,
  waste_collected_kg: null,
  segregated_wet_kg: null,
  segregated_dry_kg: null,
  stops: [
    {
      id: 21,
      seq: 1,
      completed: false,
      skipped: false,
      route_stop: { id: 11, bin_id: 1 },
    },
    {
      id: 22,
      seq: 2,
      completed: false,
      skipped: false,
      route_stop: { id: 12, bin_id: null },
    },
  ],
  ...overrides,
});

describe('SolidWasteService', () => {
  let service: SolidWasteService;

  const prisma = {
    wasteBin: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
      groupBy: jest.fn(),
    },
    wasteBinReading: { create: jest.fn() },
    collectionRoute: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    collectionRouteStop: { deleteMany: jest.fn(), createMany: jest.fn() },
    collectionTrip: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    collectionTripStop: { update: jest.fn(), count: jest.fn() },
    sanitationAttendance: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      upsert: jest.fn(),
      update: jest.fn(),
      groupBy: jest.fn(),
    },
    orgUnit: { findFirst: jest.fn() },
    zone: { findFirst: jest.fn() },
    slaTracker: { findFirst: jest.fn(), updateMany: jest.fn(), count: jest.fn() },
    $transaction: jest.fn(),
  };

  const numbers = { next: jest.fn() };
  const sla = { startTracker: jest.fn() };
  const audit = { log: jest.fn(), getEntityHistory: jest.fn() };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SolidWasteService,
        { provide: PrismaService, useValue: prisma },
        { provide: NumberGenService, useValue: numbers },
        { provide: SlaService, useValue: sla },
        { provide: AuditService, useValue: audit },
      ],
    }).compile();

    service = module.get(SolidWasteService);
    jest.clearAllMocks();

    prisma.orgUnit.findFirst.mockResolvedValue({ id: ORG });
    prisma.slaTracker.findFirst.mockResolvedValue(null);
    prisma.slaTracker.updateMany.mockResolvedValue({ count: 0 });
    prisma.wasteBin.update.mockImplementation(({ data }) =>
      Promise.resolve(binRow(data)),
    );
    prisma.wasteBinReading.create.mockImplementation(({ data }) =>
      Promise.resolve({ id: 99, ...data }),
    );
    // The service batches the reading and the denormalised bin update; the
    // real client returns both results in order.
    prisma.$transaction.mockImplementation((ops: any[]) => Promise.all(ops));
    audit.log.mockResolvedValue(undefined);
    audit.getEntityHistory.mockResolvedValue([]);
    numbers.next.mockResolvedValue('BIN-000001');
    sla.startTracker.mockResolvedValue({ id: 1 });
  });

  describe('createBin', () => {
    it('allots a bin code and records the creation', async () => {
      prisma.wasteBin.create.mockResolvedValue(binRow());

      const bin = await service.createBin(TENANT, ORG, USER, {
        bin_type: 'community',
        capacity_litres: 1100,
        latitude: 11.01,
        longitude: 76.95,
      } as any);

      expect(numbers.next).toHaveBeenCalledWith(TENANT, 'waste_bin', ORG);
      expect(prisma.wasteBin.create.mock.calls[0][0].data.bin_code).toBe(
        'BIN-000001',
      );
      // The map needs the pin colour without recomputing the band client-side.
      expect(bin.pin_colour).toBe('green');
      expect(bin.needs_clearance).toBe(false);
    });

    it('refuses a zone from another branch', async () => {
      prisma.zone.findFirst.mockResolvedValue(null);

      await expect(
        service.createBin(TENANT, ORG, USER, {
          bin_type: 'community',
          capacity_litres: 1100,
          latitude: 11.01,
          longitude: 76.95,
          zone_id: 99,
        } as any),
      ).rejects.toThrow(/does not belong to this branch/);
    });

    it('refuses an org unit from another tenant', async () => {
      prisma.orgUnit.findFirst.mockResolvedValue(null);

      await expect(
        service.createBin(TENANT, 999, USER, {
          bin_type: 'community',
          capacity_litres: 1100,
          latitude: 11.01,
          longitude: 76.95,
        } as any),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('recordReading', () => {
    it('derives the band from the percentage rather than trusting the client', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(binRow());

      const reading = await service.recordReading(TENANT, 1, USER, {
        fill_pct: 82,
      } as any);

      const readingData = prisma.wasteBinReading.create.mock.calls[0][0].data;
      expect(readingData.fill_level).toBe('HIGH');
      expect(reading.pin_colour).toBe('red');
    });

    it('opens a clearance SLA the first time a bin goes red', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(binRow());

      await service.recordReading(TENANT, 1, USER, { fill_pct: 100 } as any);

      expect(sla.startTracker).toHaveBeenCalledWith(
        TENANT,
        ORG,
        'waste_bin',
        1,
        'community',
        'critical',
      );
    });

    it('does not start a second clock for an already-full bin', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(
        binRow({ fill_level: 'HIGH', fill_pct: 80 }),
      );
      prisma.slaTracker.findFirst.mockResolvedValue({ id: 42 });

      await service.recordReading(TENANT, 1, USER, { fill_pct: 90 } as any);

      expect(sla.startTracker).not.toHaveBeenCalled();
    });

    it('forces the level to empty and closes the SLA when the bin is emptied', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(
        binRow({ fill_level: 'OVERFLOWING', fill_pct: 100 }),
      );

      await service.recordReading(TENANT, 1, USER, {
        fill_pct: 95,
        emptied: true,
      } as any);

      const readingData = prisma.wasteBinReading.create.mock.calls[0][0].data;
      // An emptied bin is empty, whatever the crew typed in the box.
      expect(readingData.fill_pct).toBe(0);
      expect(readingData.fill_level).toBe('EMPTY');
      expect(prisma.slaTracker.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'resolved' }),
        }),
      );
    });

    it('stamps last_emptied_at only on an emptying reading', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(binRow());

      await service.recordReading(TENANT, 1, USER, { fill_pct: 50 } as any);
      const observed = prisma.wasteBin.update.mock.calls[0][0].data;
      expect(observed.last_emptied_at).toBeUndefined();

      jest.clearAllMocks();
      prisma.wasteBin.findFirst.mockResolvedValue(binRow());
      prisma.$transaction.mockImplementation((ops: any[]) => Promise.all(ops));
      prisma.wasteBinReading.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 99, ...data }),
      );
      prisma.wasteBin.update.mockImplementation(({ data }) =>
        Promise.resolve(binRow(data)),
      );

      await service.recordReading(TENANT, 1, USER, {
        fill_pct: 0,
        emptied: true,
      } as any);
      const emptied = prisma.wasteBin.update.mock.calls[0][0].data;
      expect(emptied.last_emptied_at).toBeInstanceOf(Date);
    });

    it('refuses readings against a removed bin', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(binRow({ status: 'REMOVED' }));

      await expect(
        service.recordReading(TENANT, 1, USER, { fill_pct: 50 } as any),
      ).rejects.toThrow(/removed from service/);
    });

    it('does not leak a bin from another tenant', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(null);

      await expect(
        service.recordReading(TENANT, 1, USER, { fill_pct: 50 } as any),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('updateBin', () => {
    it('closes an open clearance SLA when a bin leaves service', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(
        binRow({ fill_level: 'OVERFLOWING' }),
      );

      await service.updateBin(TENANT, 1, USER, { status: 'DAMAGED' } as any);

      expect(prisma.slaTracker.updateMany).toHaveBeenCalled();
    });

    it('leaves the SLA alone on an ordinary edit', async () => {
      prisma.wasteBin.findFirst.mockResolvedValue(binRow());

      await service.updateBin(TENANT, 1, USER, { landmark: 'Near the temple' } as any);

      expect(prisma.slaTracker.updateMany).not.toHaveBeenCalled();
    });
  });

  describe('startTrip', () => {
    it('snapshots the route stops onto the trip', async () => {
      prisma.collectionRoute.findFirst.mockResolvedValue(routeRow());
      prisma.collectionTrip.findFirst.mockResolvedValue(null);
      numbers.next.mockResolvedValue('TRIP-2026-27-000001');
      prisma.collectionTrip.create.mockImplementation(({ data }) =>
        Promise.resolve(tripRow({ ...data, stops: [] })),
      );

      await service.startTrip(TENANT, ORG, USER, { route_id: 3 } as any);

      const data = prisma.collectionTrip.create.mock.calls[0][0].data;
      expect(data.stops_total).toBe(2);
      expect(data.stops.create).toEqual([
        { route_stop_id: 11, seq: 1 },
        { route_stop_id: 12, seq: 2 },
      ]);
      expect(data.status).toBe('IN_PROGRESS');
    });

    it('refuses a duplicate round for the same route, date and shift', async () => {
      prisma.collectionRoute.findFirst.mockResolvedValue(routeRow());
      prisma.collectionTrip.findFirst.mockResolvedValue(
        tripRow({ trip_number: 'TRIP-EXISTING' }),
      );

      await expect(
        service.startTrip(TENANT, ORG, USER, { route_id: 3 } as any),
      ).rejects.toThrow(/already exists/);
    });

    it('allows a second round on a different shift', async () => {
      prisma.collectionRoute.findFirst.mockResolvedValue(routeRow());
      prisma.collectionTrip.findFirst.mockResolvedValue(null);
      prisma.collectionTrip.create.mockImplementation(({ data }) =>
        Promise.resolve(tripRow({ ...data, stops: [] })),
      );

      await service.startTrip(TENANT, ORG, USER, {
        route_id: 3,
        shift: 'afternoon',
      } as any);

      expect(prisma.collectionTrip.create.mock.calls[0][0].data.shift).toBe(
        'afternoon',
      );
    });

    it('refuses a route with no stops', async () => {
      prisma.collectionRoute.findFirst.mockResolvedValue(routeRow({ stops: [] }));

      await expect(
        service.startTrip(TENANT, ORG, USER, { route_id: 3 } as any),
      ).rejects.toThrow(/no stops/);
    });

    it('refuses an inactive route', async () => {
      prisma.collectionRoute.findFirst.mockResolvedValue(
        routeRow({ is_active: false }),
      );

      await expect(
        service.startTrip(TENANT, ORG, USER, { route_id: 3 } as any),
      ).rejects.toThrow(/not active/);
    });
  });

  describe('completeStop', () => {
    it('counts the stop and empties the bin behind it', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(tripRow());
      prisma.collectionTripStop.update.mockResolvedValue({ id: 21 });
      prisma.collectionTripStop.count.mockResolvedValue(1);
      prisma.collectionTrip.update.mockImplementation(({ data }) =>
        Promise.resolve(tripRow({ ...data })),
      );
      prisma.wasteBin.findFirst.mockResolvedValue(binRow({ fill_level: 'HIGH' }));

      const trip = await service.completeStop(TENANT, 7, 21, USER, {} as any);

      expect(prisma.collectionTripStop.update.mock.calls[0][0].data.completed).toBe(
        true,
      );
      expect(trip.stops_completed).toBe(1);
      // Collecting from a stop that has a bin implies the bin was emptied.
      expect(prisma.wasteBinReading.create.mock.calls[0][0].data.emptied).toBe(true);
    });

    it('counts a skipped stop as settled but does not empty a bin', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(tripRow());
      prisma.collectionTripStop.update.mockResolvedValue({ id: 21 });
      prisma.collectionTripStop.count.mockResolvedValue(1);
      prisma.collectionTrip.update.mockImplementation(({ data }) =>
        Promise.resolve(tripRow({ ...data })),
      );

      await service.completeStop(TENANT, 7, 21, USER, {
        skipped: true,
        skip_reason: 'Street blocked by a wedding pandal',
      } as any);

      const data = prisma.collectionTripStop.update.mock.calls[0][0].data;
      expect(data.skipped).toBe(true);
      expect(data.completed).toBe(false);
      expect(prisma.wasteBinReading.create).not.toHaveBeenCalled();
    });

    it('requires a reason for a skip', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(tripRow());

      await expect(
        service.completeStop(TENANT, 7, 21, USER, { skipped: true } as any),
      ).rejects.toThrow(/must record why/);
    });

    it('will not record the same stop twice', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(
        tripRow({
          stops: [
            {
              id: 21,
              seq: 1,
              completed: true,
              skipped: false,
              route_stop: { id: 11, bin_id: 1 },
            },
          ],
        }),
      );

      await expect(
        service.completeStop(TENANT, 7, 21, USER, {} as any),
      ).rejects.toThrow(/already been recorded/);
    });

    it('refuses stops on a round that is not running', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(
        tripRow({ status: 'COMPLETED' }),
      );

      await expect(
        service.completeStop(TENANT, 7, 21, USER, {} as any),
      ).rejects.toThrow(/only be recorded while it is in progress/);
    });
  });

  describe('closeTrip', () => {
    it('completes the round and reports progress', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(tripRow());
      prisma.collectionTrip.update.mockImplementation(({ data }) =>
        Promise.resolve(tripRow({ ...data, stops_completed: 2, stops_total: 2 })),
      );

      const trip = await service.closeTrip(TENANT, 7, USER, {
        waste_collected_kg: 900,
        segregated_wet_kg: 500,
        segregated_dry_kg: 400,
      } as any);

      expect(trip.status).toBe('COMPLETED');
      expect(trip.progress.band).toBe('complete');
      expect(trip.weights.reconciles).toBe(true);
    });

    it('surfaces a segregation log that does not match the weighbridge', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(tripRow());
      prisma.collectionTrip.update.mockImplementation(({ data }) =>
        Promise.resolve(tripRow({ ...data, stops_completed: 2 })),
      );

      const trip = await service.closeTrip(TENANT, 7, USER, {
        waste_collected_kg: 1000,
        segregated_wet_kg: 300,
        segregated_dry_kg: 200,
      } as any);

      expect(trip.weights.reconciles).toBe(false);
      expect(trip.weights.unaccounted).toBe(500);
    });

    it('rejects a closing odometer below the opening one', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(tripRow());

      await expect(
        service.closeTrip(TENANT, 7, USER, { odometer_end_km: 900 } as any),
      ).rejects.toThrow(/below the opening reading/);
    });

    it('will not close a round twice', async () => {
      prisma.collectionTrip.findFirst.mockResolvedValue(
        tripRow({ status: 'COMPLETED' }),
      );

      await expect(
        service.closeTrip(TENANT, 7, USER, {} as any),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('replaceStops', () => {
    it('refuses to renumber stops under a crew mid-round', async () => {
      prisma.collectionRoute.findFirst.mockResolvedValue(routeRow());
      prisma.collectionTrip.count.mockResolvedValue(1);

      await expect(
        service.replaceStops(TENANT, 3, USER, {
          stops: [{ label: 'New stop' }],
        } as any),
      ).rejects.toThrow(/in progress/);
    });

    it('renumbers from 1 in the order supplied', async () => {
      prisma.collectionRoute.findFirst.mockResolvedValue(routeRow());
      prisma.collectionTrip.count.mockResolvedValue(0);
      prisma.$transaction.mockResolvedValue([]);
      prisma.collectionRoute.findFirst.mockResolvedValueOnce(routeRow());

      await service
        .replaceStops(TENANT, 3, USER, {
          stops: [{ label: 'A' }, { label: 'B' }, { label: 'C' }],
        } as any)
        .catch(() => {
          // getRoute at the end re-queries; the assertion below is on the write.
        });

      const createMany = prisma.collectionRouteStop.createMany.mock.calls[0][0];
      expect(createMany.data.map((s: any) => s.seq)).toEqual([1, 2, 3]);
      expect(createMany.data.map((s: any) => s.label)).toEqual(['A', 'B', 'C']);
    });
  });

  describe('markAttendance', () => {
    it('upserts so marking twice corrects rather than double-counts', async () => {
      prisma.sanitationAttendance.upsert.mockResolvedValue({ id: 1 });

      await service.markAttendance(TENANT, ORG, USER, {
        worker_name: 'K. Murugan',
        status: 'PRESENT',
      } as any);

      const call = prisma.sanitationAttendance.upsert.mock.calls[0][0];
      expect(call.where.org_unit_id_worker_name_attendance_date_shift).toBeDefined();
      expect(call.create.check_in_at).toBeInstanceOf(Date);
    });

    it('does not stamp a check-in for an absent worker', async () => {
      prisma.sanitationAttendance.upsert.mockResolvedValue({ id: 1 });

      await service.markAttendance(TENANT, ORG, USER, {
        worker_name: 'K. Murugan',
        status: 'ABSENT',
      } as any);

      expect(prisma.sanitationAttendance.upsert.mock.calls[0][0].create.check_in_at)
        .toBeNull();
    });

    it('counts a half day as present', async () => {
      prisma.sanitationAttendance.upsert.mockResolvedValue({ id: 1 });

      await service.markAttendance(TENANT, ORG, USER, {
        worker_name: 'K. Murugan',
        status: 'HALF_DAY',
      } as any);

      expect(prisma.sanitationAttendance.upsert.mock.calls[0][0].create.check_in_at)
        .toBeInstanceOf(Date);
    });
  });

  describe('listAttendance', () => {
    it('totals the head count a supervisor actually asks for', async () => {
      prisma.sanitationAttendance.findMany.mockResolvedValue([
        { status: 'PRESENT', worker_name: 'A' },
        { status: 'PRESENT', worker_name: 'B' },
        { status: 'HALF_DAY', worker_name: 'C' },
        { status: 'ABSENT', worker_name: 'D' },
        { status: 'LEAVE', worker_name: 'E' },
      ]);

      const result = await service.listAttendance(TENANT, {
        shift: 'morning',
      } as any);

      expect(result.present).toBe(3); // two full + one half day
      expect(result.absent).toBe(1);
      expect(result.on_leave).toBe(1);
      expect(result.total_marked).toBe(5);
    });
  });

  describe('checkOut', () => {
    it('refuses to check out a worker who never checked in', async () => {
      prisma.sanitationAttendance.findFirst.mockResolvedValue({
        id: 1,
        org_unit_id: ORG,
        check_in_at: null,
        check_out_at: null,
      });

      await expect(service.checkOut(TENANT, 1, USER)).rejects.toThrow(
        /never checked in/,
      );
    });

    it('refuses a double check-out', async () => {
      prisma.sanitationAttendance.findFirst.mockResolvedValue({
        id: 1,
        org_unit_id: ORG,
        check_in_at: new Date(),
        check_out_at: new Date(),
      });

      await expect(service.checkOut(TENANT, 1, USER)).rejects.toThrow(
        /already checked out/,
      );
    });
  });
});
