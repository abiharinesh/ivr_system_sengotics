import { Controller, Get, Post, Put, Delete, Patch, Body, Param, Query, ParseIntPipe, UseGuards, Req, ForbiddenException } from '@nestjs/common'
import { PanchayatAdminService } from './panchayat-admin.service'
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'
import { RolesGuard } from '../auth/guards/roles.guard'
import { Roles } from '../auth/decorators/roles.decorator'

interface AuthenticatedRequest {
    user: {
        id: number
        email: string
        role: string
        panchayat_id: number | null
    }
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin')
@Controller('api/admin')
export class PanchayatAdminController {
    constructor(private readonly service: PanchayatAdminService) { }

    /** Extract and validate panchayat_id from the JWT user. */
    private getPanchayatId(req: AuthenticatedRequest): number {
        if (!req.user.panchayat_id) {
            throw new ForbiddenException('Your account is not associated with any panchayat')
        }
        return req.user.panchayat_id
    }

    // ── Profile ────────────────────────────────────────────────────────────
    @Get('me')
    getMe(@Req() req: AuthenticatedRequest) {
        return this.service.getMe(req.user.id)
    }

    // ── Stats ──────────────────────────────────────────────────────────────
    @Get('stats')
    getStats(@Req() req: AuthenticatedRequest) {
        return this.service.getStats(this.getPanchayatId(req))
    }

    // ── Pole Management ─────────────────────────────────────────────────────
    @Post('poles')
    createPole(@Req() req: AuthenticatedRequest, @Body() body: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) {
        return this.service.createPole(this.getPanchayatId(req), body)
    }

    @Get('poles')
    listPoles(@Req() req: AuthenticatedRequest) {
        return this.service.listPoles(this.getPanchayatId(req))
    }

    @Put('poles/:id')
    updatePole(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number, @Body() body: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) {
        return this.service.updatePole(this.getPanchayatId(req), id, body)
    }

    @Delete('poles/:id')
    deletePole(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number) {
        return this.service.deletePole(this.getPanchayatId(req), id)
    }

    // ── Complaint Management ────────────────────────────────────────────────
    @Get('complaints')
    listComplaints(@Req() req: AuthenticatedRequest, @Query('status') status?: string) {
        return this.service.listComplaints(this.getPanchayatId(req), status)
    }

    @Patch('complaints/:id/status')
    updateComplaintStatus(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number, @Body() body: { status: string }) {
        return this.service.updateComplaintStatus(this.getPanchayatId(req), id, body.status)
    }

    /** Assign a pole to a manual_review complaint + auto-learn the caller's landmark. */
    @Patch('complaints/:id/resolve')
    resolveComplaint(@Req() req: AuthenticatedRequest, @Param('id', ParseIntPipe) id: number, @Body() body: { pole_id: number }) {
        return this.service.resolveComplaint(this.getPanchayatId(req), id, body.pole_id)
    }
}
