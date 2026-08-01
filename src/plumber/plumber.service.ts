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

/**
 * Service for plumber-facing operations.
 * Mirrors ElectricianService but uses `assigned_plumber_id`
 * and includes water-pipeline context alongside poles.
 */
@Injectable()
export class PlumberService {
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

  async listComplaints(plumberId: number, status?: string) {
    return this.prisma.complaint.findMany({
      where: {
        assigned_plumber_id: plumberId,
        ...(status && { status }),
      },
      include: {
        pole: true,
        pipeline: true,
        tank: true,
        panchayat: { select: { id: true, name: true } },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  async getComplaint(plumberId: number, complaintId: number) {
    const c = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
      include: {
        pole: true,
        pipeline: true,
        tank: true,
        panchayat: { select: { id: true, name: true } },
        voice_call: {
          select: { id: true, transcript: true, transcript_english: true },
        },
      },
    });
    if (!c) throw new NotFoundException(`Complaint #${complaintId} not found`);
    if (c.assigned_plumber_id !== plumberId) {
      throw new ForbiddenException('This complaint is not assigned to you');
    }
    return c;
  }

  async acceptComplaint(plumberId: number, complaintId: number) {
    const c = await this.getComplaint(plumberId, complaintId);
    if (c.status !== 'assigned') {
      throw new BadRequestException(
        `Can only accept complaints in status "assigned". Current: ${c.status}`,
      );
    }
    return this.prisma.complaint.update({
      where: { id: complaintId },
      data: { status: 'in_progress' },
      include: {
        pole: true,
        pipeline: true,
        panchayat: { select: { id: true, name: true } },
      },
    });
  }

  async submitCannotAttend(
    plumberId: number,
    complaintId: number,
    reason?: string,
  ) {
    const c = await this.getComplaint(plumberId, complaintId);
    if (!['assigned', 'in_progress'].includes(c.status)) {
      throw new BadRequestException(
        `Cannot decline complaint in status "${c.status}"`,
      );
    }
    return this.prisma.complaint.update({
      where: { id: complaintId },
      data: {
        status: 'reassign_required',
        assigned_plumber_id: null,
        assigned_at: null,
        description: reason
          ? `${c.description ?? ''}\n[Plumber declined: ${reason}]`.trim()
          : c.description,
      },
      include: { pole: true, pipeline: true },
    });
  }

  async submitResolution(
    plumberId: number,
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
    const c = await this.getComplaint(plumberId, complaintId);
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
          return this.getComplaint(plumberId, complaintId);
        }
      }
    }

    // For plumber complaints, the reference point could be a pipeline location or a pole
    let dist: number | null = null;
    let locationValid: boolean | null = null;

    // Try pipeline-based geo validation first
    // WaterPipeline stores path as GeoJSON LineString; extract first coordinate
    if (c.pipeline_id && c.pipeline) {
      const pipeline = await this.prisma.waterPipeline.findUnique({
        where: { id: c.pipeline_id },
      });
      if (pipeline && pipeline.path_geojson) {
        try {
          const geo =
            typeof pipeline.path_geojson === 'string'
              ? JSON.parse(pipeline.path_geojson)
              : pipeline.path_geojson;
          const coords = geo?.coordinates;
          if (Array.isArray(coords) && coords.length > 0) {
            // GeoJSON uses [lng, lat] order
            const [refLng, refLat] = coords[0];
            if (Number.isFinite(refLat) && Number.isFinite(refLng)) {
              dist = distanceMeters(
                input.latitude,
                input.longitude,
                refLat,
                refLng,
              );
              locationValid = dist <= DEFAULT_RESOLUTION_RADIUS_M;
            }
          }
        } catch {
          // If GeoJSON is malformed, skip geo-validation for pipeline
        }
      }
    }
    // Fall back to pole-based geo validation
    else if (c.pole_id && c.pole) {
      const pole = await this.prisma.electricPole.findUnique({
        where: { id: c.pole_id },
      });
      if (
        pole &&
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
        pipeline: true,
        panchayat: { select: { id: true, name: true } },
      },
    });

    return resolved;
  }
}
