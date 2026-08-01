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

  // ── Branch Software Name Presets ───────────────────────────────────────
  private static readonly BRANCH_NAME_PRESETS: Record<
    string,
    { ta: string; en: string }
  > = {
    VILLAGE_PANCHAYAT: { ta: 'கிராம ஊராட்சி குரல்', en: 'Grama Ooratchi Kural' },
    PANCHAYAT_UNION: { ta: 'ஊராட்சி ஒன்றிய குரல்', en: 'Ooratchi Union Kural' },
    DISTRICT_PANCHAYAT: { ta: 'மாவட்ட ஊராட்சி குரல்', en: 'District Ooratchi Kural' },
    TOWN_PANCHAYAT: { ta: 'பேரூராட்சி குரல்', en: 'Peeraatchi Kural' },
    MUNICIPALITY: { ta: 'நகராட்சி குரல்', en: 'Nagaraatchi Kural' },
    MUNICIPAL_CORPORATION: { ta: 'மாநகராட்சி குரல்', en: 'Maanagaraatchi Kural' },
  };

  private resolveBranchPreset(branchType: string) {
    return SuperAdminService.BRANCH_NAME_PRESETS[branchType] ?? {
      ta: 'ஊராட்சி குரல்',
      en: 'Ooratchi Kural',
    };
  }

  async createPanchayat(data: {
    name: string;
    ivr_number?: string;
    center_lat?: number;
    center_lng?: number;
    tenant_id?: string;
    branch_type?: any;
    branch_status?: any;
    branch_code?: string;
    parent_branch_id?: number;
    district?: string;
    taluk?: string;
    block?: string;
    village?: string;
    ward_count?: number;
    gis_boundary?: any;
    area_sq_km?: number;
    contact_phone?: string;
    contact_email?: string;
    address?: string;
    logo_url?: string;
    software_name_ta?: string;
    software_name_en?: string;
    software_tagline_ta?: string;
    software_tagline_en?: string;
    primary_color?: string;
    secondary_color?: string;
  }) {
    if (data.parent_branch_id) {
      await this.ensurePanchayatExists(data.parent_branch_id);
    }

    // Auto-generate software names from branch_type preset if not explicitly provided
    const branchType = data.branch_type ?? 'VILLAGE_PANCHAYAT';
    const preset = this.resolveBranchPreset(branchType);

    const branch = await this.prisma.orgUnit.create({
      data: {
        name: data.name,
        ivr_number: data.ivr_number ?? null,
        center_lat: data.center_lat ?? null,
        center_lng: data.center_lng ?? null,
        tenant_id: data.tenant_id ?? 'default',
        branch_type: branchType,
        branch_status: data.branch_status ?? 'ACTIVE',
        branch_code: data.branch_code ?? null,
        parent_org_unit_id: data.parent_branch_id ?? null,
        district: data.district ?? null,
        taluk: data.taluk ?? null,
        block: data.block ?? null,
        village: data.village ?? null,
        ward_count: data.ward_count ?? null,
        gis_boundary: data.gis_boundary ?? null,
        area_sq_km: data.area_sq_km ?? null,
        contact_phone: data.contact_phone ?? null,
        contact_email: data.contact_email ?? null,
        address: data.address ?? null,
        logo_url: data.logo_url ?? null,
        software_name_ta: data.software_name_ta ?? preset.ta,
        software_name_en: data.software_name_en ?? preset.en,
        software_tagline_ta: data.software_tagline_ta ?? 'குடிமக்கள் சேவை மையம்',
        software_tagline_en: data.software_tagline_en ?? 'Citizen Service Portal',
        primary_color: data.primary_color ?? '#1E3A8A',
        secondary_color: data.secondary_color ?? '#0EA5E9',
      },
    });

    await this.prisma.branchFeatureConfig.create({
      data: { org_unit_id: branch.id },
    });

    await this.prisma.branchLifecycleEvent.create({
      data: {
        tenant_id: branch.tenant_id,
        branch_id: branch.id,
        event_type: 'created',
        to_status: branch.branch_status,
        effective_date: new Date(),
        details: { reason: 'Initial creation' } as any,
      },
    });

    return branch;
  }

  async createUnifiedPanchayat(data: {
    name: string;
    branch_code?: string;
    branch_type?: any;
    district?: string;
    taluk?: string;
    address?: string;
    contact_phone?: string;
    contact_email?: string;
    ivr_number?: string;
    software_name_ta?: string;
    software_name_en?: string;
    software_tagline_ta?: string;
    software_tagline_en?: string;
    logo_url?: string;
    secondary_logo_url?: string;
    primary_color?: string;
    secondary_color?: string;
    admin_name?: string;
    admin_email?: string;
    admin_password?: string;
    admin_phone?: string;
  }) {
    const branch = await this.createPanchayat({
      name: data.name,
      branch_code: data.branch_code,
      branch_type: data.branch_type ?? 'VILLAGE_PANCHAYAT',
      district: data.district,
      taluk: data.taluk,
      address: data.address,
      contact_phone: data.contact_phone,
      contact_email: data.contact_email,
      ivr_number: data.ivr_number,
      software_name_ta: data.software_name_ta,
      software_name_en: data.software_name_en,
      software_tagline_ta: data.software_tagline_ta,
      software_tagline_en: data.software_tagline_en,
      logo_url: data.logo_url,
      primary_color: data.primary_color,
      secondary_color: data.secondary_color,
    });

    if (data.secondary_logo_url) {
      await this.prisma.orgUnit.update({
        where: { id: branch.id },
        data: { secondary_logo_url: data.secondary_logo_url },
      });
    }

    let adminUser: any = null;
    if (data.admin_email) {
      const existingUser = await this.prisma.user.findFirst({
        where: { email: data.admin_email.trim() },
      });
      if (existingUser) {
        throw new BadRequestException(`User with email "${data.admin_email}" already exists`);
      }

      const passwordHash = await bcrypt.hash(data.admin_password || 'Password@123', 10);
      adminUser = await this.prisma.user.create({
        data: {
          email: data.admin_email.trim(),
          password_hash: passwordHash,
          role: 'panchayat_admin',
          user_type: 'employee',
          primary_org_unit_id: branch.id,
          phone_e164: data.admin_phone?.trim() ?? null,
          is_active: true,
          is_verified: true,
        },
      });

      await this.prisma.employee.create({
        data: {
          tenant_id: branch.tenant_id || 'default',
          user_id: adminUser.id,
          employee_code: `EMP-PA-${branch.id}-${Date.now().toString().slice(-4)}`,
          service_book_number: `SB-PA-${branch.id}`,
          org_unit_id: branch.id,
          designation: 'Panchayat Administrative Officer',
          status: 'active',
        },
      }).catch(() => {});
    }

    return {
      branch,
      admin_user: adminUser
        ? {
            id: adminUser.id,
            email: adminUser.email,
            role: adminUser.role,
            phone_e164: adminUser.phone_e164,
          }
        : null,
    };
  }

  async updatePanchayat(
    id: number,
    data: any,
  ) {
    const existing = await this.ensurePanchayatExists(id);
    if (data.parent_branch_id) {
      await this.ensurePanchayatExists(data.parent_branch_id);
    }
    const updated = await this.prisma.orgUnit.update({ where: { id }, data: data as any });

    if (data.branch_status && data.branch_status !== existing.branch_status) {
      await this.prisma.branchLifecycleEvent.create({
        data: {
          tenant_id: updated.tenant_id,
          branch_id: updated.id,
          event_type: 'status_changed',
          from_status: existing.branch_status,
          to_status: updated.branch_status,
          effective_date: new Date(),
          details: { reason: 'Admin status update' } as any,
        },
      });
    }

    return updated;
  }

  async deletePanchayat(id: number) {
    await this.ensurePanchayatExists(id);
    await this.prisma.orgUnit.update({
      where: { id },
      data: { is_deleted: true, deleted_at: new Date(), is_active: false },
    });
    return { success: true };
  }

  async listPanchayats(tenantId = 'default') {
    return this.prisma.orgUnit.findMany({
      where: { tenant_id: tenantId, is_deleted: false },
      include: {
        parent_org_unit: {
          select: { id: true, name: true, branch_type: true },
        },
        _count: {
          select: { electric_poles: true, complaints: true, users: true },
        },
      },
    });
  }

  // ── Branch Feature Config Matrix ────────────────────────────────────────

  /** All valid feature toggle keys that can be set. */
  private static readonly VALID_FEATURE_KEYS = new Set([
    'street_light_mgmt', 'water_supply_mgmt', 'complaint_mgmt', 'tender_mgmt',
    'certificate_mgmt', 'market_mgmt', 'asset_booking', 'ad_campaign',
    'penalty_mgmt', 'ivr_system', 'zone_management',
    'solid_waste_mgmt', 'drainage_mgmt', 'road_mgmt', 'parks_mgmt',
    'public_health', 'building_permit', 'birth_death_reg',
    'vehicle_fleet_mgmt', 'cemetery_mgmt', 'encroachment_mgmt',
  ]);

  async getFeatureConfig(branchId: number) {
    await this.ensurePanchayatExists(branchId);
    let config = await this.prisma.branchFeatureConfig.findUnique({
      where: { org_unit_id: branchId },
    });
    if (!config) {
      config = await this.prisma.branchFeatureConfig.create({
        data: { org_unit_id: branchId },
      });
    }
    return config;
  }

  async updateFeatureConfig(branchId: number, data: any) {
    await this.ensurePanchayatExists(branchId);

    // Strip non-feature fields
    delete data.id;
    delete data.panchayat_id;
    delete data.org_unit_id;
    delete data.created_at;
    delete data.updated_at;

    // Validate only known feature keys are being set
    const cleanData: Record<string, boolean> = {};
    for (const [key, value] of Object.entries(data)) {
      if (SuperAdminService.VALID_FEATURE_KEYS.has(key)) {
        cleanData[key] = Boolean(value);
      } else {
        this.logger.warn(`Ignoring unknown feature key: "${key}"`);
      }
    }

    if (Object.keys(cleanData).length === 0) {
      throw new BadRequestException(
        'No valid feature toggles provided. Valid keys: ' +
        Array.from(SuperAdminService.VALID_FEATURE_KEYS).join(', '),
      );
    }

    // A branch may only enable a module its tenant's subscription ceiling allows.
    const branch = await this.prisma.orgUnit.findUnique({
      where: { id: branchId },
      select: { tenant_id: true },
    });
    const ceiling = branch
      ? await this.prisma.tenantFeatureConfig.findUnique({ where: { tenant_id: branch.tenant_id } })
      : null;
    if (ceiling) {
      for (const [key, value] of Object.entries(cleanData)) {
        if (value === true && (ceiling as any)[key] === false) {
          throw new BadRequestException(
            `Cannot enable "${key}" — disabled at the tenant subscription level`,
          );
        }
      }
    }

    // Auto-create config if it doesn't exist
    const existing = await this.prisma.branchFeatureConfig.findUnique({
      where: { org_unit_id: branchId },
    });
    if (!existing) {
      return this.prisma.branchFeatureConfig.create({
        data: { org_unit_id: branchId, ...cleanData },
      });
    }

    return this.prisma.branchFeatureConfig.update({
      where: { org_unit_id: branchId },
      data: cleanData,
    });
  }

  /** Apply a feature template to multiple branches at once. */
  async bulkUpdateFeatureConfig(branchIds: number[], data: Record<string, boolean>) {
    const cleanData: Record<string, boolean> = {};
    for (const [key, value] of Object.entries(data)) {
      if (SuperAdminService.VALID_FEATURE_KEYS.has(key)) {
        cleanData[key] = Boolean(value);
      }
    }

    const results: Array<{ branch_id: number; success: boolean; error?: string }> = [];

    for (const branchId of branchIds) {
      try {
        await this.updateFeatureConfig(branchId, { ...cleanData });
        results.push({ branch_id: branchId, success: true });
      } catch (err) {
        results.push({
          branch_id: branchId,
          success: false,
          error: (err as Error).message,
        });
      }
    }

    return { updated: results.filter(r => r.success).length, results };
  }

  // ── Branch Lifecycle Events ──────────────────────────────────────────────

  async getLifecycleEvents(tenantId: string, branchId: number) {
    await this.ensurePanchayatExists(branchId);
    return this.prisma.branchLifecycleEvent.findMany({
      where: { tenant_id: tenantId, branch_id: branchId },
      orderBy: { created_at: 'desc' },
    });
  }

  async getPanchayat(id: number) {
    const panchayat = await this.prisma.orgUnit.findUnique({
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

    const existing = await this.prisma.user.findFirst({
      where: { email: data.email },
    });
    if (existing) throw new ForbiddenException('Email already in use');

    const password_hash = await bcrypt.hash(data.password, 10);
    return this.prisma.user.create({
      data: {
        email: data.email,
        password_hash,
        role: 'panchayat_admin',
        primary_org_unit_id: data.panchayat_id,
      },
      select: {
        id: true,
        email: true,
        role: true,
        primary_org_unit_id: true,
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
    const existing = await this.prisma.user.findFirst({
      where: { email: data.email },
    });
    if (existing) throw new ForbiddenException('Email already in use');
    const password_hash = await bcrypt.hash(data.password, 10);
    return this.prisma.user.create({
      data: {
        email: data.email,
        password_hash,
        role: data.role,
        primary_org_unit_id: data.panchayat_id,
        phone_e164: data.phone_e164?.trim() || null,
      },
      select: {
        id: true,
        email: true,
        role: true,
        primary_org_unit_id: true,
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
        primary_org_unit_id: true,
        created_at: true,
        primary_org_unit: { select: { name: true } },
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
      this.prisma.orgUnit.count(),
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

  // ── RBAC: Permissions ──────────────────────────────────────────────────

  async listPermissions() {
    const perms = await this.prisma.permission.findMany({
      orderBy: [{ module: 'asc' }, { action: 'asc' }],
    });
    // Group by module for the frontend
    const grouped: Record<string, typeof perms> = {};
    for (const p of perms) {
      if (!grouped[p.module]) grouped[p.module] = [];
      grouped[p.module].push(p);
    }
    return { permissions: perms, grouped };
  }

  // ── RBAC: Permission Groups ───────────────────────────────────────────

  async listPermissionGroups(tenantId = 'default') {
    return this.prisma.permissionGroup.findMany({
      where: { tenant_id: tenantId },
      orderBy: { name: 'asc' },
    });
  }

  async createPermissionGroup(data: {
    name: string;
    permissions: string[];
    tenant_id?: string;
  }) {
    if (!data.name?.trim()) {
      throw new BadRequestException('Permission group name is required');
    }
    return this.prisma.permissionGroup.create({
      data: {
        tenant_id: data.tenant_id ?? 'default',
        name: data.name.trim(),
        permissions: data.permissions ?? [],
      },
    });
  }

  async updatePermissionGroup(
    id: number,
    data: { name?: string; permissions?: string[] },
  ) {
    const existing = await this.prisma.permissionGroup.findUnique({
      where: { id },
    });
    if (!existing)
      throw new NotFoundException(`PermissionGroup #${id} not found`);

    return this.prisma.permissionGroup.update({
      where: { id },
      data: {
        ...(data.name && { name: data.name.trim() }),
        ...(data.permissions && { permissions: data.permissions }),
      },
    });
  }

  async deletePermissionGroup(id: number) {
    const existing = await this.prisma.permissionGroup.findUnique({
      where: { id },
    });
    if (!existing)
      throw new NotFoundException(`PermissionGroup #${id} not found`);

    await this.prisma.permissionGroup.delete({ where: { id } });
    return { success: true };
  }

  // ── RBAC: Roles ───────────────────────────────────────────────────────

  async listRoles(tenantId = 'default', branchId?: number) {
    return this.prisma.role.findMany({
      where: {
        tenant_id: tenantId,
        ...(branchId != null && { org_unit_id: branchId }),
      },
      include: {
        org_unit: { select: { id: true, name: true } },
      },
      orderBy: [{ hierarchy_level: 'asc' }, { name: 'asc' }],
    });
  }

  async createRole(data: {
    name: string;
    display_name: string;
    display_name_ta?: string;
    department?: string;
    hierarchy_level?: number;
    permission_group_id?: number;
    inherits_from_role_id?: number;
    can_approve?: boolean;
    branch_id?: number;
    tenant_id?: string;
  }) {
    if (!data.name?.trim()) {
      throw new BadRequestException('Role name is required');
    }
    if (!data.display_name?.trim()) {
      throw new BadRequestException('Display name is required');
    }
    if (data.branch_id) {
      await this.ensurePanchayatExists(data.branch_id);
    }
    return this.prisma.role.create({
      data: {
        tenant_id: data.tenant_id ?? 'default',
        name: data.name.trim().toLowerCase().replace(/\s+/g, '_'),
        display_name: data.display_name.trim(),
        display_name_ta: data.display_name_ta ?? null,
        department: data.department ?? null,
        hierarchy_level: data.hierarchy_level ?? 5,
        permission_group_id: data.permission_group_id ?? null,
        inherits_from_role_id: data.inherits_from_role_id ?? null,
        can_approve: data.can_approve ?? false,
        org_unit_id: data.branch_id ?? null,
      },
      include: {
        org_unit: { select: { id: true, name: true } },
      },
    });
  }

  async updateRole(
    id: number,
    data: {
      display_name?: string;
      display_name_ta?: string;
      department?: string;
      hierarchy_level?: number;
      permission_group_id?: number;
      inherits_from_role_id?: number;
      can_approve?: boolean;
      is_active?: boolean;
    },
  ) {
    const existing = await this.prisma.role.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException(`Role #${id} not found`);

    return this.prisma.role.update({
      where: { id },
      data: data as any,
      include: {
        org_unit: { select: { id: true, name: true } },
      },
    });
  }

  async deleteRole(id: number) {
    const existing = await this.prisma.role.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException(`Role #${id} not found`);
    if (existing.is_system) {
      throw new ForbiddenException('System roles cannot be deleted');
    }
    await this.prisma.role.delete({ where: { id } });
    return { success: true };
  }

  // ── RBAC: User Role Assignments ───────────────────────────────────────

  async listUserRoles(userId: number) {
    return this.prisma.userRole.findMany({
      where: { user_id: userId },
      include: {
        user: { select: { id: true, email: true, role: true } },
      },
    });
  }

  async assignUserRole(data: {
    user_id: number;
    role_id: number;
    branch_id: number;
    is_temporary?: boolean;
    valid_until?: string;
    granted_by?: number;
  }) {
    // Validate user exists
    const user = await this.prisma.user.findUnique({
      where: { id: data.user_id },
    });
    if (!user) throw new NotFoundException(`User #${data.user_id} not found`);

    // Validate role exists
    const role = await this.prisma.role.findUnique({
      where: { id: data.role_id },
    });
    if (!role) throw new NotFoundException(`Role #${data.role_id} not found`);

    // Validate branch exists
    await this.ensurePanchayatExists(data.branch_id);

    // Check for duplicate
    const existing = await this.prisma.userRole.findFirst({
      where: {
        user_id: data.user_id,
        role_id: data.role_id,
        org_unit_id: data.branch_id,
        department_id: null,
      },
    });
    if (existing) {
      throw new BadRequestException(
        'This user already has this role at the specified branch',
      );
    }

    return this.prisma.userRole.create({
      data: {
        user_id: data.user_id,
        role_id: data.role_id,
        org_unit_id: data.branch_id,
        is_temporary: data.is_temporary ?? false,
        valid_until: data.valid_until ? new Date(data.valid_until) : null,
        granted_by: data.granted_by ?? null,
      },
    });
  }

  async revokeUserRole(userRoleId: number) {
    const existing = await this.prisma.userRole.findUnique({
      where: { id: userRoleId },
    });
    if (!existing)
      throw new NotFoundException(`UserRole #${userRoleId} not found`);

    await this.prisma.userRole.delete({ where: { id: userRoleId } });
    return { success: true };
  }

  // ── Dynamic Branch Naming & Branding Config ────────────────────────────

  async getBranchBranding(id: number) {
    const panchayat = await this.prisma.orgUnit.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        branch_type: true,
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
    if (!panchayat) throw new NotFoundException(`Branch #${id} not found`);
    return panchayat;
  }

  async updateBranchBranding(
    id: number,
    data: {
      software_name_ta?: string;
      software_name_en?: string;
      software_tagline_ta?: string;
      software_tagline_en?: string;
      logo_url?: string;
      secondary_logo_url?: string;
      favicon_url?: string;
      primary_color?: string;
      secondary_color?: string;
      welcome_audio_url?: string;
    },
  ) {
    await this.ensurePanchayatExists(id);
    return this.prisma.orgUnit.update({
      where: { id },
      data: {
        ...(data.software_name_ta !== undefined && { software_name_ta: data.software_name_ta }),
        ...(data.software_name_en !== undefined && { software_name_en: data.software_name_en }),
        ...(data.software_tagline_ta !== undefined && { software_tagline_ta: data.software_tagline_ta }),
        ...(data.software_tagline_en !== undefined && { software_tagline_en: data.software_tagline_en }),
        ...(data.logo_url !== undefined && { logo_url: data.logo_url }),
        ...(data.secondary_logo_url !== undefined && { secondary_logo_url: data.secondary_logo_url }),
        ...(data.favicon_url !== undefined && { favicon_url: data.favicon_url }),
        ...(data.primary_color !== undefined && { primary_color: data.primary_color }),
        ...(data.secondary_color !== undefined && { secondary_color: data.secondary_color }),
        ...(data.welcome_audio_url !== undefined && { welcome_audio_url: data.welcome_audio_url }),
      },
    });
  }

  // ── Private Helpers ────────────────────────────────────────────────────

  private async ensurePanchayatExists(id: number): Promise<any> {
    const exists = await this.prisma.orgUnit.findUnique({
      where: { id },
    });
    if (!exists) throw new NotFoundException(`Panchayat #${id} not found`);
    return exists;
  }
}
