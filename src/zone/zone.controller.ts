import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  Req,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { ZoneService } from './zone.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

// ── Panchayat Admin Zone Endpoints ───────────────────────────────────────────
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin')
@Controller('api/admin/zones')
export class PanchayatAdminZoneController {
  constructor(private readonly zoneService: ZoneService) {}

  @Get()
  listZones(@Req() req: any) {
    const orgUnitId = req.user?.org_unit_id;
    if (!orgUnitId) return [];
    return this.zoneService.listByPanchayat(orgUnitId);
  }

  @Post()
  createZone(@Req() req: any, @Body() body: any) {
    return this.zoneService.create(req.user.org_unit_id, body);
  }

  @Put(':id')
  updateZone(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    return this.zoneService.update(req.user.org_unit_id, id, body);
  }

  @Delete(':id')
  deleteZone(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return this.zoneService.delete(req.user.org_unit_id, id);
  }

  @Post('lookup-boundary')
  lookupBoundary(@Body() body: { place_name: string; country_code?: string }) {
    return this.zoneService.lookupBoundary(body.place_name, body.country_code);
  }
}

// ── Super Admin Zone Endpoints ───────────────────────────────────────────────
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin')
@Controller('api/superadmin/zones')
export class SuperAdminZoneController {
  constructor(private readonly zoneService: ZoneService) {}

  @Get()
  listAllZones() {
    return this.zoneService.listAll();
  }

  @Get(':orgUnitId')
  listZonesByPanchayat(
    @Param('orgUnitId', ParseIntPipe) orgUnitId: number,
  ) {
    return this.zoneService.listByPanchayat(orgUnitId);
  }

  @Post(':orgUnitId')
  createZone(
    @Param('orgUnitId', ParseIntPipe) orgUnitId: number,
    @Body() body: any,
  ) {
    return this.zoneService.create(orgUnitId, body);
  }

  @Put(':orgUnitId/:id')
  updateZone(
    @Param('orgUnitId', ParseIntPipe) orgUnitId: number,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    return this.zoneService.update(orgUnitId, id, body);
  }

  @Delete(':orgUnitId/:id')
  deleteZone(
    @Param('orgUnitId', ParseIntPipe) orgUnitId: number,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.zoneService.delete(orgUnitId, id);
  }

  @Post('lookup-boundary')
  lookupBoundary(@Body() body: { place_name: string; country_code?: string }) {
    return this.zoneService.lookupBoundary(body.place_name, body.country_code);
  }
}
