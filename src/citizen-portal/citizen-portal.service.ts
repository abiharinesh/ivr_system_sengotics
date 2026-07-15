import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export class CreateCitizenProfileDto {
  fullName: string;
  phone: string;
  email?: string;
  address?: string;
  ward?: string;
  branchId: number;
}

export class CreateAnnouncementDto {
  branchId: number;
  title: string;
  titleTa?: string;
  body: string;
  bodyTa?: string;
  category?: string; // "general", "water", "road", "event"
  isPinned?: boolean;
  expiresAt?: Date;
}

export class CreateFeedbackDto {
  branchId: number;
  entityType?: string;
  entityId?: number;
  rating: number; // 1-5
  comment?: string;
}

@Injectable()
export class CitizenPortalService {
  constructor(private prisma: PrismaService) {}

  // ── Citizen Profile Operations ──────────────────────────────────────────

  async createProfile(tenantId: string, userId: number, dto: CreateCitizenProfileDto) {
    const existing = await this.prisma.citizenProfile.findUnique({
      where: { user_id: userId },
    });
    if (existing) {
      throw new BadRequestException('Citizen profile already exists for this user account.');
    }

    return this.prisma.citizenProfile.create({
      data: {
        tenant_id: tenantId,
        user_id: userId,
        full_name: dto.fullName,
        phone: dto.phone,
        email: dto.email ?? null,
        address: dto.address ?? null,
        ward: dto.ward ?? null,
        branch_id: dto.branchId,
      },
    });
  }

  async getProfile(tenantId: string, userId: number) {
    const profile = await this.prisma.citizenProfile.findUnique({
      where: { user_id: userId },
      include: { user: true },
    });
    if (!profile || profile.tenant_id !== tenantId) {
      throw new NotFoundException(`Citizen profile for user #${userId} not found.`);
    }
    return profile;
  }

  async updateProfile(tenantId: string, userId: number, dto: Partial<CreateCitizenProfileDto>) {
    await this.getProfile(tenantId, userId);

    return this.prisma.citizenProfile.update({
      where: { user_id: userId },
      data: {
        full_name: dto.fullName,
        phone: dto.phone,
        email: dto.email,
        address: dto.address,
        ward: dto.ward,
        branch_id: dto.branchId,
      },
    });
  }

  // ── Announcements Operations ────────────────────────────────────────────

  async createAnnouncement(tenantId: string, dto: CreateAnnouncementDto, createdBy: number) {
    return this.prisma.announcement.create({
      data: {
        tenant_id: tenantId,
        branch_id: dto.branchId,
        title: dto.title,
        title_ta: dto.titleTa ?? null,
        body: dto.body,
        body_ta: dto.bodyTa ?? null,
        category: dto.category ?? 'general',
        is_pinned: dto.isPinned ?? false,
        expires_at: dto.expiresAt ?? null,
        created_by: createdBy,
      },
    });
  }

  async getAnnouncements(tenantId: string, branchId: number) {
    const now = new Date();
    return this.prisma.announcement.findMany({
      where: {
        tenant_id: tenantId,
        branch_id: branchId,
        OR: [
          { expires_at: null },
          { expires_at: { gte: now } },
        ],
      },
      orderBy: [
        { is_pinned: 'desc' },
        { published_at: 'desc' },
      ],
    });
  }

  // ── Feedback Operations ─────────────────────────────────────────────────

  async createFeedback(tenantId: string, citizenUserId: number | null, dto: CreateFeedbackDto) {
    if (dto.rating < 1 || dto.rating > 5) {
      throw new BadRequestException('Rating must be between 1 and 5');
    }

    return this.prisma.citizenFeedback.create({
      data: {
        tenant_id: tenantId,
        branch_id: dto.branchId,
        citizen_user_id: citizenUserId,
        entity_type: dto.entityType ?? null,
        entity_id: dto.entityId ?? null,
        rating: dto.rating,
        comment: dto.comment ?? null,
      },
    });
  }

  async getFeedbackList(tenantId: string, branchId: number) {
    return this.prisma.citizenFeedback.findMany({
      where: { tenant_id: tenantId, branch_id: branchId },
      orderBy: { created_at: 'desc' },
    });
  }
}
