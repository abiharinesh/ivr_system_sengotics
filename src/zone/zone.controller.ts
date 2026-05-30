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
} from '@nestjs/common'
import { ZoneService } from './zone.service'
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'
import { RolesGuard } from '../auth/guards/roles.guard'
import { Roles } from '../auth/decorators/roles.decorator'

// ── Panchayat Admin Zone Endpoints ───────────────────────────────────────────
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin')
@Controller('api/admin/zones')
export class PanchayatAdminZoneController {
    constructor(private readonly zoneService: ZoneService) {}

    @Get()
    listZones(@Req() req: any) {
        const panchayatId = req.user?.panchayat_id
        if (!panchayatId) return []
        return this.zoneService.listByPanchayat(panchayatId)
    }

    @Post()
    createZone(@Req() req: any, @Body() body: any) {
        return this.zoneService.create(req.user.panchayat_id, body)
    }

    @Put(':id')
    updateZone(@Req() req: any, @Param('id', ParseIntPipe) id: number, @Body() body: any) {
        return this.zoneService.update(req.user.panchayat_id, id, body)
    }

    @Delete(':id')
    deleteZone(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
        return this.zoneService.delete(req.user.panchayat_id, id)
    }

    @Post('lookup-boundary')
    lookupBoundary(@Body() body: { place_name: string; country_code?: string }) {
        return this.zoneService.lookupBoundary(body.place_name, body.country_code)
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
        return this.zoneService.listAll()
    }

    @Get(':panchayatId')
    listZonesByPanchayat(@Param('panchayatId', ParseIntPipe) panchayatId: number) {
        return this.zoneService.listByPanchayat(panchayatId)
    }

    @Post(':panchayatId')
    createZone(
        @Param('panchayatId', ParseIntPipe) panchayatId: number,
        @Body() body: any,
    ) {
        return this.zoneService.create(panchayatId, body)
    }

    @Put(':panchayatId/:id')
    updateZone(
        @Param('panchayatId', ParseIntPipe) panchayatId: number,
        @Param('id', ParseIntPipe) id: number,
        @Body() body: any,
    ) {
        return this.zoneService.update(panchayatId, id, body)
    }

    @Delete(':panchayatId/:id')
    deleteZone(
        @Param('panchayatId', ParseIntPipe) panchayatId: number,
        @Param('id', ParseIntPipe) id: number,
    ) {
        return this.zoneService.delete(panchayatId, id)
    }

    @Post('lookup-boundary')
    lookupBoundary(@Body() body: { place_name: string; country_code?: string }) {
        return this.zoneService.lookupBoundary(body.place_name, body.country_code)
    }
}
