import { Injectable, Logger, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { PrismaService, validateComplaintStatus } from '@app/shared'
import * as bcrypt from 'bcrypt'
import {
    buildResolutionTrend, mergeRecentActivity, utcMondayWeekStart,
    type ComplaintResolutionFields,
} from './dashboard-insights'

const STAFF_ROLES = ['agent', 'electrician'] as const

@Injectable()
export class AdminServiceService {
    private readonly logger = new Logger(AdminServiceService.name)
    constructor(
        private readonly prisma: PrismaService,
        private readonly config: ConfigService,
    ) {}

    // ══════════════════════════════════════════════════════════════════════
    //   SUPER-ADMIN OPERATIONS (global scope)
    // ══════════════════════════════════════════════════════════════════════

    // ── Panchayat Management ────────────────────────────────────────────
    async createPanchayat(data: { name: string; ivr_number?: string; center_lat?: number; center_lng?: number }) {
        return this.prisma.panchayat.create({ data })
    }
    async updatePanchayat(id: number, data: { name?: string; ivr_number?: string; center_lat?: number; center_lng?: number }) {
        await this.ensurePanchayatExists(id)
        return this.prisma.panchayat.update({ where: { id }, data })
    }
    async deletePanchayat(id: number) {
        await this.ensurePanchayatExists(id)
        await this.prisma.panchayat.delete({ where: { id } })
        return { success: true }
    }
    async listPanchayats() {
        return this.prisma.panchayat.findMany({
            include: { _count: { select: { electric_poles: true, complaints: true, users: true } } }
        })
    }
    async getPanchayat(id: number) {
        const p = await this.prisma.panchayat.findUnique({
            where: { id }, include: { electric_poles: true, _count: { select: { complaints: true } } }
        })
        if (!p) throw new NotFoundException(`Panchayat #${id} not found`)
        return p
    }

    // ── Poles (global) ──────────────────────────────────────────────────
    async createPoleGlobal(data: { panchayat_id: number; pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) {
        await this.ensurePanchayatExists(data.panchayat_id)
        const pole = await this.prisma.electricPole.create({
            data: { panchayat_id: data.panchayat_id, pole_number: data.pole_number, keypad_id: data.keypad_id, latitude: data.latitude, longitude: data.longitude, landmarks: data.landmarks ?? [] }
        })
        if (data.latitude !== undefined && data.longitude !== undefined) {
            await this.prisma.$executeRaw`UPDATE electric_poles SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326) WHERE id = ${pole.id}`
        }
        return pole
    }
    async listPolesGlobal(panchayatId?: number) {
        return this.prisma.electricPole.findMany({
            where: { ...(panchayatId && !isNaN(panchayatId) && { panchayat_id: panchayatId }) },
            include: { panchayat: true, _count: { select: { complaints: true } }, complaints: { select: { status: true } } },
            orderBy: { id: 'desc' }
        })
    }
    async updatePoleGlobal(poleId: number, data: { panchayat_id?: number; pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) {
        const existing = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!existing) throw new NotFoundException(`Pole #${poleId} not found`)
        if (data.panchayat_id) await this.ensurePanchayatExists(data.panchayat_id)
        const updated = await this.prisma.electricPole.update({ where: { id: poleId }, data })
        const lat = data.latitude ?? updated.latitude; const lng = data.longitude ?? updated.longitude
        if (lat != null && lng != null) {
            await this.prisma.$executeRaw`UPDATE electric_poles SET location = ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326) WHERE id = ${poleId}`
        }
        return updated
    }
    async deletePoleGlobal(poleId: number) {
        const existing = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!existing) throw new NotFoundException(`Pole #${poleId} not found`)
        await this.prisma.electricPole.delete({ where: { id: poleId } })
        return { success: true }
    }

    // ── User Management ─────────────────────────────────────────────────
    async createPanchayatAdmin(data: { email: string; password: string; panchayat_id: number }) {
        if (!data.password || data.password.length < 8) throw new BadRequestException('Password must be at least 8 characters long')
        await this.ensurePanchayatExists(data.panchayat_id)
        const existing = await this.prisma.user.findUnique({ where: { email: data.email } })
        if (existing) throw new ForbiddenException('Email already in use')
        const password_hash = await bcrypt.hash(data.password, 10)
        return this.prisma.user.create({
            data: { email: data.email, password_hash, role: 'panchayat_admin', panchayat_id: data.panchayat_id },
            select: { id: true, email: true, role: true, panchayat_id: true, created_at: true }
        })
    }
    async createStaffUser(data: { email: string; password: string; role: string; panchayat_id: number; phone_e164?: string | null }) {
        if (!STAFF_ROLES.includes(data.role as (typeof STAFF_ROLES)[number])) throw new BadRequestException(`role must be one of: ${STAFF_ROLES.join(', ')}`)
        if (!data.password || data.password.length < 8) throw new BadRequestException('Password must be at least 8 characters long')
        await this.ensurePanchayatExists(data.panchayat_id)
        const existing = await this.prisma.user.findUnique({ where: { email: data.email } })
        if (existing) throw new ForbiddenException('Email already in use')
        const password_hash = await bcrypt.hash(data.password, 10)
        return this.prisma.user.create({
            data: { email: data.email, password_hash, role: data.role, panchayat_id: data.panchayat_id, phone_e164: data.phone_e164?.trim() || null },
            select: { id: true, email: true, role: true, panchayat_id: true, phone_e164: true, created_at: true }
        })
    }
    async listUsers() {
        return this.prisma.user.findMany({ select: { id: true, email: true, role: true, panchayat_id: true, created_at: true, panchayat: { select: { name: true } } } })
    }
    async deleteUser(id: number, currentUserId?: number) {
        if (currentUserId && id === currentUserId) throw new ForbiddenException('Cannot delete your own account')
        const user = await this.prisma.user.findUnique({ where: { id } })
        if (!user) throw new NotFoundException(`User #${id} not found`)
        if (user.role === 'super_admin') {
            const count = await this.prisma.user.count({ where: { role: 'super_admin' } })
            if (count <= 1) throw new ForbiddenException('Cannot delete the last super admin')
        }
        await this.prisma.user.delete({ where: { id } })
        return { success: true }
    }

    // ── Complaints (global) ─────────────────────────────────────────────
    async listComplaintsGlobal(status?: string, panchayatId?: number) {
        if (status) validateComplaintStatus(status)
        return this.prisma.complaint.findMany({
            where: { ...(status && { status }), ...(panchayatId && !isNaN(panchayatId) && { panchayat_id: panchayatId }) },
            include: { pole: true, panchayat: true, voice_call: true, assigned_electrician: { select: { id: true, email: true } } },
            orderBy: { created_at: 'desc' }
        })
    }
    async createComplaintGlobal(data: { pole_id: number; complaint_type?: string; description?: string; urgency_level?: string; caller_language?: string; caller_emotion?: string }) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: data.pole_id } })
        if (!pole) throw new NotFoundException(`Pole #${data.pole_id} not found`)
        if (!pole.panchayat_id) throw new BadRequestException('Selected pole has no panchayat context')
        const complaint = await this.prisma.complaint.create({
            data: {
                pole_id: data.pole_id, panchayat_id: pole.panchayat_id,
                complaint_type: data.complaint_type?.trim() || 'manual_reported',
                description: data.description?.trim() || null,
                urgency_level: data.urgency_level?.trim() || null,
                caller_language: data.caller_language?.trim() || null,
                caller_emotion: data.caller_emotion?.trim() || null,
                status: 'pending',
            },
            include: { pole: true, panchayat: true, assigned_electrician: { select: { id: true, email: true } } },
        })
        return this.autoAssignComplaintRoundRobin(pole.panchayat_id, complaint.id)
    }
    async updateComplaintStatusGlobal(id: number, status: string) {
        validateComplaintStatus(status)
        const c = await this.prisma.complaint.findUnique({ where: { id } })
        if (!c) throw new NotFoundException(`Complaint #${id} not found`)
        return this.prisma.complaint.update({ where: { id }, data: { status, ...(status === 'resolved' ? { resolved_at: new Date() } : {}) } })
    }
    async resolveComplaintGlobal(complaintId: number, poleId: number) {
        const complaint = await this.prisma.complaint.findUnique({ where: { id: complaintId }, include: { voice_call: true } })
        if (!complaint) throw new NotFoundException(`Complaint #${complaintId} not found`)
        if (complaint.status !== 'manual_review') throw new BadRequestException(`Can only resolve complaints with status 'manual_review'. Current status: '${complaint.status}'`)
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)
        const updated = await this.prisma.complaint.update({
            where: { id: complaintId },
            data: { pole_id: poleId, panchayat_id: pole.panchayat_id, status: 'pending' },
            include: { pole: true, panchayat: true }
        })
        await this.learnLandmark(complaint, pole)
        this.logger.log(`✅ Complaint #${complaintId} resolved → pole #${poleId}`)
        if (!pole.panchayat_id) return updated
        return this.autoAssignComplaintRoundRobin(pole.panchayat_id, complaintId)
    }
    async assignElectricianGlobal(complaintId: number, electricianUserId: number) {
        const complaint = await this.prisma.complaint.findUnique({ where: { id: complaintId } })
        if (!complaint) throw new NotFoundException(`Complaint #${complaintId} not found`)
        if (!complaint.panchayat_id) throw new BadRequestException('Complaint has no panchayat context')
        return this.assignElectrician(complaint.panchayat_id, complaintId, electricianUserId)
    }

    // ── Settings ────────────────────────────────────────────────────────
    async getSttProvider() {
        const s = await this.prisma.systemSettings.findUnique({ where: { key: 'stt_provider' } })
        return { provider: s?.value ?? 'gemini', available_providers: ['gemini', 'groq', 'rapidapi', 'google-speech'], updated_at: s?.updated_at ?? null }
    }
    async setSttProvider(provider: string) {
        const valid = ['gemini', 'groq', 'rapidapi', 'google-speech']
        if (!valid.includes(provider)) throw new BadRequestException(`Invalid STT provider "${provider}". Must be one of: ${valid.join(', ')}`)
        const s = await this.prisma.systemSettings.upsert({ where: { key: 'stt_provider' }, update: { value: provider }, create: { key: 'stt_provider', value: provider } })
        return { provider: s.value, message: `STT provider set to ${provider}`, updated_at: s.updated_at }
    }
    async getLlmProvider() {
        const s = await this.prisma.systemSettings.findUnique({ where: { key: 'llm_provider' } })
        return { provider: s?.value ?? 'gemini', available_providers: ['gemini', 'groq'], updated_at: s?.updated_at ?? null }
    }
    async setLlmProvider(provider: string) {
        const valid = ['gemini', 'groq']
        if (!valid.includes(provider)) throw new BadRequestException(`Invalid LLM provider "${provider}". Must be one of: ${valid.join(', ')}`)
        const s = await this.prisma.systemSettings.upsert({ where: { key: 'llm_provider' }, update: { value: provider }, create: { key: 'llm_provider', value: provider } })
        return { provider: s.value, message: `LLM provider set to ${provider}`, updated_at: s.updated_at }
    }
    async getApiKeys() {
        const rk = await this.prisma.systemSettings.findUnique({ where: { key: 'rapidapi_key' } })
        return { rapidapi_key: rk?.value ? `${rk.value.slice(0, 8)}...${rk.value.slice(-4)}` : null, rapidapi_key_set: !!rk?.value, updated_at: rk?.updated_at ?? null }
    }
    async setApiKeys(data: { rapidapi_key?: string }) {
        const results: Record<string, any> = {}
        if (data.rapidapi_key) {
            if (data.rapidapi_key.length < 10) throw new BadRequestException('Invalid RapidAPI key — too short')
            const s = await this.prisma.systemSettings.upsert({ where: { key: 'rapidapi_key' }, update: { value: data.rapidapi_key }, create: { key: 'rapidapi_key', value: data.rapidapi_key } })
            results.rapidapi_key = { set: true, updated_at: s.updated_at }
        }
        return { message: 'API keys updated', ...results }
    }

    // ── Global Stats ────────────────────────────────────────────────────
    async getStatsGlobal() {
        const [complaints, pending, resolved, manual_review, poles, panchayats, users] = await Promise.all([
            this.prisma.complaint.count(), this.prisma.complaint.count({ where: { status: 'pending' } }),
            this.prisma.complaint.count({ where: { status: 'resolved' } }), this.prisma.complaint.count({ where: { status: 'manual_review' } }),
            this.prisma.electricPole.count(), this.prisma.panchayat.count(), this.prisma.user.count()
        ])
        return { total_complaints: complaints, pending_complaints: pending, resolved_complaints: resolved, manual_review_complaints: manual_review, total_poles: poles, total_panchayats: panchayats, total_admins: users }
    }
    async getState() {
        const [stats, p1p, p1f, p2p, p2f] = await Promise.all([
            this.getStatsGlobal(),
            this.prisma.callState.count({ where: { phase1_status: 'pending' } }),
            this.prisma.callState.count({ where: { phase1_status: 'failed' } }),
            this.prisma.callState.count({ where: { phase2_status: 'pending' } }),
            this.prisma.callState.count({ where: { phase2_status: 'failed' } }),
        ])
        return { ...stats, call_pipeline: { phase1_pending: p1p, phase1_failed: p1f, phase2_pending: p2p, phase2_failed: p2f } }
    }
    async getDashboardInsightsGlobal() { return this.buildDashboardInsights() }

    // ══════════════════════════════════════════════════════════════════════
    //   PANCHAYAT-ADMIN OPERATIONS (scoped to panchayat)
    // ══════════════════════════════════════════════════════════════════════

    async getMe(userId: number) {
        const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { id: true, email: true, role: true, panchayat_id: true, panchayat: true } })
        if (!user) throw new NotFoundException('User not found')
        return user
    }

    // ── Poles (scoped) ──────────────────────────────────────────────────
    async createPoleScoped(panchayatId: number, data: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) {
        const pole = await this.prisma.electricPole.create({ data: { pole_number: data.pole_number, keypad_id: data.keypad_id, latitude: data.latitude, longitude: data.longitude, landmarks: data.landmarks ?? [], panchayat_id: panchayatId } })
        if (data.latitude && data.longitude) {
            await this.prisma.$executeRaw`UPDATE electric_poles SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326) WHERE id = ${pole.id}`
        }
        return pole
    }
    async listPolesScoped(panchayatId: number) {
        return this.prisma.electricPole.findMany({
            where: { panchayat_id: panchayatId },
            include: { _count: { select: { complaints: true } }, complaints: { select: { status: true } } }
        })
    }
    async updatePoleScoped(panchayatId: number, poleId: number, data: { pole_number?: string; keypad_id?: string; latitude?: number; longitude?: number; landmarks?: string[] }) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)
        if (pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — pole belongs to another panchayat')
        const updated = await this.prisma.electricPole.update({ where: { id: poleId }, data })
        if (data.latitude && data.longitude) {
            await this.prisma.$executeRaw`UPDATE electric_poles SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326) WHERE id = ${poleId}`
        }
        return updated
    }
    async deletePoleScoped(panchayatId: number, poleId: number) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)
        if (pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — pole belongs to another panchayat')
        await this.prisma.electricPole.delete({ where: { id: poleId } })
        return { success: true }
    }

    // ── Complaints (scoped) ─────────────────────────────────────────────
    async listComplaintsScoped(panchayatId: number, status?: string) {
        return this.prisma.complaint.findMany({
            where: { panchayat_id: panchayatId, ...(status && { status }) },
            include: { pole: true, voice_call: true, assigned_electrician: { select: { id: true, email: true } } },
            orderBy: { created_at: 'desc' }
        })
    }
    async createComplaintScoped(panchayatId: number, data: { pole_id: number; complaint_type?: string; description?: string; urgency_level?: string; caller_language?: string; caller_emotion?: string }) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: data.pole_id } })
        if (!pole) throw new NotFoundException(`Pole #${data.pole_id} not found`)
        if (pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — pole belongs to another panchayat')
        const complaint = await this.prisma.complaint.create({
            data: {
                pole_id: data.pole_id, panchayat_id: panchayatId,
                complaint_type: data.complaint_type?.trim() || 'manual_reported',
                description: data.description?.trim() || null, urgency_level: data.urgency_level?.trim() || null,
                caller_language: data.caller_language?.trim() || null, caller_emotion: data.caller_emotion?.trim() || null,
                status: 'pending',
            },
            include: { pole: true, assigned_electrician: { select: { id: true, email: true } } },
        })
        return this.autoAssignComplaintRoundRobin(panchayatId, complaint.id)
    }
    async updateComplaintStatusScoped(panchayatId: number, complaintId: number, status: string) {
        validateComplaintStatus(status)
        const c = await this.prisma.complaint.findUnique({ where: { id: complaintId } })
        if (!c) throw new NotFoundException(`Complaint #${complaintId} not found`)
        if (c.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — complaint belongs to another panchayat')
        return this.prisma.complaint.update({ where: { id: complaintId }, data: { status, ...(status === 'resolved' ? { resolved_at: new Date() } : {}) } })
    }
    async resolveComplaintScoped(panchayatId: number, complaintId: number, poleId: number) {
        const complaint = await this.prisma.complaint.findUnique({ where: { id: complaintId }, include: { voice_call: true } })
        if (!complaint) throw new NotFoundException(`Complaint #${complaintId} not found`)
        if (complaint.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — complaint belongs to another panchayat')
        if (complaint.status !== 'manual_review') throw new BadRequestException(`Can only resolve complaints with status 'manual_review'. Current status: '${complaint.status}'`)
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)
        if (pole.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — pole belongs to another panchayat')
        await this.prisma.complaint.update({ where: { id: complaintId }, data: { pole_id: poleId, status: 'pending' }, include: { pole: true } })
        await this.learnLandmark(complaint, pole)
        this.logger.log(`✅ Complaint #${complaintId} resolved → pole #${poleId}`)
        return this.autoAssignComplaintRoundRobin(panchayatId, complaintId)
    }

    // ── Panchayat-scoped stats ──────────────────────────────────────────
    async getStatsScoped(panchayatId: number) {
        const [total, pending, resolved, manual_review, poles] = await Promise.all([
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId } }),
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId, status: 'pending' } }),
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId, status: 'resolved' } }),
            this.prisma.complaint.count({ where: { panchayat_id: panchayatId, status: 'manual_review' } }),
            this.prisma.electricPole.count({ where: { panchayat_id: panchayatId } })
        ])
        return { total_complaints: total, pending_complaints: pending, resolved_complaints: resolved, manual_review_complaints: manual_review, total_poles: poles }
    }
    async getDashboardInsightsScoped(panchayatId: number) { return this.buildDashboardInsights(panchayatId) }

    // ══════════════════════════════════════════════════════════════════════
    //   SHARED PRIVATE HELPERS
    // ══════════════════════════════════════════════════════════════════════

    async assignElectrician(panchayatId: number, complaintId: number, electricianUserId: number) {
        const sparky = await this.prisma.user.findUnique({ where: { id: electricianUserId }, select: { id: true, role: true, panchayat_id: true, phone_e164: true } })
        if (!sparky || sparky.role !== 'electrician') throw new BadRequestException('User is not an electrician')
        if (sparky.panchayat_id !== panchayatId) throw new ForbiddenException('Electrician belongs to another panchayat')
        const complaint = await this.prisma.complaint.findUnique({ where: { id: complaintId } })
        if (!complaint) throw new NotFoundException(`Complaint #${complaintId} not found`)
        if (complaint.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — complaint belongs to another panchayat')
        if (!['pending', 'reassign_required'].includes(complaint.status)) throw new BadRequestException(`Can only assign complaints in status pending or reassign_required. Current: ${complaint.status}`)
        const updated = await this.prisma.complaint.update({
            where: { id: complaintId },
            data: { assigned_electrician_id: electricianUserId, assigned_at: new Date(), status: 'assigned' },
            include: { pole: true, assigned_electrician: { select: { id: true, email: true, phone_e164: true } } },
        })
        // WhatsApp notification (direct Cloud API call — no separate service dependency)
        if (sparky.phone_e164) {
            const token = this.config.get<string>('WHATSAPP_CLOUD_TOKEN')
            const phoneId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID')
            if (token && phoneId) {
                const to = sparky.phone_e164.replace(/^\+/, '').replace(/\D/g, '')
                const msg = `Complaint #${complaintId} is assigned to you. Use the field app, or reply DONE ${complaintId} when the work is finished.`
                fetch(`https://graph.facebook.com/v21.0/${phoneId}/messages`, {
                    method: 'POST',
                    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
                    body: JSON.stringify({ messaging_product: 'whatsapp', to, type: 'text', text: { body: msg } }),
                }).catch((err) => this.logger.warn(`WhatsApp notify failed: ${err?.message ?? err}`))
            }
        }
        return updated
    }

    async autoAssignComplaintRoundRobin(panchayatId: number, complaintId: number) {
        const complaint = await this.prisma.complaint.findUnique({
            where: { id: complaintId },
            include: { pole: true, assigned_electrician: { select: { id: true, email: true } } },
        })
        if (!complaint) throw new NotFoundException(`Complaint #${complaintId} not found`)
        if (complaint.panchayat_id !== panchayatId) throw new ForbiddenException('Access denied — complaint belongs to another panchayat')
        if (!['pending', 'reassign_required'].includes(complaint.status)) return complaint

        const electricians = await this.prisma.user.findMany({ where: { role: 'electrician', panchayat_id: panchayatId }, select: { id: true }, orderBy: { id: 'asc' } })
        if (electricians.length === 0) { this.logger.warn(`No electricians available for panchayat #${panchayatId}`); return complaint }

        const latestAssignments = await this.prisma.complaint.findMany({
            where: { panchayat_id: panchayatId, assigned_electrician_id: { in: electricians.map((e) => e.id) }, assigned_at: { not: null } },
            select: { assigned_electrician_id: true, assigned_at: true },
            orderBy: [{ assigned_at: 'desc' }],
        })
        const lastByElectrician = new Map<number, Date | null>()
        for (const row of latestAssignments) {
            if (row.assigned_electrician_id != null && !lastByElectrician.has(row.assigned_electrician_id)) {
                lastByElectrician.set(row.assigned_electrician_id, row.assigned_at)
            }
        }
        electricians.sort((a, b) => {
            const aL = lastByElectrician.get(a.id) ?? null; const bL = lastByElectrician.get(b.id) ?? null
            if (aL == null && bL == null) return a.id - b.id
            if (aL == null) return -1; if (bL == null) return 1
            const cmp = aL.getTime() - bL.getTime(); return cmp !== 0 ? cmp : a.id - b.id
        })
        try { return await this.assignElectrician(panchayatId, complaintId, electricians[0].id) }
        catch (err: any) { this.logger.warn(`Round-robin auto assignment failed for complaint #${complaintId}: ${err?.message ?? err}`); return complaint }
    }

    private async learnLandmark(complaint: { voice_call_id: number | null; voice_call: { ai_extracted_json: any } | null }, pole: { id: number; landmarks: string[] }): Promise<void> {
        if (!complaint.voice_call?.ai_extracted_json) return
        const extracted = complaint.voice_call.ai_extracted_json as Record<string, any>
        const newLandmarks: string[] = []
        if (extracted.landmark_english && typeof extracted.landmark_english === 'string') newLandmarks.push(extracted.landmark_english.trim())
        if (extracted.landmark && typeof extracted.landmark === 'string') newLandmarks.push(extracted.landmark.trim())
        if (newLandmarks.length === 0) return
        const existingLower = pole.landmarks.map(l => l.toLowerCase())
        const uniqueNew = newLandmarks.filter(l => l.length > 0 && !existingLower.includes(l.toLowerCase()))
        if (uniqueNew.length === 0) return
        await this.prisma.electricPole.update({ where: { id: pole.id }, data: { landmarks: [...pole.landmarks, ...uniqueNew] } })
        this.logger.log(`[Learn] ✅ Added ${uniqueNew.length} new landmark(s) to pole #${pole.id}: ${uniqueNew.join(', ')}`)
    }

    private async buildDashboardInsights(panchayatId?: number) {
        const now = new Date()
        const currentWeekStart = utcMondayWeekStart(now)
        const lastWeekStart = new Date(currentWeekStart); lastWeekStart.setUTCDate(lastWeekStart.getUTCDate() - 7)
        const currentWeekEnd = new Date(currentWeekStart); currentWeekEnd.setUTCDate(currentWeekEnd.getUTCDate() + 7)
        const scope = panchayatId ? { panchayat_id: panchayatId } : {}
        const trendOr = [
            { resolved_at: { gte: lastWeekStart, lt: currentWeekEnd } },
            { AND: [{ status: { in: ['resolved_pending_confirmation', 'resolved'] } }, { resolution_image_captured_at: { gte: lastWeekStart, lt: currentWeekEnd } }] },
        ]
        const [forTrend, byCat, newRows, resRows, subRows] = await Promise.all([
            this.prisma.complaint.findMany({ where: { ...scope, OR: trendOr }, select: { id: true, resolved_at: true, resolution_image_captured_at: true, status: true } }),
            this.prisma.complaint.groupBy({ by: ['complaint_type'], where: scope, _count: { _all: true }, orderBy: { _count: { complaint_type: 'desc' } }, take: 8 }),
            this.prisma.complaint.findMany({ where: scope, orderBy: { created_at: 'desc' }, take: 5, select: { id: true, complaint_type: true, description: true, status: true, created_at: true, resolved_at: true, resolution_image_captured_at: true } }),
            this.prisma.complaint.findMany({ where: { ...scope, resolved_at: { not: null } }, orderBy: { resolved_at: 'desc' }, take: 5, select: { id: true, complaint_type: true, description: true, status: true, created_at: true, resolved_at: true, resolution_image_captured_at: true } }),
            this.prisma.complaint.findMany({ where: { ...scope, status: 'resolved_pending_confirmation', resolved_at: null, resolution_image_captured_at: { not: null } }, orderBy: { resolution_image_captured_at: 'desc' }, take: 5, select: { id: true, complaint_type: true, description: true, status: true, created_at: true, resolved_at: true, resolution_image_captured_at: true } }),
        ])
        return {
            resolution_trend: buildResolutionTrend(forTrend),
            by_category: byCat.map((r) => ({ label: r.complaint_type?.trim() || 'Other', count: r._count._all })),
            recent_activity: mergeRecentActivity(newRows as ComplaintResolutionFields[], resRows as ComplaintResolutionFields[], subRows as ComplaintResolutionFields[]),
        }
    }

    private async ensurePanchayatExists(id: number): Promise<void> {
        const exists = await this.prisma.panchayat.findUnique({ where: { id }, select: { id: true } })
        if (!exists) throw new NotFoundException(`Panchayat #${id} not found`)
    }
}
