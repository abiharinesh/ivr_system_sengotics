import {
    Controller,
    Get,
    Post,
    Put,
    Delete,
    Patch,
    Body,
    Param,
    Query,
    ParseIntPipe,
    UseGuards,
    Req,
    Res,
    ForbiddenException,
    BadRequestException,
} from '@nestjs/common'
import type { Response } from 'express'
import { PanchayatAdminService } from './panchayat-admin.service'
import { ElectricianOpsService } from '../field-ops/field-ops.service'
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
    constructor(
        private readonly service: PanchayatAdminService,
        private readonly electricianOps: ElectricianOpsService
    ) { }

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
    @Get('dashboard/insights')
    getDashboardInsights(@Req() req: AuthenticatedRequest) {
        return this.service.getDashboardInsights(this.getPanchayatId(req))
    }

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

    /** Assign complaint to an electrician (same panchayat). */
    @Patch('complaints/:id/assign-electrician')
    assignElectrician(
        @Req() req: AuthenticatedRequest,
        @Param('id', ParseIntPipe) id: number,
        @Body() body: { electrician_user_id: number }
    ) {
        return this.service.assignElectrician(this.getPanchayatId(req), id, body.electrician_user_id)
    }

    // ── Field electricians & exports ─────────────────────────────────────
    @Get('electricians')
    listElectricians(@Req() req: AuthenticatedRequest) {
        return this.electricianOps.listElectricians(this.getPanchayatId(req))
    }

    @Post('electricians')
    createElectrician(
        @Req() req: AuthenticatedRequest,
        @Body() body: { email: string; password: string; phone_e164?: string }
    ) {
        return this.electricianOps.createElectricianForPanchayat(this.getPanchayatId(req), body)
    }

    @Get('electricians/:id/stats')
    electricianStats(
        @Req() req: AuthenticatedRequest,
        @Param('id', ParseIntPipe) id: number,
        @Query('preset') preset: string,
        @Query('date_from') dateFrom?: string,
        @Query('date_to') dateTo?: string
    ) {
        if (!preset) throw new BadRequestException('preset query required')
        return this.electricianOps.getElectricianStats(id, this.getPanchayatId(req), preset, dateFrom, dateTo)
    }

    @Post('exports/electrician-resolved')
    startElectricianExport(
        @Req() req: AuthenticatedRequest,
        @Body()
        body: { electrician_user_id: number; preset: string; date_from?: string; date_to?: string }
    ) {
        return this.electricianOps.createResolvedExportJob({
            createdByUserId: req.user.id,
            scopedPanchayatId: this.getPanchayatId(req),
            electricianId: body.electrician_user_id,
            preset: body.preset,
            dateFrom: body.date_from,
            dateTo: body.date_to,
        })
    }

    @Get('exports/:jobId')
    getExportJob(@Req() req: AuthenticatedRequest, @Param('jobId', ParseIntPipe) jobId: number) {
        return this.electricianOps.getExportJob(jobId, {
            id: req.user.id,
            role: req.user.role,
            panchayat_id: req.user.panchayat_id,
        })
    }

    @Get('exports/:jobId/download')
    async downloadExport(
        @Req() req: AuthenticatedRequest,
        @Res() res: Response,
        @Param('jobId', ParseIntPipe) jobId: number
    ) {
        const meta = await this.electricianOps.getExportJob(jobId, {
            id: req.user.id,
            role: req.user.role,
            panchayat_id: req.user.panchayat_id,
        })
        if (meta.status !== 'ready' || !meta.download_url) {
            throw new BadRequestException('Export not ready or failed')
        }
        const abs = this.electricianOps.resolveExportAbsolutePath(meta.download_url)
        res.download(abs, `electrician-export-job-${jobId}.zip`)
    }
}
