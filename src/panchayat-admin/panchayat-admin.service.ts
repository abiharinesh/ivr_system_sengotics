import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { validateComplaintStatus } from '../common/complaint-status';
import {
  buildResolutionTrend,
  mergeRecentActivity,
  utcMondayWeekStart,
  type ComplaintResolutionFields,
} from '../common/dashboard-insights';
import { WhatsAppService } from '../whatsapp/whatsapp.service';
import { PenaltyService } from '../penalty/penalty.service';
import { OrgHierarchyService } from '../core/tenant/org-hierarchy.service';
import { OrgScopedService } from '../core/tenant/org-scoped.service';

@Injectable()
export class PanchayatAdminService extends OrgScopedService {
  private readonly logger = new Logger(PanchayatAdminService.name);
  constructor(
    private prisma: PrismaService,
    private readonly whatsApp: WhatsAppService,
    private readonly penaltyService: PenaltyService,
    hierarchyService: OrgHierarchyService,
  ) {
    super(hierarchyService);
  }

  private async getBranchIdsScope(
    tenantId: string,
    panchayatId: number,
    accessScope: string,
  ): Promise<number[]> {
    if (accessScope === 'child_org_units') {
      return this.hierarchy.getDescendantBranchIds(tenantId, panchayatId);
    }
    return [panchayatId];
  }

  // ── Profile ────────────────────────────────────────────────────────────

