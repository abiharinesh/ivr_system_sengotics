import { Controller, Get, Post, Put, Delete, Patch, Body, Param, Query, Req, ParseIntPipe, UseGuards } from '@nestjs/common'
import { SuperAdminService } from './super-admin.service'
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'
import { RolesGuard } from '../auth/guards/roles.guard'
import { Roles } from '../auth/decorators/roles.decorator'

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin')
@Controller('api/superadmin')
export class SuperAdminController {
    constructor(private readonly superAdminService: SuperAdminService) { }

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

    // ── Pole Management (Read-Only across all panchayats) ───────────────────
    @Get('poles')
    listPoles(@Query('panchayat_id') pid?: string) {
        const panchayatId = pid ? parseInt(pid, 10) : undefined
        return this.superAdminService.listPoles(isNaN(panchayatId as number) ? undefined : panchayatId)
    }

    // ── Admin User Management ──────────────────────────────────────────────
    @Post('users')
    createPanchayatAdmin(@Body() body: { email: string; password: string; panchayat_id: number }) {
        return this.superAdminService.createPanchayatAdmin(body)
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

    @Patch('complaints/:id/status')
    updateComplaintStatus(@Param('id', ParseIntPipe) id: number, @Body() body: { status: string }) {
        return this.superAdminService.updateComplaintStatus(id, body.status)
    }

    /** Assign a pole to a manual_review complaint + auto-learn the caller's landmark. */
    @Patch('complaints/:id/resolve')
    resolveComplaint(@Param('id', ParseIntPipe) id: number, @Body() body: { pole_id: number }) {
        return this.superAdminService.resolveComplaint(id, body.pole_id)
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

    // ── Stats ──────────────────────────────────────────────────────────────
    @Get('stats')
    getStats() {
        return this.superAdminService.getStats()
    }
}
