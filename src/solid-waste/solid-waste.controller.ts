import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { FeatureGuard } from '../municipality/guards/feature.guard';
import { RequiresFeature } from '../municipality/decorators/requires-feature.decorator';
import { SolidWasteService } from './solid-waste.service';
import {
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

interface AuthReq {
  user: {
    id: number;
    email: string;
    role: string;
    org_unit_id: number | null;
    tenant_id: string;
  };
}

/**
 * Solid waste management (Screen Plan 14 §1).
 *
 * Field roles (sanitary worker, driver) can record readings and stops but not
 * reshape the plan; route and bin configuration is narrowed to supervisors on
 * the individual routes.
 */
@UseGuards(JwtAuthGuard, RolesGuard, FeatureGuard)
@RequiresFeature('solid_waste_mgmt')
@Roles(
  'super_admin',
  'panchayat_admin',
  'municipal_commissioner',
  'health_officer',
  'sanitary_inspector',
  'sanitary_supervisor',
  'sanitary_worker',
)
@Controller('api/solid-waste')
export class SolidWasteController {
  constructor(private readonly service: SolidWasteService) {}

  private resolveOrgUnitId(req: AuthReq, requested?: number): number {
    if (req.user.role === 'super_admin') {
      const id = requested ?? req.user.org_unit_id;
      if (id == null) {
        throw new BadRequestException(
          'org_unit_id is required when acting as super admin',
        );
      }
      return id;
    }
    if (req.user.org_unit_id == null) {
      throw new BadRequestException(
        'Your account is not associated with any branch',
      );
    }
    return req.user.org_unit_id;
  }

  private scopeFor(req: AuthReq, requested?: number): number | undefined {
    return req.user.role === 'super_admin'
      ? requested
      : (req.user.org_unit_id ?? undefined);
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  /** GET /api/solid-waste/summary — bin pins, today's rounds, worker head count. */
  @Get('summary')
  summary(@Req() req: AuthReq, @Query('org_unit_id') orgUnitId?: string) {
    return this.service.summary(
      req.user.tenant_id,
      this.scopeFor(req, orgUnitId ? Number(orgUnitId) : undefined),
    );
  }

  // ── Bins ──────────────────────────────────────────────────────────────────

  /** GET /api/solid-waste/bins?needs_clearance=true */
  @Get('bins')
  listBins(@Req() req: AuthReq, @Query() query: ListBinsDto) {
    return this.service.listBins(req.user.tenant_id, {
      ...query,
      org_unit_id: this.scopeFor(req, query.org_unit_id),
    });
  }

  /** GET /api/solid-waste/bins/:id */
  @Get('bins/:id')
  getBin(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.getBin(req.user.tenant_id, id);
  }

  /** POST /api/solid-waste/bins */
  @Post('bins')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
    'sanitary_inspector',
  )
  createBin(@Req() req: AuthReq, @Body() dto: CreateBinDto) {
    return this.service.createBin(
      req.user.tenant_id,
      this.resolveOrgUnitId(req, dto.org_unit_id),
      req.user.id,
      dto,
    );
  }

  /** PUT /api/solid-waste/bins/:id */
  @Put('bins/:id')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
    'sanitary_inspector',
  )
  updateBin(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateBinDto,
  ) {
    return this.service.updateBin(req.user.tenant_id, id, req.user.id, dto);
  }

  /**
   * POST /api/solid-waste/bins/:id/readings — a fill-level observation.
   * Open to field staff: this is the action they perform dozens of times a day.
   */
  @Post('bins/:id/readings')
  recordReading(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RecordReadingDto,
  ) {
    return this.service.recordReading(req.user.tenant_id, id, req.user.id, dto);
  }

  // ── Routes ────────────────────────────────────────────────────────────────

  /** GET /api/solid-waste/routes */
  @Get('routes')
  listRoutes(@Req() req: AuthReq, @Query('org_unit_id') orgUnitId?: string) {
    return this.service.listRoutes(
      req.user.tenant_id,
      this.scopeFor(req, orgUnitId ? Number(orgUnitId) : undefined),
    );
  }

  /** GET /api/solid-waste/routes/:id */
  @Get('routes/:id')
  getRoute(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.getRoute(req.user.tenant_id, id);
  }

  /** POST /api/solid-waste/routes */
  @Post('routes')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
    'sanitary_inspector',
  )
  createRoute(@Req() req: AuthReq, @Body() dto: CreateRouteDto) {
    return this.service.createRoute(
      req.user.tenant_id,
      this.resolveOrgUnitId(req, dto.org_unit_id),
      req.user.id,
      dto,
    );
  }

  /** PUT /api/solid-waste/routes/:id */
  @Put('routes/:id')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
    'sanitary_inspector',
  )
  updateRoute(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateRouteDto,
  ) {
    return this.service.updateRoute(req.user.tenant_id, id, req.user.id, dto);
  }

  /** PUT /api/solid-waste/routes/:id/stops — replace the stop list wholesale. */
  @Put('routes/:id/stops')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
    'sanitary_inspector',
  )
  replaceStops(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ReplaceStopsDto,
  ) {
    return this.service.replaceStops(req.user.tenant_id, id, req.user.id, dto);
  }

  // ── Trips ─────────────────────────────────────────────────────────────────

  /** GET /api/solid-waste/trips?from=2026-08-01 */
  @Get('trips')
  listTrips(@Req() req: AuthReq, @Query() query: ListTripsDto) {
    return this.service.listTrips(req.user.tenant_id, {
      ...query,
      org_unit_id: this.scopeFor(req, query.org_unit_id),
    });
  }

  /** GET /api/solid-waste/trips/:id */
  @Get('trips/:id')
  getTrip(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.getTrip(req.user.tenant_id, id);
  }

  /** POST /api/solid-waste/trips — open a round. */
  @Post('trips')
  startTrip(@Req() req: AuthReq, @Body() dto: StartTripDto) {
    return this.service.startTrip(
      req.user.tenant_id,
      this.resolveOrgUnitId(req),
      req.user.id,
      dto,
    );
  }

  /** PUT /api/solid-waste/trips/:id/stops/:stopId */
  @Put('trips/:id/stops/:stopId')
  completeStop(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Param('stopId', ParseIntPipe) stopId: number,
    @Body() dto: CompleteStopDto,
  ) {
    return this.service.completeStop(
      req.user.tenant_id,
      id,
      stopId,
      req.user.id,
      dto,
    );
  }

  /** POST /api/solid-waste/trips/:id/close */
  @Post('trips/:id/close')
  closeTrip(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CloseTripDto,
  ) {
    return this.service.closeTrip(req.user.tenant_id, id, req.user.id, dto);
  }

  /** POST /api/solid-waste/trips/:id/abandon */
  @Post('trips/:id/abandon')
  abandonTrip(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AbandonTripDto,
  ) {
    return this.service.abandonTrip(req.user.tenant_id, id, req.user.id, dto);
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  /** GET /api/solid-waste/attendance?date=2026-08-02&shift=morning */
  @Get('attendance')
  listAttendance(@Req() req: AuthReq, @Query() query: ListAttendanceDto) {
    return this.service.listAttendance(req.user.tenant_id, {
      ...query,
      org_unit_id: this.scopeFor(req, query.org_unit_id),
    });
  }

  /** POST /api/solid-waste/attendance */
  @Post('attendance')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
    'sanitary_inspector',
    'sanitary_supervisor',
  )
  markAttendance(@Req() req: AuthReq, @Body() dto: MarkAttendanceDto) {
    return this.service.markAttendance(
      req.user.tenant_id,
      this.resolveOrgUnitId(req, dto.org_unit_id),
      req.user.id,
      dto,
    );
  }

  /** POST /api/solid-waste/attendance/:id/check-out */
  @Post('attendance/:id/check-out')
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'health_officer',
    'sanitary_inspector',
    'sanitary_supervisor',
  )
  checkOut(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.service.checkOut(req.user.tenant_id, id, req.user.id);
  }
}