  async getMe(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        phone_e164: true,
        user_type: true,
        created_at: true,
        last_login_at: true,
        primary_org_unit_id: true,
        primary_org_unit: true,
        employee: {
          select: {
            id: true,
            employee_code: true,
            service_book_number: true,
            cadre: true,
            designation: true,
            photo_url: true,
            date_of_joining: true,
            qualification: true,
            status: true,
          },
        },
      },
    });
    if (!user) throw new NotFoundException('User not found');

    const pid = user.primary_org_unit_id;
    let stats = {
      wards: 0,
      total_assets: 0,
      resolved_grievances: 0,
      active_field_staff: 0,
    };

    if (pid) {
      const [wardsCount, polesCount, pipelinesCount, resolvedCount, staffCount] = await Promise.all([
        this.prisma.panchayatZone.count({ where: { panchayat_id: pid } }).catch(() => 0),
        this.prisma.electricPole.count({ where: { panchayat_id: pid } }).catch(() => 0),
        this.prisma.waterPipeline.count({ where: { panchayat_id: pid } }).catch(() => 0),
        this.prisma.complaint.count({ where: { panchayat_id: pid, status: 'resolved' } }).catch(() => 0),
        this.prisma.user.count({
          where: { primary_org_unit_id: pid, role: { in: ['electrician', 'plumber', 'agent'] }, is_active: true },
        }).catch(() => 0),
      ]);

      const declaredWards = user.primary_org_unit?.ward_count || 0;
      stats = {
        wards: declaredWards > 0 ? declaredWards : Math.max(wardsCount, 12),
        total_assets: polesCount + pipelinesCount,
        resolved_grievances: resolvedCount,
        active_field_staff: staffCount,
      };
    }

    return {
      ...user,
      stats,
    };
  }

  async updateProfile(
    userId: number,
    data: {
      officer_name?: string;
      email?: string;
      phone?: string;
      panchayat_name?: string;
      photo_url?: string;
      // Branding & panchayat config fields
      logo_url?: string;
      secondary_logo_url?: string;
      favicon_url?: string;
      software_name_ta?: string;
      software_name_en?: string;
      software_tagline_ta?: string;
      software_tagline_en?: string;
      primary_color?: string;
      secondary_color?: string;
      welcome_audio_url?: string;
      contact_phone?: string;
      contact_email?: string;
      address?: string;
      ivr_number?: string;
      district?: string;
      taluk?: string;
      branch_code?: string;
    },
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, primary_org_unit_id: true, email: true },
    });
    if (!user) throw new NotFoundException('User not found');

    if (data.email || data.phone) {
      await this.prisma.user.update({
        where: { id: userId },
        data: {
          ...(data.email && { email: data.email.trim() }),
          ...(data.phone && { phone_e164: data.phone.trim() }),
        },
      });
    }

    if (data.photo_url !== undefined) {
      const emp = await this.prisma.employee.findFirst({ where: { user_id: userId } });
      if (emp) {
        await this.prisma.employee.update({
          where: { id: emp.id },
          data: { photo_url: data.photo_url },
        });
      }
    }

    // Update panchayat-level fields (name, branding, contact, etc.)
    if (user.primary_org_unit_id) {
      const panchayatUpdate: Record<string, any> = {};
      if (data.panchayat_name) panchayatUpdate.name = data.panchayat_name.trim();
      if (data.logo_url !== undefined) panchayatUpdate.logo_url = data.logo_url || null;
      if (data.secondary_logo_url !== undefined) panchayatUpdate.secondary_logo_url = data.secondary_logo_url || null;
      if (data.favicon_url !== undefined) panchayatUpdate.favicon_url = data.favicon_url || null;
      if (data.software_name_ta !== undefined) panchayatUpdate.software_name_ta = data.software_name_ta;
      if (data.software_name_en !== undefined) panchayatUpdate.software_name_en = data.software_name_en;
      if (data.software_tagline_ta !== undefined) panchayatUpdate.software_tagline_ta = data.software_tagline_ta;
      if (data.software_tagline_en !== undefined) panchayatUpdate.software_tagline_en = data.software_tagline_en;
      if (data.primary_color !== undefined) panchayatUpdate.primary_color = data.primary_color;
      if (data.secondary_color !== undefined) panchayatUpdate.secondary_color = data.secondary_color;
      if (data.welcome_audio_url !== undefined) panchayatUpdate.welcome_audio_url = data.welcome_audio_url || null;
      if (data.contact_phone !== undefined) panchayatUpdate.contact_phone = data.contact_phone || null;
      if (data.contact_email !== undefined) panchayatUpdate.contact_email = data.contact_email || null;
      if (data.address !== undefined) panchayatUpdate.address = data.address || null;
      if (data.ivr_number !== undefined) panchayatUpdate.ivr_number = data.ivr_number || null;
      if (data.district !== undefined) panchayatUpdate.district = data.district || null;
      if (data.taluk !== undefined) panchayatUpdate.taluk = data.taluk || null;
      if (data.branch_code !== undefined) panchayatUpdate.branch_code = data.branch_code || null;

      if (Object.keys(panchayatUpdate).length > 0) {
        await this.prisma.orgUnit.update({
          where: { id: user.primary_org_unit_id },
          data: panchayatUpdate,
        });
      }
    }

    return this.getMe(userId);
  }

  async getFirstPanchayatId(): Promise<number | null> {
    const p = await this.prisma.orgUnit.findFirst({ select: { id: true } });
    return p ? p.id : null;
  }

  // ── Branding ────────────────────────────────────────────────────────────

  async getBranding(panchayatId: number) {
    const panchayat = await this.prisma.orgUnit.findUnique({
      where: { id: panchayatId },
      select: {
        id: true,
        name: true,
        branch_type: true,
        branch_code: true,
        district: true,
        taluk: true,
        address: true,
        contact_phone: true,
        contact_email: true,
        ivr_number: true,
        ward_count: true,
        logo_url: true,
        secondary_logo_url: true,
        favicon_url: true,
        software_name_ta: true,
        software_name_en: true,
        software_tagline_ta: true,
        software_tagline_en: true,
        primary_color: true,
        secondary_color: true,
        welcome_audio_url: true,
      },
    });
    if (!panchayat) throw new NotFoundException(`Panchayat #${panchayatId} not found`);
    return panchayat;
  }

  // ── Pole Management (scoped to their panchayat) ────────────────────────

  async createPole(
    panchayatId: number,
    data: {
      pole_number?: string;
      keypad_id?: string;
      latitude?: number;
      longitude?: number;
      landmarks?: string[];
    },
  ) {
    const pole = await this.prisma.electricPole.create({
      data: {
        pole_number: data.pole_number,
        keypad_id: data.keypad_id,
        latitude: data.latitude,
        longitude: data.longitude,
        landmarks: data.landmarks ?? [],
        panchayat_id: panchayatId,
      },
    });

    // Set PostGIS geometry if coordinates are provided
    if (data.latitude && data.longitude) {
      await this.prisma.$executeRaw`
                UPDATE electric_poles
                SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)
                WHERE id = ${pole.id}
            `;
    }
    return pole;
  }

  async listPoles(panchayatId: number, tenantId = 'default', accessScope = 'own_org_unit') {
    const branchIds = await this.getBranchIdsScope(tenantId, panchayatId, accessScope);
    return this.prisma.electricPole.findMany({
      where: { panchayat_id: { in: branchIds } },
      include: {
        _count: { select: { complaints: true } },
        complaints: { select: { status: true } },
      },
    });
  }

  async updatePole(
    panchayatId: number,
    poleId: number,
    data: {
      pole_number?: string;
      keypad_id?: string;
      latitude?: number;
      longitude?: number;
      landmarks?: string[];
    },
  ) {
    const pole = await this.prisma.electricPole.findUnique({
      where: { id: poleId },
    });

    if (!pole) throw new NotFoundException(`Pole #${poleId} not found`);
    if (pole.panchayat_id !== panchayatId)
      throw new ForbiddenException(
        'Access denied — pole belongs to another panchayat',
      );

    const updated = await this.prisma.electricPole.update({
      where: { id: poleId },
      data,
    });

    // Update PostGIS geometry if coordinates changed
    if (data.latitude && data.longitude) {
      await this.prisma.$executeRaw`
                UPDATE electric_poles
                SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)
                WHERE id = ${poleId}
            `;
    }

    return updated;
  }

  async deletePole(panchayatId: number, poleId: number) {
    const pole = await this.prisma.electricPole.findUnique({
      where: { id: poleId },
    });

    if (!pole) throw new NotFoundException(`Pole #${poleId} not found`);
    if (pole.panchayat_id !== panchayatId)
      throw new ForbiddenException(
        'Access denied — pole belongs to another panchayat',
      );

    await this.prisma.electricPole.delete({ where: { id: poleId } });
    return { success: true };
  }

  // ── Complaint Management (scoped to their panchayat) ──────────────────

  async listComplaints(panchayatId: number, tenantId = 'default', accessScope = 'own_org_unit', status?: string) {
    const branchIds = await this.getBranchIdsScope(tenantId, panchayatId, accessScope);
    return this.prisma.complaint.findMany({
      where: { panchayat_id: { in: branchIds }, ...(status && { status }) },
      include: {
        pole: true,
        voice_call: true,
        pipeline: true,
        tank: true,
        assigned_electrician: { select: { id: true, email: true } },
        assigned_plumber: { select: { id: true, email: true } },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  async createComplaint(
    panchayatId: number,
    data: {
      pole_id: number;
      complaint_type?: string;
      description?: string;
      urgency_level?: string;
      caller_language?: string;
      caller_emotion?: string;
    },
  ) {
    const pole = await this.prisma.electricPole.findUnique({
      where: { id: data.pole_id },
    });
    if (!pole) throw new NotFoundException(`Pole #${data.pole_id} not found`);
    if (pole.panchayat_id !== panchayatId) {
      throw new ForbiddenException(
        'Access denied — pole belongs to another panchayat',
      );
    }

    const complaint = await this.prisma.complaint.create({
      data: {
        pole_id: data.pole_id,
        panchayat_id: panchayatId,
        complaint_type: data.complaint_type?.trim() || 'manual_reported',
        description: data.description?.trim() || null,
        urgency_level: data.urgency_level?.trim() || null,
        caller_language: data.caller_language?.trim() || null,
        caller_emotion: data.caller_emotion?.trim() || null,
        status: 'pending',
      },
      include: {
        pole: true,
        assigned_electrician: { select: { id: true, email: true } },
      },
    });

    return this.autoAssignComplaintRoundRobin(panchayatId, complaint.id);
  }

  async updateComplaintStatus(
    panchayatId: number,
    complaintId: number,
    status: string,
  ) {
    validateComplaintStatus(status);

    const complaint = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
    });

    if (!complaint)
      throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (complaint.panchayat_id !== panchayatId)
      throw new ForbiddenException(
        'Access denied — complaint belongs to another panchayat',
      );

    const updated = await this.prisma.complaint.update({
      where: { id: complaintId },
      data: {
        status,
        ...(status === 'resolved' ? { resolved_at: new Date() } : {}),
      },
    });

    if (status === 'resolved') {
      try {
        await this.penaltyService.handleComplaintResolution(complaintId);
      } catch (err) {
        this.logger.error(`Error processing resolution penalty for complaint #${complaintId}: ${(err as Error).message}`);
      }
    }

    return updated;
  }

  /**
   * Assign an open complaint to an electrician in the same panchayat.
   */
  async assignElectrician(
    panchayatId: number,
    complaintId: number,
    electricianUserId: number,
  ) {
    const sparky = await this.prisma.user.findUnique({
      where: { id: electricianUserId },
      select: { id: true, role: true, primary_org_unit_id: true, phone_e164: true },
    });
    if (!sparky || sparky.role !== 'electrician') {
      throw new BadRequestException('User is not an electrician');
    }
    if (sparky.primary_org_unit_id !== panchayatId) {
      throw new ForbiddenException('Electrician belongs to another panchayat');
    }

    const complaint = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
    });
    if (!complaint)
      throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (complaint.panchayat_id !== panchayatId) {
      throw new ForbiddenException(
        'Access denied — complaint belongs to another panchayat',
      );
    }
    if (!['pending', 'reassign_required'].includes(complaint.status)) {
      throw new BadRequestException(
        `Can only assign complaints in status pending or reassign_required. Current: ${complaint.status}`,
      );
    }

    const updated = await this.prisma.complaint.update({
      where: { id: complaintId },
      data: {
        assigned_electrician_id: electricianUserId,
        assigned_at: new Date(),
        status: 'assigned',
      },
      include: {
        pole: true,
        assigned_electrician: {
          select: { id: true, email: true, phone_e164: true },
        },
      },
    });

    if (sparky.phone_e164) {
      const msg = `Complaint #${complaintId} is assigned to you. Use the field app, or reply DONE ${complaintId} when the work is finished.`;
      void this.whatsApp
        .sendText(sparky.phone_e164, msg)
        .catch((err) =>
          this.logger.warn(`WhatsApp notify failed: ${err?.message ?? err}`),
        );
    }

    return updated;
  }

  async autoAssignComplaintRoundRobin(
    panchayatId: number,
    complaintId: number,
  ) {
    const complaint = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
      include: {
        pole: true,
        assigned_electrician: { select: { id: true, email: true } },
      },
    });
    if (!complaint)
      throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (complaint.panchayat_id !== panchayatId) {
      throw new ForbiddenException(
        'Access denied — complaint belongs to another panchayat',
      );
    }
    if (!['pending', 'reassign_required'].includes(complaint.status)) {
      return complaint;
    }

    const electricians = await this.prisma.user.findMany({
      where: { role: 'electrician', primary_org_unit_id: panchayatId },
      select: { id: true },
      orderBy: { id: 'asc' },
    });
    if (electricians.length === 0) {
      this.logger.warn(
        `No electricians available for panchayat #${panchayatId}`,
      );
      return complaint;
    }

    const latestAssignments = await this.prisma.complaint.findMany({
      where: {
        panchayat_id: panchayatId,
        assigned_electrician_id: { in: electricians.map((e) => e.id) },
        assigned_at: { not: null },
      },
      select: { assigned_electrician_id: true, assigned_at: true },
      orderBy: [{ assigned_at: 'desc' }],
    });

    const lastAssignedByElectrician = new Map<number, Date | null>();
    for (const row of latestAssignments) {
      const electricianId = row.assigned_electrician_id;
      if (electricianId == null) continue;
      if (!lastAssignedByElectrician.has(electricianId)) {
        lastAssignedByElectrician.set(electricianId, row.assigned_at);
      }
    }

    electricians.sort((a, b) => {
      const aLast = lastAssignedByElectrician.get(a.id) ?? null;
      const bLast = lastAssignedByElectrician.get(b.id) ?? null;
      if (aLast == null && bLast == null) return a.id - b.id;
      if (aLast == null) return -1;
      if (bLast == null) return 1;
      const cmp = aLast.getTime() - bLast.getTime();
      if (cmp !== 0) return cmp;
      return a.id - b.id;
    });

    const selected = electricians[0];
    try {
      return await this.assignElectrician(
        panchayatId,
        complaintId,
        selected.id,
      );
    } catch (err: any) {
      this.logger.warn(
        `Round-robin auto assignment failed for complaint #${complaintId}: ${err?.message ?? err}`,
      );
      return complaint;
    }
  }

  /**
   * Resolve a manual_review complaint by assigning it to a pole.
   * Scoped: pole must belong to this admin's panchayat.
   * Auto-learns: saves the caller's landmark phrase to the pole.
   */
  async resolveComplaint(
    panchayatId: number,
    complaintId: number,
    poleId: number,
  ) {
    // 1. Validate complaint
    const complaint = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
      include: { voice_call: true },
    });
    if (!complaint)
      throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (complaint.panchayat_id !== panchayatId)
      throw new ForbiddenException(
        'Access denied — complaint belongs to another panchayat',
      );
    if (complaint.status !== 'manual_review') {
      throw new BadRequestException(
        `Can only resolve complaints with status 'manual_review'. Current status: '${complaint.status}'`,
      );
    }

    // 2. Validate pole belongs to this panchayat
    const pole = await this.prisma.electricPole.findUnique({
      where: { id: poleId },
    });
    if (!pole) throw new NotFoundException(`Pole #${poleId} not found`);
    if (pole.panchayat_id !== panchayatId)
      throw new ForbiddenException(
        'Access denied — pole belongs to another panchayat',
      );

    // 3. Assign pole and update status
    const updated = await this.prisma.complaint.update({
      where: { id: complaintId },
      data: { pole_id: poleId, status: 'pending' },
      include: { pole: true },
    });

    // 4. Auto-learn landmark
    await this.learnLandmark(complaint, pole);

    this.logger.log(`✅ Complaint #${complaintId} resolved → pole #${poleId}`);
    return this.autoAssignComplaintRoundRobin(panchayatId, complaintId);
  }

  /** Learn new landmark phrases from resolved voice complaints. */
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

    const existingLower = pole.landmarks.map((l) => l.toLowerCase());
    const uniqueNew = newLandmarks.filter(
      (l) => l.length > 0 && !existingLower.includes(l.toLowerCase()),
    );

    if (uniqueNew.length === 0) return;

    await this.prisma.electricPole.update({
      where: { id: pole.id },
      data: { landmarks: [...pole.landmarks, ...uniqueNew] },
    });

    this.logger.log(
      `[Learn] ✅ Added ${uniqueNew.length} new landmark(s) to pole #${pole.id}: ${uniqueNew.join(', ')}`,
    );
  }

  // ── Stats (scoped to their panchayat) ─────────────────────────────────

  async getDashboardInsights(panchayatId: number, tenantId = 'default', accessScope = 'own_org_unit') {
    const now = new Date();
    const currentWeekStart = utcMondayWeekStart(now);
    const lastWeekStart = new Date(currentWeekStart);
    lastWeekStart.setUTCDate(lastWeekStart.getUTCDate() - 7);
    const currentWeekEnd = new Date(currentWeekStart);
    currentWeekEnd.setUTCDate(currentWeekEnd.getUTCDate() + 7);

    const branchIds = await this.getBranchIdsScope(tenantId, panchayatId, accessScope);
    const scope = { panchayat_id: { in: branchIds } };
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
        where: { ...scope, OR: trendOr },
        select: {
          id: true,
          resolved_at: true,
          resolution_image_captured_at: true,
          status: true,
        },
      }),
      this.prisma.complaint.groupBy({
        by: ['complaint_type'],
        where: scope,
        _count: { _all: true },
        orderBy: { _count: { complaint_type: 'desc' } },
        take: 8,
      }),
      this.prisma.complaint.findMany({
        where: scope,
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
        where: { ...scope, resolved_at: { not: null } },
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
          ...scope,
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

  async getStats(panchayatId: number, tenantId = 'default', accessScope = 'own_org_unit') {
    const branchIds = await this.getBranchIdsScope(tenantId, panchayatId, accessScope);
    const [total, pending, resolved, manual_review, poles] = await Promise.all([
      this.prisma.complaint.count({ where: { panchayat_id: { in: branchIds } } }),
      this.prisma.complaint.count({
        where: { panchayat_id: { in: branchIds }, status: 'pending' },
      }),
      this.prisma.complaint.count({
        where: { panchayat_id: { in: branchIds }, status: 'resolved' },
      }),
      this.prisma.complaint.count({
        where: { panchayat_id: { in: branchIds }, status: 'manual_review' },
      }),
      this.prisma.electricPole.count({ where: { panchayat_id: { in: branchIds } } }),
    ]);
    return {
      total_complaints: total,
      pending_complaints: pending,
      resolved_complaints: resolved,
      manual_review_complaints: manual_review,
      total_poles: poles,
    };
  }
}
