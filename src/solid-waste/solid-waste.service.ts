import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  AttendanceStatus,
  BinFillLevel as PrismaBinFillLevel,
  BinStatus,
  Prisma,
  TripStatus,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { SlaService } from '../core/sla/sla.service';
import {
  checkWeights,
  classifyFill,
  clampPct,
  clearanceUrgency,
  needsClearance,
  pinColour,
  routeProgress,
} from './bin-fill';
import type {
  AbandonTripDto,
  CloseTripDto,
  CompleteStopDto,
  CreateBinDto,
  CreateRouteDto,
  ListAttendanceDto,
  ListBinsDto,
  ListTripsDto,
  MarkAttendanceDto,
  RecordReadingDto,
  ReplaceStopsDto,
  StartTripDto,
  UpdateBinDto,
  UpdateRouteDto,
} from './dto/solid-waste.dto';

const MODULE = 'solid_waste';
const BIN_ENTITY = 'waste_bin';
const TRIP_ENTITY = 'collection_trip';
const BIN_SEQUENCE = 'waste_bin';
const TRIP_SEQUENCE = 'collection_trip';

@Injectable()
export class SolidWasteService {
  private readonly logger = new Logger(SolidWasteService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly numbers: NumberGenService,
    private readonly sla: SlaService,
    private readonly audit: AuditService,
  ) {}

  // ── Helpers ───────────────────────────────────────────────────────────────

  private num(value: Prisma.Decimal | number | null | undefined): number | null {
    if (value === null || value === undefined) return null;
    return typeof value === 'number' ? value : Number(value.toString());
  }

  private async assertOrgUnit(tenantId: string, orgUnitId: number) {
    const orgUnit = await this.prisma.orgUnit.findFirst({
      where: { id: orgUnitId, tenant_id: tenantId },
      select: { id: true },
    });
    if (!orgUnit) {
      throw new ForbiddenException(
        `Org unit #${orgUnitId} does not belong to your tenant`,
      );
    }
  }

  /** Midnight of the given day, so date-keyed rows compare cleanly. */
  private toDay(value?: string): Date {
    const d = value ? new Date(value) : new Date();
    if (Number.isNaN(d.getTime())) {
      throw new BadRequestException(`"${value}" is not a valid date`);
    }
    return new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  }

  private serializeBin(bin: any) {
    if (!bin) return bin;
    return {
      ...bin,
      pin_colour: pinColour(bin.fill_level),
      needs_clearance: needsClearance(bin.fill_level),
    };
  }

  private serializeTrip(trip: any) {
    if (!trip) return trip;
    const progress = routeProgress(trip.stops_completed, trip.stops_total);
    return {
      ...trip,
      waste_collected_kg: this.num(trip.waste_collected_kg),
      segregated_wet_kg: this.num(trip.segregated_wet_kg),
      segregated_dry_kg: this.num(trip.segregated_dry_kg),
      progress,
      weights: checkWeights(
        this.num(trip.waste_collected_kg),
        this.num(trip.segregated_wet_kg),
        this.num(trip.segregated_dry_kg),
      ),
    };
  }

  // ── Bins ──────────────────────────────────────────────────────────────────

  async listBins(tenantId: string, query: ListBinsDto) {
    const where: Prisma.WasteBinWhereInput = {
      tenant_id: tenantId,
      ...(query.org_unit_id !== undefined && { org_unit_id: query.org_unit_id }),
      ...(query.zone_id !== undefined && { zone_id: query.zone_id }),
      ...(query.ward_number && { ward_number: query.ward_number }),
      ...(query.fill_level && {
        fill_level: query.fill_level as PrismaBinFillLevel,
      }),
      ...(query.status
        ? { status: query.status as BinStatus }
        : // A removed bin is not on the map unless it is asked for by name.
          { status: { not: 'REMOVED' } }),
      ...(query.needs_clearance && {
        fill_level: { in: ['HIGH', 'OVERFLOWING'] as PrismaBinFillLevel[] },
      }),
      ...(query.q && {
        OR: [
          { bin_code: { contains: query.q, mode: 'insensitive' } },
          { landmark: { contains: query.q, mode: 'insensitive' } },
          { ward_number: { contains: query.q, mode: 'insensitive' } },
        ],
      }),
    };

    const [rows, total] = await Promise.all([
      this.prisma.wasteBin.findMany({
        where,
        include: { zone: { select: { id: true, name: true } } },
        orderBy: [{ fill_pct: 'desc' }, { bin_code: 'asc' }],
        take: query.take ?? 200,
        skip: query.skip ?? 0,
      }),
      this.prisma.wasteBin.count({ where }),
    ]);

    return { total, items: rows.map((b) => this.serializeBin(b)) };
  }

