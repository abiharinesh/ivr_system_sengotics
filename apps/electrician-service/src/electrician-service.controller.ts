import {
    Controller, Get, Post, Param, Query, Body, Req, Res,
    ParseIntPipe, UseGuards, UseInterceptors, UploadedFile, BadRequestException,
} from '@nestjs/common'
import type { Response } from 'express'
import { FileInterceptor } from '@nestjs/platform-express'
import type { UploadedImageFile } from '@app/shared'
import { parseGeoFromBody, strFieldOptional, JwtAuthGuard, RolesGuard, Roles } from '@app/shared'
import { ElectricianServiceService } from './electrician-service.service'

interface AuthReq { user: { id: number; email: string; role: string; panchayat_id: number | null } }
const IMAGE_LIMIT = 12 * 1024 * 1024

// ═══════════════════════════════════════════════════════════════════════
//  ELECTRICIAN SELF-SERVICE (JWT-protected, role: electrician)
// ═══════════════════════════════════════════════════════════════════════

@Controller('electrician')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('electrician')
export class ElectricianServiceController {
    constructor(private readonly service: ElectricianServiceService) {}

    @Get('me')
    getMe(@Req() req: AuthReq) { return this.service.getMe(req.user.id) }

    @Get('complaints')
    list(@Req() req: AuthReq, @Query('status') status?: string) { return this.service.listComplaints(req.user.id, status) }

    @Get('complaints/:id')
    getOne(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) { return this.service.getComplaint(req.user.id, id) }

    @Post('complaints/:id/accept')
    accept(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) { return this.service.acceptComplaint(req.user.id, id) }

    @Post('complaints/:id/decline')
    decline(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number, @Body() body: { reason?: string }) {
        return this.service.submitCannotAttend(req.user.id, id, body?.reason)
    }

    @Post('complaints/:id/resolve')
    @UseInterceptors(FileInterceptor('file', { limits: { fileSize: IMAGE_LIMIT } }))
    resolve(
        @Req() req: AuthReq, @Param('id', ParseIntPipe) id: number,
        @UploadedFile() file: UploadedImageFile, @Body() body: Record<string, unknown>,
    ) {
        if (!file?.buffer?.length) throw new BadRequestException('file is required')
        const geo = parseGeoFromBody(body)
        return this.service.submitResolution(req.user.id, id, file, {
            ...geo, note: strFieldOptional(body, 'note'), localJobId: strFieldOptional(body, 'localJobId'),
        })
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  INTERNAL ENDPOINTS (no auth — service-to-service calls only)
// ═══════════════════════════════════════════════════════════════════════

@Controller('electrician/internal')
export class ElectricianInternalController {
    constructor(private readonly service: ElectricianServiceService) {}

    /** Called by whatsapp-service when electrician texts "DONE <id>" */
    @Post('whatsapp-done')
    async whatsappDone(@Body() body: { complaint_id: number; electrician_user_id: number }) {
        return this.service.markWhatsAppDoneAck(body.complaint_id, body.electrician_user_id)
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  FIELD-OPS ADMIN ENDPOINTS (used by admin-service proxy or directly)
// ═══════════════════════════════════════════════════════════════════════

@Controller('electricians')
export class ElectricianOpsController {
    constructor(private readonly service: ElectricianServiceService) {}

    @Get()
    listAll(@Query('panchayat_id') pid?: string) {
        const panchayatId = pid ? parseInt(pid, 10) : undefined
        return this.service.listAllElectricians(isNaN(panchayatId as number) ? undefined : panchayatId)
    }

    @Get('panchayat/:pid')
    listByPanchayat(@Param('pid', ParseIntPipe) pid: number) {
        return this.service.listElectricians(pid)
    }

    @Post('panchayat/:pid')
    create(@Param('pid', ParseIntPipe) pid: number, @Body() body: { email: string; password: string; phone_e164?: string }) {
        return this.service.createElectricianForPanchayat(pid, body)
    }

    @Get(':id/stats')
    stats(
        @Param('id', ParseIntPipe) id: number,
        @Query('panchayat_id') pid?: string,
        @Query('preset') preset?: string,
        @Query('date_from') dateFrom?: string, @Query('date_to') dateTo?: string,
    ) {
        if (!preset) throw new BadRequestException('preset query required')
        const scopedPid = pid ? parseInt(pid, 10) : null
        return this.service.getElectricianStats(id, isNaN(scopedPid as number) ? null : scopedPid, preset, dateFrom, dateTo)
    }

    @Post('exports/resolved')
    export(@Body() body: { created_by_user_id: number; scoped_panchayat_id?: number; electrician_user_id: number; preset: string; date_from?: string; date_to?: string }) {
        return this.service.createResolvedExportJob({
            createdByUserId: body.created_by_user_id,
            scopedPanchayatId: body.scoped_panchayat_id ?? null,
            electricianId: body.electrician_user_id,
            preset: body.preset, dateFrom: body.date_from, dateTo: body.date_to,
        })
    }

    @Get('exports/:jobId')
    getJob(@Param('jobId', ParseIntPipe) jobId: number, @Query('user_id') uid?: string, @Query('role') role?: string, @Query('panchayat_id') pid?: string) {
        return this.service.getExportJob(jobId, {
            id: uid ? parseInt(uid, 10) : 0, role: role ?? 'super_admin',
            panchayat_id: pid ? parseInt(pid, 10) : null,
        })
    }

    @Get('exports/:jobId/download')
    async download(@Res() res: Response, @Param('jobId', ParseIntPipe) jobId: number, @Query('user_id') uid?: string, @Query('role') role?: string, @Query('panchayat_id') pid?: string) {
        const meta = await this.service.getExportJob(jobId, {
            id: uid ? parseInt(uid, 10) : 0, role: role ?? 'super_admin',
            panchayat_id: pid ? parseInt(pid, 10) : null,
        })
        if (meta.status !== 'ready' || !meta.download_url) throw new BadRequestException('Export not ready or failed')
        const abs = this.service.resolveExportAbsolutePath(meta.download_url)
        res.download(abs, `electrician-export-job-${jobId}.zip`)
    }
}
