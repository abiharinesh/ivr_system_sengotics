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
    Req,
    Res,
    ParseIntPipe,
    UseGuards,
    BadRequestException,
} from '@nestjs/common'
import type { Response } from 'express'
import { SuperAdminService } from './super-admin.service'
import { ElectricianOpsService } from '../field-ops/field-ops.service'
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'
import { RolesGuard } from '../auth/guards/roles.guard'
import { Roles } from '../auth/decorators/roles.decorator'
import { DocumentTemplateSettingsService } from '../tender/pdf/document-template-settings.service'
import { validateTemplateId } from '../tender/tender-status'

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin')
@Controller('api/superadmin')
export class SuperAdminController {
    constructor(
        private readonly superAdminService: SuperAdminService,
        private readonly electricianOps: ElectricianOpsService,
        private readonly documentTemplateSettings: DocumentTemplateSettingsService,
    ) { }

    // ── Panchayat Management ────────────────────────────────────────────────
    @Post('panchayats')
    createPanchayat(@Body() body: { name: string; ivr_number?: string; center_lat?: number; center_lng?: number }) {
        return this.superAdminService.createPanchayat(body)
    }

    @Get('panchayats')
    listPanchayats() {
        return this.superAdminService.listPanchayats()
    }

    @Get('panchayats/:id')
    getPanchayat(@Param('id', ParseIntPipe) id: number) {
        return this.superAdminService.getPanchayat(id)
    }

    @Put('panchayats/:id')
    updatePanchayat(@Param('id', ParseIntPipe) id: number, @Body() body: { name?: string; ivr_number?: string; center_lat?: number; center_lng?: number }) {
        return this.superAdminService.updatePanchayat(id, body)
    }

    @Delete('panchayats/:id')
    deletePanchayat(@Param('id', ParseIntPipe) id: number) {
        return this.superAdminService.deletePanchayat(id)
    }

    // ── Pole Management (all panchayats) ─────────────────────────────────────
    @Post('poles')
    createPole(@Body() body: {
        panchayat_id: number
        pole_number?: string
        keypad_id?: string
        latitude?: number
        longitude?: number
        landmarks?: string[]
    }) {
        return this.superAdminService.createPole(body)
    }

    @Get('poles')
    listPoles(@Query('panchayat_id') pid?: string) {
        const panchayatId = pid ? parseInt(pid, 10) : undefined
        return this.superAdminService.listPoles(isNaN(panchayatId as number) ? undefined : panchayatId)
    }

    @Put('poles/:id')
    updatePole(
        @Param('id', ParseIntPipe) id: number,
        @Body() body: {
            panchayat_id?: number
            pole_number?: string
            keypad_id?: string
            latitude?: number
            longitude?: number
            landmarks?: string[]
        }
    ) {
        return this.superAdminService.updatePole(id, body)
    }

    @Delete('poles/:id')
    deletePole(@Param('id', ParseIntPipe) id: number) {
        return this.superAdminService.deletePole(id)
    }

    // ── Admin User Management ──────────────────────────────────────────────
    @Post('users')
    createPanchayatAdmin(@Body() body: { email: string; password: string; panchayat_id: number }) {
        return this.superAdminService.createPanchayatAdmin(body)
    }

    @Post('users/staff')
    createStaffUser(
        @Body()
        body: {
            email: string
            password: string
            role: string
            panchayat_id: number
            phone_e164?: string
        }
    ) {
        return this.superAdminService.createStaffUser(body)
    }

    @Get('users')
    listUsers() {
        return this.superAdminService.listUsers()
    }

    @Delete('users/:id')
    deleteUser(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
        return this.superAdminService.deleteUser(id, req.user?.id)
    }

    // ── Complaints (all panchayats) ─────────────────────────────────────────
    @Get('complaints')
    listComplaints(@Query('status') status?: string, @Query('panchayat_id') pid?: string) {
        const panchayatId = pid ? parseInt(pid, 10) : undefined
        return this.superAdminService.listComplaints(status, isNaN(panchayatId as number) ? undefined : panchayatId)
    }

    @Post('complaints')
    createComplaint(
        @Body()
        body: {
            pole_id: number
            complaint_type?: string
            description?: string
            urgency_level?: string
            caller_language?: string
            caller_emotion?: string
        }
    ) {
        return this.superAdminService.createComplaint(body)
    }

    @Patch('complaints/:id/status')
    updateComplaintStatus(@Param('id', ParseIntPipe) id: number, @Body() body: { status: string }) {
        return this.superAdminService.updateComplaintStatus(id, body.status)
    }

    /** Assign a pole to a manual_review complaint + auto-learn the caller's landmark. */
    @Patch('complaints/:id/resolve')
    resolveComplaint(@Param('id', ParseIntPipe) id: number, @Body() body: { pole_id: number }) {
        return this.superAdminService.resolveComplaint(id, body.pole_id)
    }

    @Patch('complaints/:id/assign-electrician')
    assignElectricianSa(
        @Param('id', ParseIntPipe) id: number,
        @Body() body: { electrician_user_id: number }
    ) {
        return this.superAdminService.assignElectricianGlobal(id, body.electrician_user_id)
    }

    // ── STT Provider Settings ────────────────────────────────────────────────
    @Get('settings/stt-provider')
    getSttProvider() {
        return this.superAdminService.getSttProvider()
    }

