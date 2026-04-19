import {
    Controller, Get, Post, Put, Delete, Patch,
    Body, Param, Query, Req, Res, ParseIntPipe,
    UseGuards, BadRequestException, ForbiddenException,
} from '@nestjs/common'
import type { Response } from 'express'
import { JwtAuthGuard, RolesGuard, Roles } from '@app/shared'
import { AdminServiceService } from './admin-service.service'

interface AuthReq { user: { id: number; email: string; role: string; panchayat_id: number | null } }

// ══════════════════════════════════════════════════════════════════════════════
//  SUPER ADMIN CONTROLLER
// ══════════════════════════════════════════════════════════════════════════════

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin')
@Controller('superadmin')
export class SuperAdminController {
    constructor(private readonly svc: AdminServiceService) {}

    // ── Panchayat Management ───────────────────────────────────────────
    @Post('panchayats')    createPanchayat(@Body() b: { name: string; ivr_number?: string; center_lat?: number; center_lng?: number }) { return this.svc.createPanchayat(b) }
    @Get('panchayats')     listPanchayats() { return this.svc.listPanchayats() }
    @Get('panchayats/:id') getPanchayat(@Param('id', ParseIntPipe) id: number) { return this.svc.getPanchayat(id) }
    @Put('panchayats/:id') updatePanchayat(@Param('id', ParseIntPipe) id: number, @Body() b: { name?: string; ivr_number?: string; center_lat?: number; center_lng?: number }) { return this.svc.updatePanchayat(id, b) }
    @Delete('panchayats/:id') deletePanchayat(@Param('id', ParseIntPipe) id: number) { return this.svc.deletePanchayat(id) }

