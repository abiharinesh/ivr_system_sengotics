import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import archiver from 'archiver';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { resolveDateRange } from '../common/date-preset.util';
import {
  distanceMeters,
  DEFAULT_RESOLUTION_RADIUS_M,
} from '../common/geo.util';
import type { UploadedImageFile } from '../common/upload.types';

const MAX_EXPORT_ROWS = 2000;

function csvEscape(value: string): string {
  if (/[",\n\r]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

@Injectable()
export class ElectricianOpsService {
  private readonly logger = new Logger(ElectricianOpsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async listElectricians(panchayatId: number) {
    return this.prisma.user.findMany({
      where: { panchayat_id: panchayatId, role: 'electrician' },
      select: {
        id: true,
        email: true,
        phone_e164: true,
        created_at: true,
        panchayat_id: true,
      },
      orderBy: { id: 'asc' },
    });
  }

  async listAllElectricians(panchayatFilterId?: number) {
    return this.prisma.user.findMany({
      where: {
        role: 'electrician',
        ...(panchayatFilterId != null && !Number.isNaN(panchayatFilterId)
          ? { panchayat_id: panchayatFilterId }
          : {}),
      },
      select: {
        id: true,
        email: true,
        phone_e164: true,
        created_at: true,
        panchayat_id: true,
        panchayat: { select: { id: true, name: true } },
      },
      orderBy: [{ panchayat_id: 'asc' }, { id: 'asc' }],
    });
  }

  async createElectricianForPanchayat(
    panchayatId: number,
    data: { email: string; password: string; phone_e164?: string | null },
  ) {
    if (!data.password || data.password.length < 8) {
      throw new BadRequestException(
        'Password must be at least 8 characters long',
      );
    }
    const existing = await this.prisma.user.findUnique({
      where: { email: data.email },
    });
    if (existing) throw new BadRequestException('Email already in use');
    const password_hash = await bcrypt.hash(data.password, 10);
    return this.prisma.user.create({
      data: {
        email: data.email,
        password_hash,
        role: 'electrician',
        panchayat_id: panchayatId,
        phone_e164: data.phone_e164?.trim() || null,
      },
      select: {
        id: true,
        email: true,
        phone_e164: true,
        role: true,
        panchayat_id: true,
        created_at: true,
      },
    });
  }

  private async ensureElectricianInPanchayat(
    electricianId: number,
    panchayatId: number,
  ) {
    const u = await this.prisma.user.findUnique({
      where: { id: electricianId },
    });
    if (!u || u.role !== 'electrician')
      throw new BadRequestException('Not an electrician');
    if (u.panchayat_id !== panchayatId)
      throw new ForbiddenException('Electrician is in another panchayat');
    return u;
  }

  async getElectricianStats(
    electricianId: number,
    scopedPanchayatId: number | null,
    preset: string,
    dateFrom?: string,
    dateTo?: string,
  ) {
    const u = await this.prisma.user.findUnique({
      where: { id: electricianId },
    });
    if (!u || u.role !== 'electrician')
      throw new NotFoundException('Electrician not found');
    if (scopedPanchayatId != null && u.panchayat_id !== scopedPanchayatId) {
      throw new ForbiddenException('Electrician belongs to another panchayat');
    }

    const { from, to } = resolveDateRange(preset, dateFrom, dateTo);

    const [assignedInPeriod, resolvedInPeriod, openAssigned] =
      await Promise.all([
        this.prisma.complaint.count({
          where: {
            assigned_electrician_id: electricianId,
            assigned_at: { gte: from, lte: to },
          },
        }),
        this.prisma.complaint.count({
          where: {
            assigned_electrician_id: electricianId,
            status: 'resolved',
            resolved_at: { gte: from, lte: to },
          },
        }),
        this.prisma.complaint.count({
          where: {
            assigned_electrician_id: electricianId,
            status: {
              in: [
                'assigned',
                'in_progress',
                'resolved_pending_confirmation',
                'reassign_required',
              ],
            },
          },
        }),
      ]);

    return {
      electrician: { id: u.id, email: u.email, phone_e164: u.phone_e164 },
      preset,
      range: { from: from.toISOString(), to: to.toISOString() },
      assigned_in_period: assignedInPeriod,
      resolved_in_period: resolvedInPeriod,
      open_assigned: openAssigned,
    };
  }

  async createResolvedExportJob(args: {
    createdByUserId: number;
    scopedPanchayatId: number | null;
    electricianId: number;
    preset: string;
    dateFrom?: string;
    dateTo?: string;
  }) {
    const u = await this.prisma.user.findUnique({
      where: { id: args.electricianId },
    });
    if (!u || u.role !== 'electrician')
      throw new BadRequestException('Invalid electrician');
    if (
      args.scopedPanchayatId != null &&
      u.panchayat_id !== args.scopedPanchayatId
    ) {
      throw new ForbiddenException('Electrician belongs to another panchayat');
    }

    const { from, to } = resolveDateRange(
      args.preset,
      args.dateFrom,
      args.dateTo,
    );

    const job = await this.prisma.exportJob.create({
      data: {
        created_by_user_id: args.createdByUserId,
        panchayat_id: u.panchayat_id,
        electrician_user_id: args.electricianId,
        range_from: from,
        range_to: to,
        status: 'pending',
      },
    });

    void this.processExportJob(job.id).catch((err) => {
      this.logger.error(`Export job ${job.id} failed: ${err?.message ?? err}`);
    });

    return { job_id: job.id, status: job.status };
  }

  async getExportJob(
    jobId: number,
    requester: { id: number; role: string; panchayat_id: number | null },
  ) {
    const job = await this.prisma.exportJob.findUnique({
      where: { id: jobId },
      include: {
        electrician: { select: { id: true, email: true } },
      },
    });
    if (!job) throw new NotFoundException('Export job not found');

    if (requester.role === 'panchayat_admin') {
      if (job.panchayat_id !== requester.panchayat_id) {
        throw new ForbiddenException('Wrong panchayat');
      }
    } else if (requester.role !== 'super_admin') {
      throw new ForbiddenException('Forbidden');
    }

    const outPath = job.result_relative_path ?? null;
    return {
      id: job.id,
      status: job.status,
      row_count: job.row_count,
      error_message: job.error_message,
      download_url: job.status === 'ready' && outPath ? outPath : null,
      created_at: job.created_at,
      completed_at: job.completed_at,
      electrician: job.electrician,
    };
  }

  resolveExportAbsolutePath(relativePath: string): string {
    const clean = relativePath.replace(/^\/+/, '');
    if (!clean.startsWith('uploads/exports/')) {
      throw new ForbiddenException('Invalid export path');
    }
    return path.join(process.cwd(), clean);
  }

  private async processExportJob(jobId: number): Promise<void> {
    const job = await this.prisma.exportJob.findUnique({
      where: { id: jobId },
    });
    if (!job) return;

    await this.prisma.exportJob.update({
      where: { id: jobId },
      data: { status: 'processing', error_message: null },
    });

    try {
      const complaints = await this.prisma.complaint.findMany({
        where: {
          assigned_electrician_id: job.electrician_user_id,
          status: 'resolved',
          resolved_at: {
            gte: job.range_from,
            lte: job.range_to,
          },
        },
        include: {
          pole: true,
          panchayat: { select: { id: true, name: true } },
        },
        orderBy: { resolved_at: 'asc' },
        take: MAX_EXPORT_ROWS,
      });

      const exportDir = path.join(process.cwd(), 'uploads', 'exports');
      await fs.promises.mkdir(exportDir, { recursive: true });

      const filename = `export-${jobId}-${Date.now()}.zip`;
      const absZip = path.join(exportDir, filename);
      const relPath = `/uploads/exports/${filename}`;

      const output = fs.createWriteStream(absZip);
      const archive = archiver('zip', { zlib: { level: 6 } });
      archive.on('error', (err) => {
        throw err;
      });
      archive.pipe(output);

      const header = [
        'complaint_id',
        'pole_id',
        'panchayat',
        'category',
        'resolved_at',
        'proof_lat',
        'proof_lng',
        'proof_captured_at',
        'geotag_ok',
        'image_file',
      ].join(',');

      const lines: string[] = [header];
      let imgIndex = 0;

      for (const c of complaints) {
        const imgUrl = c.resolution_image_url;
        let diskName = '';
        if (imgUrl) {
          const relFile = imgUrl.replace(/^\/+/, '');
          const absImg = path.join(process.cwd(), relFile);
          if (fs.existsSync(absImg)) {
            imgIndex += 1;
            diskName = `images/complaint_${c.id}_${imgIndex}${path.extname(absImg) || '.jpg'}`;
            archive.file(absImg, { name: diskName });
          }
        }

        lines.push(
          [
            c.id,
            c.pole_id ?? '',
            csvEscape(c.panchayat?.name ?? ''),
            csvEscape(c.category ?? ''),
            c.resolved_at?.toISOString() ?? '',
            c.resolution_image_latitude ?? '',
            c.resolution_image_longitude ?? '',
            c.resolution_image_captured_at?.toISOString() ?? '',
            c.resolution_location_valid === null
              ? ''
              : String(c.resolution_location_valid),
            csvEscape(diskName),
          ].join(','),
        );
      }

      archive.append(lines.join('\n'), { name: 'manifest.csv' });
      await archive.finalize();

      await new Promise<void>((resolve, reject) => {
        output.on('close', () => resolve());
        output.on('error', reject);
      });

      await this.prisma.exportJob.update({
        where: { id: jobId },
        data: {
          status: 'ready',
          result_relative_path: relPath.replace(/\\/g, '/'),
          row_count: complaints.length,
          completed_at: new Date(),
        },
      });
    } catch (e: any) {
      await this.prisma.exportJob.update({
        where: { id: jobId },
        data: {
          status: 'failed',
          error_message: String(e?.message ?? e).slice(0, 2000),
          completed_at: new Date(),
        },
      });
    }
  }

  /**
   * Attach a proof image from WhatsApp to the electrician's active complaint (single match).
   */
  async attachWhatsAppProof(args: {
    electricianUserId: number;
    image: UploadedImageFile;
    exifLat?: number | null;
    exifLng?: number | null;
  }): Promise<{ complaint_id: number } | { error: string }> {
    const open = await this.prisma.complaint.findMany({
      where: {
        assigned_electrician_id: args.electricianUserId,
        status: { in: ['assigned', 'in_progress'] },
      },
      include: { pole: true },
    });

    if (open.length === 0) {
      return { error: 'no_open_complaint' };
    }
    if (open.length > 1) {
      return { error: 'multiple_open_complaints' };
    }

    const c = open[0];
    const lat = args.exifLat ?? null;
    const lng = args.exifLng ?? null;

    let dist: number | null = null;
    let locationValid: boolean | null = null;
    if (
      lat != null &&
      lng != null &&
      c.pole?.latitude != null &&
      c.pole?.longitude != null
    ) {
      dist = distanceMeters(lat, lng, c.pole.latitude, c.pole.longitude);
      locationValid = dist <= DEFAULT_RESOLUTION_RADIUS_M;
    }

    const subdir = 'complaints/resolutions';
    const ext = path.extname(args.image.originalname || '') || '.jpg';
    const name = `wa-${c.id}-${Date.now()}${ext}`;
    const dir = path.join(process.cwd(), 'uploads', subdir);
    await fs.promises.mkdir(dir, { recursive: true });
    const abs = path.join(dir, name);
    await fs.promises.writeFile(abs, args.image.buffer);
    const url = `/uploads/${subdir}/${name}`.replace(/\\/g, '/');

    await this.prisma.complaint.update({
      where: { id: c.id },
      data: {
        status: 'resolved_pending_confirmation',
        resolution_image_url: url,
        resolution_image_latitude: lat,
        resolution_image_longitude: lng,
        resolution_image_captured_at: new Date(),
        resolution_distance_meters: dist,
        resolution_location_valid: locationValid,
      },
    });

    return { complaint_id: c.id };
  }

  async markWhatsAppDoneAck(complaintId: number, electricianUserId: number) {
    const c = await this.prisma.complaint.findUnique({
      where: { id: complaintId },
    });
    if (!c) return { error: 'not_found' as const };
    if (c.assigned_electrician_id !== electricianUserId)
      return { error: 'forbidden' as const };
    await this.prisma.complaint.update({
      where: { id: complaintId },
      data: { whatsapp_done_ack_at: new Date() },
    });
    return { ok: true as const };
  }
}