  async getBin(tenantId: string, id: number) {
    const bin = await this.prisma.wasteBin.findFirst({
      where: { id, tenant_id: tenantId },
      include: {
        zone: { select: { id: true, name: true } },
        readings: { orderBy: { recorded_at: 'desc' }, take: 30 },
      },
    });
    if (!bin) throw new NotFoundException(`Bin #${id} not found`);

    const [tracker, history] = await Promise.all([
      this.prisma.slaTracker.findFirst({
        where: {
          tenant_id: tenantId,
          entity_type: BIN_ENTITY,
          entity_id: id,
          resolved_at: null,
        },
        orderBy: { started_at: 'desc' },
      }),
      this.audit.getEntityHistory(tenantId, BIN_ENTITY, id.toString(), 20),
    ]);

    return {
      ...this.serializeBin(bin),
      clearance_sla: tracker,
      history: history.map((h) => ({ ...h, id: h.id.toString() })),
    };
  }

  async createBin(
    tenantId: string,
    orgUnitId: number,
    userId: number,
    dto: CreateBinDto,
  ) {
    await this.assertOrgUnit(tenantId, orgUnitId);

    if (dto.zone_id !== undefined) {
      const zone = await this.prisma.zone.findFirst({
        where: { id: dto.zone_id, org_unit_id: orgUnitId },
        select: { id: true },
      });
      if (!zone) {
        throw new BadRequestException(
          `Zone #${dto.zone_id} does not belong to this branch`,
        );
      }
    }

    const binCode = await this.numbers.next(tenantId, BIN_SEQUENCE, orgUnitId);

    const bin = await this.prisma.wasteBin.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        bin_code: binCode,
        bin_type: dto.bin_type,
        capacity_litres: dto.capacity_litres,
        latitude: dto.latitude,
        longitude: dto.longitude,
        zone_id: dto.zone_id ?? null,
        ward_number: dto.ward_number ?? null,
        landmark: dto.landmark ?? null,
        installed_at: dto.installed_at ? new Date(dto.installed_at) : null,
        created_by: userId,
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId,
      userId,
      module: MODULE,
      entityType: BIN_ENTITY,
      entityId: bin.id.toString(),
      action: 'create',
      afterValue: {
        bin_code: binCode,
        bin_type: dto.bin_type,
        capacity_litres: dto.capacity_litres,
      },
    });

    this.logger.log(`Created bin ${binCode} (#${bin.id})`);
    return this.serializeBin(bin);
  }

  async updateBin(
    tenantId: string,
    id: number,
    userId: number,
    dto: UpdateBinDto,
  ) {
    const before = await this.prisma.wasteBin.findFirst({
      where: { id, tenant_id: tenantId },
    });
    if (!before) throw new NotFoundException(`Bin #${id} not found`);

    const after = await this.prisma.wasteBin.update({
      where: { id },
      data: {
        ...(dto.bin_type !== undefined && { bin_type: dto.bin_type }),
        ...(dto.capacity_litres !== undefined && {
          capacity_litres: dto.capacity_litres,
        }),
        ...(dto.latitude !== undefined && { latitude: dto.latitude }),
        ...(dto.longitude !== undefined && { longitude: dto.longitude }),
        ...(dto.zone_id !== undefined && { zone_id: dto.zone_id }),
        ...(dto.ward_number !== undefined && { ward_number: dto.ward_number }),
        ...(dto.landmark !== undefined && { landmark: dto.landmark }),
        ...(dto.status !== undefined && { status: dto.status as BinStatus }),
      },
    });

    // A bin taken out of service should not keep an open clearance SLA
    // running against it.
    if (dto.status && dto.status !== 'ACTIVE') {
      await this.closeBinSla(tenantId, id);
    }

    await this.audit.log({
      tenantId,
      orgUnitId: before.org_unit_id,
      userId,
      module: MODULE,
      entityType: BIN_ENTITY,
      entityId: id.toString(),
      action: 'update',
      beforeValue: { ...before },
      afterValue: { ...after },
      changedFields: AuditService.diffFields({ ...before }, { ...after }),
    });

    return this.serializeBin(after);
  }

  /**
   * Record a fill-level observation.
   *
   * The band is derived from the percentage here rather than trusted from the
   * client, and the denormalised columns on the bin are updated in the same
   * transaction as the append-only reading, so the map can never show a level
   * that no reading supports.
   */
  async recordReading(
    tenantId: string,
    binId: number,
    userId: number,
    dto: RecordReadingDto,
  ) {
    const bin = await this.prisma.wasteBin.findFirst({
      where: { id: binId, tenant_id: tenantId },
    });
    if (!bin) throw new NotFoundException(`Bin #${binId} not found`);
    if (bin.status === 'REMOVED') {
      throw new BadRequestException(
        'This bin has been removed from service — readings cannot be recorded against it',
      );
    }

    const emptied = dto.emptied ?? false;
    const fillPct = emptied ? 0 : clampPct(dto.fill_pct);
    const level = classifyFill(fillPct);
    const now = new Date();

    const [reading] = await this.prisma.$transaction([
      this.prisma.wasteBinReading.create({
        data: {
          bin_id: binId,
          fill_level: level as PrismaBinFillLevel,
          fill_pct: fillPct,
          emptied,
          photo_url: dto.photo_url ?? null,
          remarks: dto.remarks ?? null,
          latitude: dto.latitude ?? null,
          longitude: dto.longitude ?? null,
          recorded_by: userId,
          recorded_at: now,
        },
      }),
      this.prisma.wasteBin.update({
        where: { id: binId },
        data: {
          fill_level: level as PrismaBinFillLevel,
          fill_pct: fillPct,
          last_read_at: now,
          ...(emptied && { last_emptied_at: now }),
        },
      }),
    ]);

    // Clearance SLA: opens when a bin first crosses into HIGH, closes when it
    // is emptied. Re-reading an already-full bin must not start a second
    // clock.
    if (needsClearance(level)) {
      const open = await this.prisma.slaTracker.findFirst({
        where: {
          tenant_id: tenantId,
          entity_type: BIN_ENTITY,
          entity_id: binId,
          resolved_at: null,
        },
      });
      if (!open) {
        await this.sla.startTracker(
          tenantId,
          bin.org_unit_id,
          BIN_ENTITY,
          binId,
          bin.bin_type,
          clearanceUrgency(level),
        );
        this.logger.log(
          `Bin ${bin.bin_code} reached ${level} — clearance SLA started`,
        );
      }
    } else if (emptied || !needsClearance(level)) {
      await this.closeBinSla(tenantId, binId);
    }

    await this.audit.log({
      tenantId,
      orgUnitId: bin.org_unit_id,
      userId,
      module: MODULE,
      entityType: BIN_ENTITY,
      entityId: binId.toString(),
      action: emptied ? 'bin_emptied' : 'bin_reading',
      beforeValue: { fill_level: bin.fill_level, fill_pct: bin.fill_pct },
      afterValue: { fill_level: level, fill_pct: fillPct },
      changedFields: ['fill_level', 'fill_pct'],
    });

    return { ...reading, pin_colour: pinColour(level) };
  }

  private async closeBinSla(tenantId: string, binId: number) {
    await this.prisma.slaTracker.updateMany({
      where: {
        tenant_id: tenantId,
        entity_type: BIN_ENTITY,
        entity_id: binId,
        resolved_at: null,
      },
      data: { resolved_at: new Date(), status: 'resolved' },
    });
  }

  // ── Routes ────────────────────────────────────────────────────────────────

  async listRoutes(tenantId: string, orgUnitId?: number) {
    const routes = await this.prisma.collectionRoute.findMany({
      where: {
        tenant_id: tenantId,
        ...(orgUnitId !== undefined && { org_unit_id: orgUnitId }),
      },
      include: {
        zone: { select: { id: true, name: true } },
        _count: { select: { stops: true } },
      },
      orderBy: [{ is_active: 'desc' }, { name: 'asc' }],
    });

    return routes.map((r) => ({
      ...r,
      distance_km: this.num(r.distance_km),
      stops_total: r._count.stops,
    }));
  }

  async getRoute(tenantId: string, id: number) {
    const route = await this.prisma.collectionRoute.findFirst({
      where: { id, tenant_id: tenantId },
      include: {
        zone: { select: { id: true, name: true } },
        stops: {
          orderBy: { seq: 'asc' },
          include: {
            bin: {
              select: {
                id: true,
                bin_code: true,
                fill_level: true,
                fill_pct: true,
              },
            },
          },
        },
        trips: { orderBy: { trip_date: 'desc' }, take: 14 },
      },
    });
    if (!route) throw new NotFoundException(`Route #${id} not found`);

    return {
      ...route,
      distance_km: this.num(route.distance_km),
      stops: route.stops.map((s) => ({
        ...s,
        bin: s.bin ? { ...s.bin, pin_colour: pinColour(s.bin.fill_level) } : null,
      })),
      trips: route.trips.map((t) => this.serializeTrip(t)),
    };
  }

  async createRoute(
    tenantId: string,
    orgUnitId: number,
    userId: number,
    dto: CreateRouteDto,
  ) {
    await this.assertOrgUnit(tenantId, orgUnitId);

    const routeCode = await this.numbers.next(tenantId, 'collection_route', orgUnitId);

    const route = await this.prisma.collectionRoute.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        route_code: routeCode,
        name: dto.name,
        zone_id: dto.zone_id ?? null,
        ward_number: dto.ward_number ?? null,
        service_days: dto.service_days ?? [1, 2, 3, 4, 5, 6],
        shift: dto.shift ?? 'morning',
        default_vehicle_asset_id: dto.default_vehicle_asset_id ?? null,
        household_count: dto.household_count ?? null,
        distance_km: dto.distance_km ?? null,
        ...(dto.stops?.length
          ? {
              stops: {
                create: dto.stops.map((s, i) => ({
                  seq: i + 1,
                  label: s.label,
                  bin_id: s.bin_id ?? null,
                  latitude: s.latitude ?? null,
                  longitude: s.longitude ?? null,
                  household_count: s.household_count ?? null,
                })),
              },
            }
          : {}),
      },
      include: { stops: { orderBy: { seq: 'asc' } } },
    });

    await this.audit.log({
      tenantId,
      orgUnitId,
      userId,
      module: MODULE,
      entityType: 'collection_route',
      entityId: route.id.toString(),
      action: 'create',
      afterValue: {
        route_code: routeCode,
        name: dto.name,
        stops: route.stops.length,
      },
    });

    return { ...route, distance_km: this.num(route.distance_km) };
  }

  async updateRoute(
    tenantId: string,
    id: number,
    userId: number,
    dto: UpdateRouteDto,
  ) {
    const before = await this.prisma.collectionRoute.findFirst({
      where: { id, tenant_id: tenantId },
    });
    if (!before) throw new NotFoundException(`Route #${id} not found`);

    const after = await this.prisma.collectionRoute.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.zone_id !== undefined && { zone_id: dto.zone_id }),
        ...(dto.ward_number !== undefined && { ward_number: dto.ward_number }),
        ...(dto.service_days !== undefined && { service_days: dto.service_days }),
        ...(dto.shift !== undefined && { shift: dto.shift }),
        ...(dto.default_vehicle_asset_id !== undefined && {
          default_vehicle_asset_id: dto.default_vehicle_asset_id,
        }),
        ...(dto.household_count !== undefined && {
          household_count: dto.household_count,
        }),
        ...(dto.distance_km !== undefined && { distance_km: dto.distance_km }),
        ...(dto.is_active !== undefined && { is_active: dto.is_active }),
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: before.org_unit_id,
      userId,
      module: MODULE,
      entityType: 'collection_route',
      entityId: id.toString(),
      action: 'update',
      beforeValue: { ...before, distance_km: this.num(before.distance_km) },
      afterValue: { ...after, distance_km: this.num(after.distance_km) },
    });

    return { ...after, distance_km: this.num(after.distance_km) };
  }

  /**
   * Replace a route's stops wholesale, renumbering from 1.
   *
   * Refused while a trip against this route is still running: renumbering
   * stops under a crew mid-round would leave their completed stops pointing at
   * different places.
   */
  async replaceStops(
    tenantId: string,
    routeId: number,
    userId: number,
    dto: ReplaceStopsDto,
  ) {
    const route = await this.prisma.collectionRoute.findFirst({
      where: { id: routeId, tenant_id: tenantId },
    });
    if (!route) throw new NotFoundException(`Route #${routeId} not found`);

    const running = await this.prisma.collectionTrip.count({
      where: { route_id: routeId, status: 'IN_PROGRESS' },
    });
    if (running > 0) {
      throw new BadRequestException(
        'A round on this route is in progress — reorder the stops once it has finished',
      );
    }

    await this.prisma.$transaction([
      this.prisma.collectionRouteStop.deleteMany({ where: { route_id: routeId } }),
      this.prisma.collectionRouteStop.createMany({
        data: dto.stops.map((s, i) => ({
          route_id: routeId,
          seq: i + 1,
          label: s.label,
          bin_id: s.bin_id ?? null,
          latitude: s.latitude ?? null,
          longitude: s.longitude ?? null,
          household_count: s.household_count ?? null,
        })),
      }),
    ]);

    await this.audit.log({
      tenantId,
      orgUnitId: route.org_unit_id,
      userId,
      module: MODULE,
      entityType: 'collection_route',
      entityId: routeId.toString(),
      action: 'stops_replaced',
      afterValue: { stops: dto.stops.length },
    });

    return this.getRoute(tenantId, routeId);
  }

  // ── Trips ─────────────────────────────────────────────────────────────────

  async listTrips(tenantId: string, query: ListTripsDto) {
    const where: Prisma.CollectionTripWhereInput = {
      tenant_id: tenantId,
      ...(query.org_unit_id !== undefined && { org_unit_id: query.org_unit_id }),
      ...(query.route_id !== undefined && { route_id: query.route_id }),
      ...(query.status && { status: query.status as TripStatus }),
      ...((query.from || query.to) && {
        trip_date: {
          ...(query.from && { gte: this.toDay(query.from) }),
          ...(query.to && { lte: this.toDay(query.to) }),
        },
      }),
    };

    const [rows, total] = await Promise.all([
      this.prisma.collectionTrip.findMany({
        where,
        include: {
          route: { select: { id: true, name: true, route_code: true } },
        },
        orderBy: [{ trip_date: 'desc' }, { id: 'desc' }],
        take: query.take ?? 50,
        skip: query.skip ?? 0,
      }),
      this.prisma.collectionTrip.count({ where }),
    ]);

    return { total, items: rows.map((t) => this.serializeTrip(t)) };
  }

  async getTrip(tenantId: string, id: number) {
    const trip = await this.prisma.collectionTrip.findFirst({
      where: { id, tenant_id: tenantId },
      include: {
        route: { select: { id: true, name: true, route_code: true } },
        stops: {
          orderBy: { seq: 'asc' },
          include: { route_stop: true },
        },
      },
    });
    if (!trip) throw new NotFoundException(`Trip #${id} not found`);
    return this.serializeTrip(trip);
  }

  /**
   * Open a round. The route's stops are snapshotted onto the trip so that
   * later edits to the route plan cannot rewrite what a crew was asked to do
   * on a past day.
   */
  async startTrip(
    tenantId: string,
    orgUnitId: number,
    userId: number,
    dto: StartTripDto,
  ) {
    await this.assertOrgUnit(tenantId, orgUnitId);

    const route = await this.prisma.collectionRoute.findFirst({
      where: { id: dto.route_id, tenant_id: tenantId },
      include: { stops: { orderBy: { seq: 'asc' } } },
    });
    if (!route) throw new NotFoundException(`Route #${dto.route_id} not found`);
    if (!route.is_active) {
      throw new BadRequestException('This route is not active');
    }
    if (route.stops.length === 0) {
      throw new BadRequestException(
        'This route has no stops — add stops before running it',
      );
    }

    const tripDate = this.toDay(dto.trip_date);
    const shift = dto.shift ?? route.shift;

    const existing = await this.prisma.collectionTrip.findFirst({
      where: { route_id: route.id, trip_date: tripDate, shift },
    });
    if (existing) {
      throw new BadRequestException(
        `A ${shift} round for this route on ${tripDate.toISOString().slice(0, 10)} already exists (${existing.trip_number})`,
      );
    }

    const tripNumber = await this.numbers.next(tenantId, TRIP_SEQUENCE, orgUnitId);

    const trip = await this.prisma.collectionTrip.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        route_id: route.id,
        trip_number: tripNumber,
        trip_date: tripDate,
        shift,
        status: 'IN_PROGRESS',
        vehicle_asset_id: dto.vehicle_asset_id ?? route.default_vehicle_asset_id,
        vehicle_number: dto.vehicle_number ?? null,
        driver_user_id: dto.driver_user_id ?? null,
        crew_size: dto.crew_size ?? null,
        odometer_start_km: dto.odometer_start_km ?? null,
        started_at: new Date(),
        stops_total: route.stops.length,
        stops_completed: 0,
        created_by: userId,
        stops: {
          create: route.stops.map((s) => ({
            route_stop_id: s.id,
            seq: s.seq,
          })),
        },
      },
      include: { stops: { orderBy: { seq: 'asc' } } },
    });

    await this.audit.log({
      tenantId,
      orgUnitId,
      userId,
      module: MODULE,
      entityType: TRIP_ENTITY,
      entityId: trip.id.toString(),
      action: 'trip_started',
      afterValue: {
        trip_number: tripNumber,
        route: route.name,
        shift,
        stops_total: route.stops.length,
      },
    });

    this.logger.log(`Started ${tripNumber} on route ${route.route_code}`);
    return this.serializeTrip(trip);
  }

  /**
   * Mark one stop done (or skipped, with a reason), and fold in a bin reading
   * if the crew reported one — saving them a second action for the commonest
   * case.
   */
  async completeStop(
    tenantId: string,
    tripId: number,
    tripStopId: number,
    userId: number,
    dto: CompleteStopDto,
  ) {
    const trip = await this.prisma.collectionTrip.findFirst({
      where: { id: tripId, tenant_id: tenantId },
      include: { stops: { include: { route_stop: true } } },
    });
    if (!trip) throw new NotFoundException(`Trip #${tripId} not found`);
    if (trip.status !== 'IN_PROGRESS') {
      throw new BadRequestException(
        `This round is ${trip.status} — stops can only be recorded while it is in progress`,
      );
    }

    const stop = trip.stops.find((s) => s.id === tripStopId);
    if (!stop) {
      throw new NotFoundException(`Stop #${tripStopId} is not on this round`);
    }
    if (stop.completed || stop.skipped) {
      throw new BadRequestException('This stop has already been recorded');
    }
    if (dto.skipped && !dto.skip_reason) {
      throw new BadRequestException('A skipped stop must record why');
    }

    await this.prisma.collectionTripStop.update({
      where: { id: tripStopId },
      data: {
        completed: !dto.skipped,
        skipped: dto.skipped ?? false,
        skip_reason: dto.skip_reason ?? null,
        latitude: dto.latitude ?? null,
        longitude: dto.longitude ?? null,
        gps_accuracy_m: dto.gps_accuracy_m ?? null,
        photo_url: dto.photo_url ?? null,
        completed_at: new Date(),
      },
    });

    // Skipped stops count as dealt with for progress: the crew has passed
    // them, and a round showing 18/20 forever because two were inaccessible
    // is a board nobody trusts.
    const settled = await this.prisma.collectionTripStop.count({
      where: { trip_id: tripId, OR: [{ completed: true }, { skipped: true }] },
    });

    const updated = await this.prisma.collectionTrip.update({
      where: { id: tripId },
      data: { stops_completed: settled },
    });

    // Collecting from a stop that has a bin implies the bin was emptied.
    if (!dto.skipped && stop.route_stop.bin_id) {
      await this.recordReading(tenantId, stop.route_stop.bin_id, userId, {
        fill_pct: dto.bin_fill_pct ?? 0,
        emptied: true,
      } as RecordReadingDto);
    }

    return this.serializeTrip(updated);
  }

  async closeTrip(
    tenantId: string,
    tripId: number,
    userId: number,
    dto: CloseTripDto,
  ) {
    const trip = await this.prisma.collectionTrip.findFirst({
      where: { id: tripId, tenant_id: tenantId },
    });
    if (!trip) throw new NotFoundException(`Trip #${tripId} not found`);
    if (trip.status !== 'IN_PROGRESS') {
      throw new BadRequestException(`This round is already ${trip.status}`);
    }

    if (
      dto.odometer_end_km !== undefined &&
      trip.odometer_start_km !== null &&
      dto.odometer_end_km < trip.odometer_start_km
    ) {
      throw new BadRequestException(
        `Closing odometer (${dto.odometer_end_km}) is below the opening reading (${trip.odometer_start_km})`,
      );
    }

    const updated = await this.prisma.collectionTrip.update({
      where: { id: tripId },
      data: {
        status: 'COMPLETED',
        ended_at: new Date(),
        waste_collected_kg: dto.waste_collected_kg ?? null,
        segregated_wet_kg: dto.segregated_wet_kg ?? null,
        segregated_dry_kg: dto.segregated_dry_kg ?? null,
        odometer_end_km: dto.odometer_end_km ?? null,
        remarks: dto.remarks ?? null,
      },
    });

    const progress = routeProgress(updated.stops_completed, updated.stops_total);
    const weights = checkWeights(
      dto.waste_collected_kg,
      dto.segregated_wet_kg,
      dto.segregated_dry_kg,
    );

    await this.audit.log({
      tenantId,
      orgUnitId: trip.org_unit_id,
      userId,
      module: MODULE,
      entityType: TRIP_ENTITY,
      entityId: tripId.toString(),
      action: 'trip_completed',
      afterValue: {
        trip_number: trip.trip_number,
        stops: `${progress.completed}/${progress.total}`,
        percent: progress.percent,
        waste_collected_kg: dto.waste_collected_kg ?? null,
        weights_reconcile: weights?.reconciles ?? null,
      },
    });

    if (weights && !weights.reconciles) {
      this.logger.warn(
        `Trip ${trip.trip_number}: segregation log is ${weights.unaccounted}kg off the weighbridge total`,
      );
    }

    return this.serializeTrip(updated);
  }

  async abandonTrip(
    tenantId: string,
    tripId: number,
    userId: number,
    dto: AbandonTripDto,
  ) {
    const trip = await this.prisma.collectionTrip.findFirst({
      where: { id: tripId, tenant_id: tenantId },
    });
    if (!trip) throw new NotFoundException(`Trip #${tripId} not found`);
    if (trip.status !== 'IN_PROGRESS' && trip.status !== 'PLANNED') {
      throw new BadRequestException(`This round is already ${trip.status}`);
    }

    const updated = await this.prisma.collectionTrip.update({
      where: { id: tripId },
      data: {
        status: 'ABANDONED',
        ended_at: new Date(),
        abandon_reason: dto.reason,
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: trip.org_unit_id,
      userId,
      module: MODULE,
      entityType: TRIP_ENTITY,
      entityId: tripId.toString(),
      action: 'trip_abandoned',
      beforeValue: { status: trip.status },
      afterValue: { status: 'ABANDONED', abandon_reason: dto.reason },
      changedFields: ['status'],
    });

    return this.serializeTrip(updated);
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  /**
   * Mark a worker present/absent for a shift. Idempotent per worker per shift
   * per day — marking twice corrects the first entry rather than duplicating
   * the head count.
   */
  async markAttendance(
    tenantId: string,
    orgUnitId: number,
    userId: number,
    dto: MarkAttendanceDto,
  ) {
    await this.assertOrgUnit(tenantId, orgUnitId);

    const date = this.toDay(dto.attendance_date);
    const shift = dto.shift ?? 'morning';
    const status = dto.status as AttendanceStatus;
    const present = status === 'PRESENT' || status === 'HALF_DAY';

    const record = await this.prisma.sanitationAttendance.upsert({
      where: {
        org_unit_id_worker_name_attendance_date_shift: {
          org_unit_id: orgUnitId,
          worker_name: dto.worker_name,
          attendance_date: date,
          shift,
        },
      },
      create: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        employee_id: dto.employee_id ?? null,
        worker_name: dto.worker_name,
        worker_phone: dto.worker_phone ?? null,
        is_contract: dto.is_contract ?? false,
        attendance_date: date,
        shift,
        status,
        route_id: dto.route_id ?? null,
        check_in_at: present ? new Date() : null,
        check_in_lat: dto.check_in_lat ?? null,
        check_in_lng: dto.check_in_lng ?? null,
        remarks: dto.remarks ?? null,
        recorded_by: userId,
      },
      update: {
        status,
        employee_id: dto.employee_id ?? undefined,
        worker_phone: dto.worker_phone ?? undefined,
        route_id: dto.route_id ?? undefined,
        check_in_at: present ? new Date() : null,
        check_in_lat: dto.check_in_lat ?? undefined,
        check_in_lng: dto.check_in_lng ?? undefined,
        remarks: dto.remarks ?? undefined,
        recorded_by: userId,
      },
    });

    await this.audit.log({
      tenantId,
      orgUnitId,
      userId,
      module: MODULE,
      entityType: 'sanitation_attendance',
      entityId: record.id.toString(),
      action: 'attendance_marked',
      afterValue: {
        worker_name: dto.worker_name,
        date: date.toISOString().slice(0, 10),
        shift,
        status,
      },
    });

    return record;
  }

  async checkOut(tenantId: string, id: number, userId: number) {
    const record = await this.prisma.sanitationAttendance.findFirst({
      where: { id, tenant_id: tenantId },
    });
    if (!record) throw new NotFoundException(`Attendance record #${id} not found`);
    if (!record.check_in_at) {
      throw new BadRequestException('This worker was never checked in');
    }
    if (record.check_out_at) {
      throw new BadRequestException('This worker is already checked out');
    }

    const updated = await this.prisma.sanitationAttendance.update({
      where: { id },
      data: { check_out_at: new Date() },
    });

    await this.audit.log({
      tenantId,
      orgUnitId: record.org_unit_id,
      userId,
      module: MODULE,
      entityType: 'sanitation_attendance',
      entityId: id.toString(),
      action: 'attendance_checkout',
      afterValue: { worker_name: record.worker_name },
    });

    return updated;
  }

  async listAttendance(tenantId: string, query: ListAttendanceDto) {
    const date = this.toDay(query.date);

    const rows = await this.prisma.sanitationAttendance.findMany({
      where: {
        tenant_id: tenantId,
        ...(query.org_unit_id !== undefined && { org_unit_id: query.org_unit_id }),
        ...(query.shift && { shift: query.shift }),
        ...(query.route_id !== undefined && { route_id: query.route_id }),
        attendance_date: date,
      },
      orderBy: [{ status: 'asc' }, { worker_name: 'asc' }],
    });

    const counts = rows.reduce(
      (acc, r) => {
        acc[r.status] = (acc[r.status] ?? 0) + 1;
        return acc;
      },
      {} as Record<string, number>,
    );

    const present = (counts.PRESENT ?? 0) + (counts.HALF_DAY ?? 0);

    return {
      date: date.toISOString().slice(0, 10),
      shift: query.shift ?? 'all',
      total_marked: rows.length,
      present,
      absent: counts.ABSENT ?? 0,
      on_leave: counts.LEAVE ?? 0,
      by_status: counts,
      items: rows,
    };
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  async summary(tenantId: string, orgUnitId?: number) {
    const scope = {
      tenant_id: tenantId,
      ...(orgUnitId !== undefined && { org_unit_id: orgUnitId }),
    };
    const today = this.toDay();

    const [binsByLevel, activeBins, todayTrips, attendanceToday, slaAtRisk] =
      await Promise.all([
        this.prisma.wasteBin.groupBy({
          by: ['fill_level'],
          where: { ...scope, status: 'ACTIVE' },
          _count: { _all: true },
        }),
        this.prisma.wasteBin.count({ where: { ...scope, status: 'ACTIVE' } }),
        this.prisma.collectionTrip.findMany({
          where: { ...scope, trip_date: today },
          select: {
            status: true,
            stops_total: true,
            stops_completed: true,
            waste_collected_kg: true,
          },
        }),
        this.prisma.sanitationAttendance.groupBy({
          by: ['status'],
          where: { ...scope, attendance_date: today },
          _count: { _all: true },
        }),
        this.prisma.slaTracker.count({
          where: {
            tenant_id: tenantId,
            entity_type: BIN_ENTITY,
            status: { in: ['warning', 'escalated', 'breached'] },
            resolved_at: null,
          },
        }),
      ]);

    const levelCounts = Object.fromEntries(
      binsByLevel.map((r) => [r.fill_level, r._count._all]),
    ) as Record<string, number>;

    const stopsTotal = todayTrips.reduce((s, t) => s + t.stops_total, 0);
    const stopsDone = todayTrips.reduce((s, t) => s + t.stops_completed, 0);
    const collectedKg = todayTrips.reduce(
      (s, t) => s + (this.num(t.waste_collected_kg) ?? 0),
      0,
    );

    const attendanceCounts = Object.fromEntries(
      attendanceToday.map((r) => [r.status, r._count._all]),
    ) as Record<string, number>;

    return {
      bins: {
        total_active: activeBins,
        by_level: levelCounts,
        green: (levelCounts.EMPTY ?? 0) + (levelCounts.LOW ?? 0),
        yellow: levelCounts.MEDIUM ?? 0,
        red: (levelCounts.HIGH ?? 0) + (levelCounts.OVERFLOWING ?? 0),
        overflowing: levelCounts.OVERFLOWING ?? 0,
        sla_at_risk: slaAtRisk,
      },
      today: {
        date: today.toISOString().slice(0, 10),
        rounds_total: todayTrips.length,
        rounds_completed: todayTrips.filter((t) => t.status === 'COMPLETED').length,
        rounds_in_progress: todayTrips.filter((t) => t.status === 'IN_PROGRESS')
          .length,
        rounds_abandoned: todayTrips.filter((t) => t.status === 'ABANDONED').length,
        progress: routeProgress(stopsDone, stopsTotal),
        waste_collected_kg: Number(collectedKg.toFixed(2)),
      },
      workers: {
        present:
          (attendanceCounts.PRESENT ?? 0) + (attendanceCounts.HALF_DAY ?? 0),
        absent: attendanceCounts.ABSENT ?? 0,
        on_leave: attendanceCounts.LEAVE ?? 0,
        total_marked: attendanceToday.reduce((s, r) => s + r._count._all, 0),
      },
    };
  }
}
