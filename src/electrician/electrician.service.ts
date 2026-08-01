import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LocalFilesService } from '../storage/local-files.service';
import type { UploadedImageFile } from '../common/upload.types';
import {
  distanceMeters,
  DEFAULT_RESOLUTION_RADIUS_M,
} from '../common/geo.util';

@Injectable()
export class ElectricianService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly files: LocalFilesService,
  ) {}

  async getMe(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        primary_org_unit_id: true,
        primary_org_unit: { select: { id: true, name: true } },
      },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async listComplaints(electricianId: number, status?: string) {
    return this.prisma.complaint.findMany({
      where: {
        assigned_electrician_id: electricianId,
        ...(status && { status }),
      },
      include: {
        pole: true,
        panchayat: { select: { id: true, name: true } },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  async getComplaint(electricianId: number, complaintId: number) {
    const c = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
      include: {
        pole: true,
        panchayat: { select: { id: true, name: true } },
        voice_call: {
          select: { id: true, transcript: true, transcript_english: true },
        },
      },
    });
    if (!c) throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (c.assigned_electrician_id !== electricianId) {
      throw new ForbiddenException('This complaint is not assigned to you');
    }
    return c;
  }

  async acceptComplaint(electricianId: number, complaintId: number) {
    const c = await this.getComplaint(electricianId, complaintId);
    if (c.status !== 'assigned') {
      throw new BadRequestException(
        `Can only accept complaints in status "assigned". Current: ${c.status}`,
      );
    }
    return this.prisma.complaint.update({
      where: { id: complaintId },
      data: { status: 'in_progress' },
      include: { pole: true, panchayat: { select: { id: true, name: true } } },
    });
  }

  async submitCannotAttend(
    electricianId: number,
    complaintId: number,
    reason?: string,
  ) {
    const c = await this.getComplaint(electricianId, complaintId);
    if (!['assigned', 'in_progress'].includes(c.status)) {
      throw new BadRequestException(
        `Cannot decline complaint in status "${c.status}"`,
      );
    }
    return this.prisma.complaint.update({
      where: { id: complaintId },
      data: {
        status: 'reassign_required',
        assigned_electrician_id: null,
        assigned_at: null,
        description: reason
          ? `${c.description ?? ''}\n[Electrician declined: ${reason}]`.trim()
          : c.description,
      },
      include: { pole: true },
    });
  }

  async submitResolution(
    electricianId: number,
    complaintId: number,
    file: UploadedImageFile,
    input: {
      latitude: number;
      longitude: number;
      capturedAt: Date;
      note?: string;
      localJobId?: string;
    },
  ) {
    const c = await this.getComplaint(electricianId, complaintId);
    if (!['assigned', 'in_progress'].includes(c.status)) {
      throw new BadRequestException(
        `Can only submit resolution for assigned/in_progress complaints. Current: ${c.status}`,
      );
    }

    if (input.localJobId) {
      const prior = await this.prisma.complaint.findUnique({
        where: { resolution_submitted_key: input.localJobId },
      });
      if (prior) {
        if (prior.id !== complaintId) {
          throw new BadRequestException(
            'localJobId already used for another complaint',
          );
        }
        if (prior.resolution_image_url) {
          return this.getComplaint(electricianId, complaintId);
        }
      }
    }

    if (!c.pole_id || !c.pole) {
      throw new BadRequestException(
        'Complaint has no pole — cannot validate proof location',
      );
    }

    const pole = await this.prisma.electricPole.findUnique({
      where: { id: c.pole_id },
    });
    if (!pole) throw new BadRequestException('Pole missing');

    let dist: number | null = null;
    let locationValid: boolean | null = null;
    if (
      pole.latitude != null &&
      pole.longitude != null &&
      Number.isFinite(pole.latitude) &&
      Number.isFinite(pole.longitude)
    ) {
      dist = distanceMeters(
        input.latitude,
        input.longitude,
        pole.latitude,
        pole.longitude,
      );
      locationValid = dist <= DEFAULT_RESOLUTION_RADIUS_M;
    }

    const imageUrl = await this.files.saveBuffer(
      'complaints/resolutions',
      file.buffer,
      file.originalname,
    );

    const resolved = await this.prisma.complaint.update({
      where: { id: complaintId },
      data: {
        status: 'resolved_pending_confirmation',
        resolution_image_url: imageUrl,
        resolution_note: input.note ?? null,
        resolution_image_latitude: input.latitude,
        resolution_image_longitude: input.longitude,
        resolution_image_captured_at: input.capturedAt,
        resolution_distance_meters: dist,
        resolution_location_valid: locationValid,
        resolution_submitted_key: input.localJobId ?? null,
        resolved_at: null,
      },
      include: {
        pole: true,
        panchayat: { select: { id: true, name: true } },
      },
    });

    return resolved;
  }
}
