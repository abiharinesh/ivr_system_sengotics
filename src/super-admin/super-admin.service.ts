import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import { validateComplaintStatus } from '../common/complaint-status';
import {
  buildResolutionTrend,
  mergeRecentActivity,
  utcMondayWeekStart,
  type ComplaintResolutionFields,
} from '../common/dashboard-insights';
import { PanchayatAdminService } from '../panchayat-admin/panchayat-admin.service';
import { PenaltyService } from '../penalty/penalty.service';

const STAFF_ROLES = ['agent', 'electrician'] as const;

@Injectable()
export class SuperAdminService {
  private readonly logger = new Logger(SuperAdminService.name);
  constructor(
    private prisma: PrismaService,
    private readonly panchayatAdmin: PanchayatAdminService,
    private readonly penaltyService: PenaltyService,
  ) {}

  /** Delegate to panchayat-scoped assign (validates electrician + WhatsApp notify). */
  async assignElectricianGlobal(
    complaintId: number,
    electricianUserId: number,
  ) {
    const complaint = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
    });
    if (!complaint)
      throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (!complaint.panchayat_id) {
      throw new BadRequestException('Complaint has no panchayat context');
    }
    return this.panchayatAdmin.assignElectrician(
      complaint.panchayat_id,
      complaintId,
      electricianUserId,
    );
  }

  // ── Panchayat Management ────────────────────────────────────────────────

  async createPanchayat(data: {
    name: string;
    ivr_number?: string;
    center_lat?: number;
    center_lng?: number;
  }) {
    return this.prisma.panchayat.create({ data });
  }

  async updatePanchayat(
    id: number,
    data: {
      name?: string;
      ivr_number?: string;
      center_lat?: number;
      center_lng?: number;
    },
  ) {
    await this.ensurePanchayatExists(id);
    return this.prisma.panchayat.update({ where: { id }, data });
  }

  async deletePanchayat(id: number) {
    await this.ensurePanchayatExists(id);
    await this.prisma.panchayat.delete({ where: { id } });
    return { success: true };
  }

  async listPanchayats() {
    return this.prisma.panchayat.findMany({
      include: {
        _count: {
          select: { electric_poles: true, complaints: true, users: true },
        },
      },
    });
  }

  async getPanchayat(id: number) {
    const panchayat = await this.prisma.panchayat.findUnique({
      where: { id },
      include: {
        electric_poles: true,
        _count: { select: { complaints: true } },
      },
    });
    if (!panchayat) throw new NotFoundException(`Panchayat #${id} not found`);
    return panchayat;
  }

  // ── Poles (all) ────────────────────────────────────────────────────────
  async createPole(data: {
    panchayat_id: number;
    pole_number?: string;
    keypad_id?: string;
    latitude?: number;
    longitude?: number;
    landmarks?: string[];
  }) {
    await this.ensurePanchayatExists(data.panchayat_id);

    const pole = await this.prisma.electricPole.create({
      data: {
        panchayat_id: data.panchayat_id,
        pole_number: data.pole_number,
        keypad_id: data.keypad_id,
        latitude: data.latitude,
        longitude: data.longitude,
        landmarks: data.landmarks ?? [],
      },
    });

    if (data.latitude !== undefined && data.longitude !== undefined) {
      await this.prisma.$executeRaw`
                UPDATE electric_poles
                SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)
                WHERE id = ${pole.id}
            `;
    }

    return pole;
  }

  async listPoles(panchayatId?: number) {
    return this.prisma.electricPole.findMany({
      where: {
        ...(panchayatId &&
          !isNaN(panchayatId) && { panchayat_id: panchayatId }),
      },
      include: {
        panchayat: true,
        _count: { select: { complaints: true } },
        complaints: { select: { status: true } },
      },
      orderBy: { id: 'desc' },
    });
  }

  async updatePole(
    poleId: number,
    data: {
      panchayat_id?: number;
      pole_number?: string;
      keypad_id?: string;
      latitude?: number;
      longitude?: number;
      landmarks?: string[];
    },
  ) {
    const existing = await this.prisma.electricPole.findUnique({
      where: { id: poleId },
    });
    if (!existing) throw new NotFoundException(`Pole #${poleId} not found`);

    if (data.panchayat_id) {
      await this.ensurePanchayatExists(data.panchayat_id);
    }

    const updated = await this.prisma.electricPole.update({
      where: { id: poleId },
      data,
    });

    const lat = data.latitude ?? updated.latitude;
    const lng = data.longitude ?? updated.longitude;
    if (
      lat !== null &&
      lat !== undefined &&
      lng !== null &&
      lng !== undefined
    ) {
      await this.prisma.$executeRaw`
                UPDATE electric_poles
                SET location = ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
                WHERE id = ${poleId}
            `;
    }

    return updated;
  }

  async deletePole(poleId: number) {
    const existing = await this.prisma.electricPole.findUnique({
      where: { id: poleId },
    });
    if (!existing) throw new NotFoundException(`Pole #${poleId} not found`);
    await this.prisma.electricPole.delete({ where: { id: poleId } });
    return { success: true };
  }

  // ── User (Panchayat Admin) Management ──────────────────────────────────

  async createPanchayatAdmin(data: {
    email: string;
    password: string;
    panchayat_id: number;
  }) {
    // Password strength check
    if (!data.password || data.password.length < 8) {
      throw new BadRequestException(
        'Password must be at least 8 characters long',
      );
    }

    await this.ensurePanchayatExists(data.panchayat_id);

    const existing = await this.prisma.user.findUnique({
      where: { email: data.email },
    });
    if (existing) throw new ForbiddenException('Email already in use');

    const password_hash = await bcrypt.hash(data.password, 10);
    return this.prisma.user.create({
      data: {
        email: data.email,
        password_hash,
        role: 'panchayat_admin',
        panchayat_id: data.panchayat_id,
      },
      select: {
        id: true,
        email: true,
        role: true,
        panchayat_id: true,
        created_at: true,
      },
    });
  }

  /** Agent or electrician login for field ops (scoped to panchayat). */
  async createStaffUser(data: {
    email: string;
    password: string;
    role: string;
    panchayat_id: number;
    phone_e164?: string | null;
  }) {
    if (!STAFF_ROLES.includes(data.role as (typeof STAFF_ROLES)[number])) {
      throw new BadRequestException(
        `role must be one of: ${STAFF_ROLES.join(', ')}`,
      );
    }
    if (!data.password || data.password.length < 8) {
      throw new BadRequestException(
        'Password must be at least 8 characters long',
      );
    }
    await this.ensurePanchayatExists(data.panchayat_id);
    const existing = await this.prisma.user.findUnique({
      where: { email: data.email },
    });
    if (existing) throw new ForbiddenException('Email already in use');
    const password_hash = await bcrypt.hash(data.password, 10);
    return this.prisma.user.create({
      data: {
        email: data.email,
        password_hash,
        role: data.role,
        panchayat_id: data.panchayat_id,
        phone_e164: data.phone_e164?.trim() || null,
      },
      select: {
        id: true,
        email: true,
        role: true,
        panchayat_id: true,
        phone_e164: true,
        created_at: true,
      },
    });
  }

  async listUsers() {
    return this.prisma.user.findMany({
      select: {
        id: true,
        email: true,
        role: true,
        panchayat_id: true,
        created_at: true,
        panchayat: { select: { name: true } },
      },
    });
  }

  async deleteUser(id: number, currentUserId?: number) {
    if (currentUserId && id === currentUserId) {
      throw new ForbiddenException('Cannot delete your own account');
    }

    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException(`User #${id} not found`);

    if (user.role === 'super_admin') {
      // Prevent deleting the last super admin
      const superAdminCount = await this.prisma.user.count({
        where: { role: 'super_admin' },
      });
      if (superAdminCount <= 1) {
        throw new ForbiddenException('Cannot delete the last super admin');
      }
    }

    await this.prisma.user.delete({ where: { id } });
    return { success: true };
  }

  // ── Complaints (all) ───────────────────────────────────────────────────

  async listComplaints(status?: string, panchayatId?: number) {
    if (status) validateComplaintStatus(status);

    return this.prisma.complaint.findMany({
      where: {
        ...(status && { status }),
        ...(panchayatId &&
          !isNaN(panchayatId) && { panchayat_id: panchayatId }),
      },
      include: {
        pole: true,
        panchayat: true,
        voice_call: true,
        assigned_electrician: { select: { id: true, email: true } },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  async createComplaint(data: {
    pole_id: number;
    complaint_type?: string;
    description?: string;
    urgency_level?: string;
    caller_language?: string;
    caller_emotion?: string;
  }) {
    const pole = await this.prisma.electricPole.findUnique({
      where: { id: data.pole_id },
    });
    if (!pole) throw new NotFoundException(`Pole #${data.pole_id} not found`);
    if (!pole.panchayat_id) {
      throw new BadRequestException('Selected pole has no panchayat context');
    }

    const complaint = await this.prisma.complaint.create({
      data: {
        pole_id: data.pole_id,
        panchayat_id: pole.panchayat_id,
        complaint_type: data.complaint_type?.trim() || 'manual_reported',
        description: data.description?.trim() || null,
        urgency_level: data.urgency_level?.trim() || null,
        caller_language: data.caller_language?.trim() || null,
        caller_emotion: data.caller_emotion?.trim() || null,
        status: 'pending',
      },
      include: {
        pole: true,
        panchayat: true,
        assigned_electrician: { select: { id: true, email: true } },
      },
    });

    return this.panchayatAdmin.autoAssignComplaintRoundRobin(
      pole.panchayat_id,
      complaint.id,
    );
  }

  async updateComplaintStatus(id: number, status: string) {
    validateComplaintStatus(status);

    const complaint = await this.prisma.complaint.findUnique({ where: { id } });
    if (!complaint) throw new NotFoundException(`Complaint #${id} not found`);

    const updated = await this.prisma.complaint.update({
      where: { id },
      data: {
        status,
        ...(status === 'resolved' ? { resolved_at: new Date() } : {}),
      },
    });

    if (status === 'resolved') {
      try {
        await this.penaltyService.handleComplaintResolution(id);
      } catch (err) {
        this.logger.error(`Error processing resolution penalty for complaint #${id}: ${(err as Error).message}`);
      }
    }

    return updated;
  }

  /**
   * Resolve a manual_review complaint by assigning it to a pole.
   * Auto-learns: saves the caller's landmark phrase to the pole's landmarks array
   * so future callers using similar language will match instantly.
   */
  async resolveComplaint(complaintId: number, poleId: number) {
    // 1. Validate complaint exists and is manual_review
    const complaint = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
      include: { voice_call: true },
    });
    if (!complaint)
      throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (complaint.status !== 'manual_review') {
      throw new BadRequestException(
        `Can only resolve complaints with status 'manual_review'. Current status: '${complaint.status}'`,
      );
    }

    // 2. Validate pole exists
    const pole = await this.prisma.electricPole.findUnique({
      where: { id: poleId },
    });
    if (!pole) throw new NotFoundException(`Pole #${poleId} not found`);

    // 3. Assign pole and update status
    const updated = await this.prisma.complaint.update({
      where: { id: complaintId },
      data: {
        pole_id: poleId,
        panchayat_id: pole.panchayat_id,
        status: 'pending',
      },
      include: { pole: true, panchayat: true },
    });

    // 4. Auto-learn: extract landmark from voice call and save to pole
    await this.learnLandmark(complaint, pole);

    this.logger.log(`✅ Complaint #${complaintId} resolved → pole #${poleId}`);
    if (!pole.panchayat_id) {
      return updated;
    }
    return this.panchayatAdmin.autoAssignComplaintRoundRobin(
      pole.panchayat_id,
      complaintId,
    );
  }

  /**
   * Extracts the landmark from a voice complaint and adds it to the pole's
   * landmarks array (if it's not already there). This is how the system
   * learns new ways people describe a location.
   */
  private async learnLandmark(
    complaint: {
      voice_call_id: number | null;
      voice_call: { ai_extracted_json: any } | null;
    },
    pole: { id: number; landmarks: string[] },
  ): Promise<void> {
    if (!complaint.voice_call?.ai_extracted_json) return;

    const extracted = complaint.voice_call.ai_extracted_json as Record<
      string,
      any
    >;
    const newLandmarks: string[] = [];

    // Collect both English and original landmark phrases
    if (
      extracted.landmark_english &&
      typeof extracted.landmark_english === 'string'
    ) {
      newLandmarks.push(extracted.landmark_english.trim());
    }
    if (extracted.landmark && typeof extracted.landmark === 'string') {
      newLandmarks.push(extracted.landmark.trim());
    }

    if (newLandmarks.length === 0) return;

    // Filter out landmarks that already exist (case-insensitive)
    const existingLower = pole.landmarks.map((l) => l.toLowerCase());
    const uniqueNew = newLandmarks.filter(
      (l) => l.length > 0 && !existingLower.includes(l.toLowerCase()),
    );

    if (uniqueNew.length === 0) {
      this.logger.log(`[Learn] No new landmarks to add for pole #${pole.id}`);
      return;
    }

    // Append new landmarks to pole
    await this.prisma.electricPole.update({
      where: { id: pole.id },
      data: { landmarks: [...pole.landmarks, ...uniqueNew] },
    });

    this.logger.log(
      `[Learn] ✅ Added ${uniqueNew.length} new landmark(s) to pole #${pole.id}: ${uniqueNew.join(', ')}`,
    );
  }

  // ── STT Provider Settings ────────────────────────────────────────────────

  async getSttProvider() {
    const setting = await this.prisma.systemSettings.findUnique({
      where: { key: 'stt_provider' },
    });
    return {
      provider: setting?.value ?? 'gemini',
      available_providers: ['gemini', 'groq', 'rapidapi', 'google-speech'],
      updated_at: setting?.updated_at ?? null,
    };
  }

  async setSttProvider(provider: string) {
    const validProviders = ['gemini', 'groq', 'rapidapi', 'google-speech'];
    if (!validProviders.includes(provider)) {
      throw new BadRequestException(
        `Invalid STT provider "${provider}". Must be one of: ${validProviders.join(', ')}`,
      );
    }

    const setting = await this.prisma.systemSettings.upsert({
      where: { key: 'stt_provider' },
      update: { value: provider },
      create: { key: 'stt_provider', value: provider },
    });

    this.logger.log(`✅ STT provider changed to: ${provider}`);
    return {
      provider: setting.value,
      message: `STT provider set to ${provider}`,
      updated_at: setting.updated_at,
    };
  }

  // ── LLM Provider Settings ────────────────────────────────────────────────

  async getLlmProvider() {
    const setting = await this.prisma.systemSettings.findUnique({
      where: { key: 'llm_provider' },
    });
    return {
      provider: setting?.value ?? 'gemini',
      available_providers: ['gemini', 'groq'],
      updated_at: setting?.updated_at ?? null,
    };
  }

  async setLlmProvider(provider: string) {
    const validProviders = ['gemini', 'groq'];
    if (!validProviders.includes(provider)) {
      throw new BadRequestException(
        `Invalid LLM provider "${provider}". Must be one of: ${validProviders.join(', ')}`,
      );
    }

    const setting = await this.prisma.systemSettings.upsert({
      where: { key: 'llm_provider' },
      update: { value: provider },
      create: { key: 'llm_provider', value: provider },
    });

    this.logger.log(`✅ LLM provider changed to: ${provider}`);
    return {
      provider: setting.value,
      message: `LLM provider set to ${provider}`,
      updated_at: setting.updated_at,
    };
  }

  // ── API Key Management ───────────────────────────────────────────────

  async getApiKeys() {
    const rapidapiKey = await this.prisma.systemSettings.findUnique({
      where: { key: 'rapidapi_key' },
    });

    return {
      rapidapi_key: rapidapiKey?.value
        ? `${rapidapiKey.value.slice(0, 8)}...${rapidapiKey.value.slice(-4)}`
        : null,
      rapidapi_key_set: !!rapidapiKey?.value,
      updated_at: rapidapiKey?.updated_at ?? null,
    };
  }

  async setApiKeys(data: { rapidapi_key?: string }) {
    const results: Record<string, any> = {};

    if (data.rapidapi_key) {
      if (data.rapidapi_key.length < 10) {
        throw new BadRequestException('Invalid RapidAPI key — too short');
      }

      const setting = await this.prisma.systemSettings.upsert({
        where: { key: 'rapidapi_key' },
        update: { value: data.rapidapi_key },
        create: { key: 'rapidapi_key', value: data.rapidapi_key },
      });
      results.rapidapi_key = {
        set: true,
        updated_at: setting.updated_at,
      };
      this.logger.log('✅ RapidAPI key updated in system settings');
    }

    return { message: 'API keys updated', ...results };
  }

  // ── Stats ──────────────────────────────────────────────────────────────

  async getDashboardInsights() {
    const now = new Date();
    const currentWeekStart = utcMondayWeekStart(now);
    const lastWeekStart = new Date(currentWeekStart);
    lastWeekStart.setUTCDate(lastWeekStart.getUTCDate() - 7);
    const currentWeekEnd = new Date(currentWeekStart);
    currentWeekEnd.setUTCDate(currentWeekEnd.getUTCDate() + 7);

    const trendOr = [
      { resolved_at: { gte: lastWeekStart, lt: currentWeekEnd } },
      {
        AND: [
          { status: { in: ['resolved_pending_confirmation', 'resolved'] } },
          {
            resolution_image_captured_at: {
              gte: lastWeekStart,
              lt: currentWeekEnd,
            },
          },
        ],
      },
    ];

    const [forTrend, byCat, newRows, resRows, subRows] = await Promise.all([
      this.prisma.complaint.findMany({
        where: { OR: trendOr },
        select: {
          id: true,
          resolved_at: true,
          resolution_image_captured_at: true,
          status: true,
        },
      }),
      this.prisma.complaint.groupBy({
        by: ['complaint_type'],
        where: {},
        _count: { _all: true },
        orderBy: { _count: { complaint_type: 'desc' } },
        take: 8,
      }),
      this.prisma.complaint.findMany({
        orderBy: { created_at: 'desc' },
        take: 5,
        select: {
          id: true,
          complaint_type: true,
          description: true,
          status: true,
          created_at: true,
          resolved_at: true,
          resolution_image_captured_at: true,
        },
      }),
      this.prisma.complaint.findMany({
        where: { resolved_at: { not: null } },
        orderBy: { resolved_at: 'desc' },
        take: 5,
        select: {
          id: true,
          complaint_type: true,
          description: true,
          status: true,
          created_at: true,
          resolved_at: true,
          resolution_image_captured_at: true,
        },
      }),
      this.prisma.complaint.findMany({
        where: {
          status: 'resolved_pending_confirmation',
          resolved_at: null,
          resolution_image_captured_at: { not: null },
        },
        orderBy: { resolution_image_captured_at: 'desc' },
        take: 5,
        select: {
          id: true,
          complaint_type: true,
          description: true,
          status: true,
          created_at: true,
          resolved_at: true,
          resolution_image_captured_at: true,
        },
      }),
    ]);

    const resolution_trend = buildResolutionTrend(forTrend);
    const by_category = byCat.map((r) => ({
      label: r.complaint_type?.trim() || 'Other',
      count: r._count._all,
    }));
    const recent_activity = mergeRecentActivity(
      newRows as ComplaintResolutionFields[],
      resRows as ComplaintResolutionFields[],
      subRows as ComplaintResolutionFields[],
    );

    return { resolution_trend, by_category, recent_activity };
  }

  async getStats() {
    const [
      complaints,
      pending,
      resolved,
      manual_review,
      poles,
      panchayats,
      users,
    ] = await Promise.all([
      this.prisma.complaint.count(),
      this.prisma.complaint.count({ where: { status: 'pending' } }),
      this.prisma.complaint.count({ where: { status: 'resolved' } }),
      this.prisma.complaint.count({ where: { status: 'manual_review' } }),
      this.prisma.electricPole.count(),
      this.prisma.panchayat.count(),
      this.prisma.user.count(),
    ]);
    return {
      total_complaints: complaints,
      pending_complaints: pending,
      resolved_complaints: resolved,
      manual_review_complaints: manual_review,
      total_poles: poles,
      total_panchayats: panchayats,
      total_admins: users,
    };
  }

  async getState() {
    const [stats, phase1Pending, phase1Failed, phase2Pending, phase2Failed] =
      await Promise.all([
        this.getStats(),
        this.prisma.callState.count({ where: { phase1_status: 'pending' } }),
        this.prisma.callState.count({ where: { phase1_status: 'failed' } }),
        this.prisma.callState.count({ where: { phase2_status: 'pending' } }),
        this.prisma.callState.count({ where: { phase2_status: 'failed' } }),
      ]);

    return {
      ...stats,
      call_pipeline: {
        phase1_pending: phase1Pending,
        phase1_failed: phase1Failed,
        phase2_pending: phase2Pending,
        phase2_failed: phase2Failed,
      },
    };
  }

  // ── Private Helpers ────────────────────────────────────────────────────

  private async ensurePanchayatExists(id: number): Promise<void> {
    const exists = await this.prisma.panchayat.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!exists) throw new NotFoundException(`Panchayat #${id} not found`);
  }
}