    // ── Poles ──────────────────────────────────────────────────────────
    @Post('poles')    createPole(@Body() b: { panchayat_id: number; pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) { return this.svc.createPoleGlobal(b) }
    @Get('poles')     listPoles(@Query('panchayat_id') pid?: string) { const id = pid ? parseInt(pid, 10) : undefined; return this.svc.listPolesGlobal(isNaN(id as number) ? undefined : id) }
    @Put('poles/:id') updatePole(@Param('id', ParseIntPipe) id: number, @Body() b: { panchayat_id?: number; pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) { return this.svc.updatePoleGlobal(id, b) }
    @Delete('poles/:id') deletePole(@Param('id', ParseIntPipe) id: number) { return this.svc.deletePoleGlobal(id) }

    // ── Users ─────────────────────────────────────────────────────────
    @Post('users')       createPanchayatAdmin(@Body() b: { email: string; password: string; panchayat_id: number }) { return this.svc.createPanchayatAdmin(b) }
    @Post('users/staff') createStaffUser(@Body() b: { email: string; password: string; role: string; panchayat_id: number; phone_e164?: string }) { return this.svc.createStaffUser(b) }
    @Get('users')        listUsers() { return this.svc.listUsers() }
    @Delete('users/:id') deleteUser(@Req() req: any, @Param('id', ParseIntPipe) id: number) { return this.svc.deleteUser(id, req.user?.id) }

    // ── Complaints ────────────────────────────────────────────────────
    @Get('complaints')               listComplaints(@Query('status') s?: string, @Query('panchayat_id') pid?: string) { const id = pid ? parseInt(pid, 10) : undefined; return this.svc.listComplaintsGlobal(s, isNaN(id as number) ? undefined : id) }
    @Post('complaints')              createComplaint(@Body() b: { pole_id: number; complaint_type?: string; description?: string; urgency_level?: string; caller_language?: string; caller_emotion?: string }) { return this.svc.createComplaintGlobal(b) }
    @Patch('complaints/:id/status')  updateStatus(@Param('id', ParseIntPipe) id: number, @Body() b: { status: string }) { return this.svc.updateComplaintStatusGlobal(id, b.status) }
    @Patch('complaints/:id/resolve') resolve(@Param('id', ParseIntPipe) id: number, @Body() b: { pole_id: number }) { return this.svc.resolveComplaintGlobal(id, b.pole_id) }
    @Patch('complaints/:id/assign-electrician') assignElectrician(@Param('id', ParseIntPipe) id: number, @Body() b: { electrician_user_id: number }) { return this.svc.assignElectricianGlobal(id, b.electrician_user_id) }

    // ── Settings ──────────────────────────────────────────────────────
    @Get('settings/stt-provider')  getStt() { return this.svc.getSttProvider() }
    @Put('settings/stt-provider')  setStt(@Body() b: { provider: string }) { return this.svc.setSttProvider(b.provider) }
    @Get('settings/llm-provider')  getLlm() { return this.svc.getLlmProvider() }
    @Put('settings/llm-provider')  setLlm(@Body() b: { provider: string }) { return this.svc.setLlmProvider(b.provider) }
    @Get('settings/api-keys')      getKeys() { return this.svc.getApiKeys() }
    @Put('settings/api-keys')      setKeys(@Body() b: { rapidapi_key?: string }) { return this.svc.setApiKeys(b) }

    // ── Stats ─────────────────────────────────────────────────────────
    @Get('dashboard/insights') insights() { return this.svc.getDashboardInsightsGlobal() }
    @Get('stats')              stats() { return this.svc.getStatsGlobal() }
    @Get('state')              state() { return this.svc.getState() }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PANCHAYAT ADMIN CONTROLLER
// ══════════════════════════════════════════════════════════════════════════════

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin')
@Controller('admin')
export class PanchayatAdminController {
    constructor(private readonly svc: AdminServiceService) {}

    private getPid(req: AuthReq): number {
        if (!req.user.panchayat_id) throw new ForbiddenException('Your account is not associated with any panchayat')
        return req.user.panchayat_id
    }

    @Get('me')                     getMe(@Req() r: AuthReq) { return this.svc.getMe(r.user.id) }
    @Get('dashboard/insights')     insights(@Req() r: AuthReq) { return this.svc.getDashboardInsightsScoped(this.getPid(r)) }
    @Get('stats')                  stats(@Req() r: AuthReq) { return this.svc.getStatsScoped(this.getPid(r)) }

    // ── Poles (scoped) ────────────────────────────────────────────────
    @Post('poles')    createPole(@Req() r: AuthReq, @Body() b: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) { return this.svc.createPoleScoped(this.getPid(r), b) }
    @Get('poles')     listPoles(@Req() r: AuthReq) { return this.svc.listPolesScoped(this.getPid(r)) }
    @Put('poles/:id') updatePole(@Req() r: AuthReq, @Param('id', ParseIntPipe) id: number, @Body() b: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) { return this.svc.updatePoleScoped(this.getPid(r), id, b) }
    @Delete('poles/:id') deletePole(@Req() r: AuthReq, @Param('id', ParseIntPipe) id: number) { return this.svc.deletePoleScoped(this.getPid(r), id) }

    // ── Complaints (scoped) ───────────────────────────────────────────
    @Get('complaints')               listComplaints(@Req() r: AuthReq, @Query('status') s?: string) { return this.svc.listComplaintsScoped(this.getPid(r), s) }
    @Post('complaints')              createComplaint(@Req() r: AuthReq, @Body() b: { pole_id: number; complaint_type?: string; description?: string; urgency_level?: string; caller_language?: string; caller_emotion?: string }) { return this.svc.createComplaintScoped(this.getPid(r), b) }
    @Patch('complaints/:id/status')  updateStatus(@Req() r: AuthReq, @Param('id', ParseIntPipe) id: number, @Body() b: { status: string }) { return this.svc.updateComplaintStatusScoped(this.getPid(r), id, b.status) }
    @Patch('complaints/:id/resolve') resolve(@Req() r: AuthReq, @Param('id', ParseIntPipe) id: number, @Body() b: { pole_id: number }) { return this.svc.resolveComplaintScoped(this.getPid(r), id, b.pole_id) }
    @Patch('complaints/:id/assign-electrician') assign(@Req() r: AuthReq, @Param('id', ParseIntPipe) id: number, @Body() b: { electrician_user_id: number }) { return this.svc.assignElectrician(this.getPid(r), id, b.electrician_user_id) }
}