    @Put('settings/stt-provider')
    setSttProvider(@Body() body: { provider: string }) {
        return this.superAdminService.setSttProvider(body.provider)
    }

    // ── LLM Provider Settings ────────────────────────────────────────────────
    @Get('settings/llm-provider')
    getLlmProvider() {
        return this.superAdminService.getLlmProvider()
    }

    @Put('settings/llm-provider')
    setLlmProvider(@Body() body: { provider: string }) {
        return this.superAdminService.setLlmProvider(body.provider)
    }

    // ── API Key Management ──────────────────────────────────────────────
    @Get('settings/api-keys')
    getApiKeys() {
        return this.superAdminService.getApiKeys()
    }

    @Put('settings/api-keys')
    setApiKeys(@Body() body: { rapidapi_key?: string }) {
        return this.superAdminService.setApiKeys(body)
    }

    // ── Document template defaults (platform-wide) ─────────────────────────
    @Get('settings/document-templates')
    getDocumentTemplateDefaults() {
        return this.documentTemplateSettings.getGlobalSettings()
    }

    @Put('settings/document-templates')
    updateDocumentTemplateDefaults(@Body() body: { templates?: unknown }) {
        return this.documentTemplateSettings.updateGlobalSettings(body)
    }

    @Post('settings/document-templates/:templateId/design')
    saveDocumentTemplateDesign(
        @Param('templateId') templateId: string,
        @Body() body: { fabric_scene?: unknown; overlay_svg?: unknown },
    ) {
        validateTemplateId(templateId)
        return this.documentTemplateSettings.saveGlobalDesign(templateId, body)
    }

    @Post('settings/document-templates/:templateId/preview')
    async previewDocumentTemplate(
        @Param('templateId') templateId: string,
        @Body() body: { panchayat_id?: number; tender_id?: number; vendor_id?: number } = {},
        @Res() res: Response,
    ) {
        validateTemplateId(templateId)
        const panchayatId = body.panchayat_id ?? 1
        if (!Number.isFinite(panchayatId) || panchayatId <= 0) {
            throw new BadRequestException('panchayat_id is required for preview')
        }
        const html = await this.documentTemplateSettings.buildPreviewHtml(
            Math.floor(panchayatId),
            templateId,
            { tender_id: body.tender_id, vendor_id: body.vendor_id },
        )
        res.setHeader('Content-Type', 'text/html; charset=utf-8')
        res.send(html)
    }

    // ── Stats ──────────────────────────────────────────────────────────────
    @Get('dashboard/insights')
    getDashboardInsights() {
        return this.superAdminService.getDashboardInsights()
    }

    @Get('stats')
    getStats() {
        return this.superAdminService.getStats()
    }

    // Backward-compatible alias used by some dashboard clients.
    @Get('state')
    getState() {
        return this.superAdminService.getState()
    }

    // ── Electricians & ZIP exports (global) ─────────────────────────────
    @Get('electricians')
    listElectricians(@Query('panchayat_id') pid?: string) {
        const panchayatId = pid ? parseInt(pid, 10) : undefined
        return this.electricianOps.listAllElectricians(isNaN(panchayatId as number) ? undefined : panchayatId)
    }

    @Post('electricians')
    createElectricianGlobal(
        @Body()
        body: { panchayat_id: number; email: string; password: string; phone_e164?: string }
    ) {
        return this.electricianOps.createElectricianForPanchayat(body.panchayat_id, {
            email: body.email,
            password: body.password,
            phone_e164: body.phone_e164,
        })
    }

    @Get('electricians/:id/stats')
    electricianStats(
        @Param('id', ParseIntPipe) id: number,
        @Query('preset') preset: string,
        @Query('date_from') dateFrom?: string,
        @Query('date_to') dateTo?: string
    ) {
        if (!preset) throw new BadRequestException('preset query required')
        return this.electricianOps.getElectricianStats(id, null, preset, dateFrom, dateTo)
    }

    @Post('exports/electrician-resolved')
    startElectricianExport(
        @Req() req: any,
        @Body()
        body: { electrician_user_id: number; preset: string; date_from?: string; date_to?: string }
    ) {
        return this.electricianOps.createResolvedExportJob({
            createdByUserId: req.user?.id,
            scopedPanchayatId: null,
            electricianId: body.electrician_user_id,
            preset: body.preset,
            dateFrom: body.date_from,
            dateTo: body.date_to,
        })
    }

    @Get('exports/:jobId')
    getExportJob(@Req() req: any, @Param('jobId', ParseIntPipe) jobId: number) {
        return this.electricianOps.getExportJob(jobId, {
            id: req.user?.id,
            role: req.user?.role,
            panchayat_id: req.user?.panchayat_id,
        })
    }

    @Get('exports/:jobId/download')
    async downloadExport(@Req() req: any, @Res() res: Response, @Param('jobId', ParseIntPipe) jobId: number) {
        const meta = await this.electricianOps.getExportJob(jobId, {
            id: req.user?.id,
            role: req.user?.role,
            panchayat_id: req.user?.panchayat_id,
        })
        if (meta.status !== 'ready' || !meta.download_url) {
            throw new BadRequestException('Export not ready or failed')
        }
        const abs = this.electricianOps.resolveExportAbsolutePath(meta.download_url)
        res.download(abs, `electrician-export-job-${jobId}.zip`)
    }
}
