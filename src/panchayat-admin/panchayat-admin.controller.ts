import { Controller, Get, Post, Put, Delete, Patch, Body, Param, Query, ParseIntPipe, UseGuards, Req } from '@nestjs/common'
import { PanchayatAdminService } from './panchayat-admin.service'
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'
import { RolesGuard } from '../auth/guards/roles.guard'
import { Roles } from '../auth/decorators/roles.decorator'

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin')
@Controller('api/admin')
export class PanchayatAdminController {
    constructor(private readonly service: PanchayatAdminService) { }

    // ── Profile ────────────────────────────────────────────────────────────
    @Get('me')
    getMe(@Req() req: any) {
        return this.service.getMe(req.user.id)
    }

    // ── Stats ──────────────────────────────────────────────────────────────
    @Get('stats')
    getStats(@Req() req: any) {
        return this.service.getStats(req.user.panchayat_id)
    }

    // ── Pole Management ─────────────────────────────────────────────────────
    @Post('poles')
    createPole(@Req() req: any, @Body() body: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number }) {
        return this.service.createPole(req.user.panchayat_id, body)
    }

    @Get('poles')
    listPoles(@Req() req: any) {
        return this.service.listPoles(req.user.panchayat_id)
    }

    @Put('poles/:id')
    updatePole(@Req() req: any, @Param('id', ParseIntPipe) id: number, @Body() body: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number }) {
        return this.service.updatePole(req.user.panchayat_id, id, body)
    }

    @Delete('poles/:id')
    deletePole(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
        return this.service.deletePole(req.user.panchayat_id, id)
    }

    // ── Complaint Management ────────────────────────────────────────────────
    @Get('complaints')
    listComplaints(@Req() req: any, @Query('status') status?: string) {
        return this.service.listComplaints(req.user.panchayat_id, status)
    }

    @Patch('complaints/:id/status')
    updateComplaintStatus(@Req() req: any, @Param('id', ParseIntPipe) id: number, @Body() body: { status: string }) {
        return this.service.updateComplaintStatus(req.user.panchayat_id, id, body.status)
    }
}
