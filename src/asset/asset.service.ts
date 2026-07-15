import { Injectable, NotFoundException, BadRequestException, ForbiddenException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { AuditService } from '../core/audit/audit.service';
import { BranchHierarchyService } from '../core/tenant/branch-hierarchy.service';
import { StorageAdapter } from '../core/document/document.service';
import * as exifr from 'exifr';
import sharp from 'sharp';

export class CreateAssetDto {
  tenantId: string;
  branchId: number;
  assetTypeCode: string;  // references MasterValue code
  name?: string;
  latitude?: number;
  longitude?: number;
  zoneId?: number;
  address?: string;
  landmarks?: string[];
  installedAt?: Date;
  manufacturer?: string;
  modelNumber?: string;
  serialNumber?: string;
  conditionRating?: number;
  customData?: Record<string, any>;
  notes?: string;
}

@Injectable()
export class AssetService {
  private readonly logger = new Logger(AssetService.name);

  constructor(
    private prisma: PrismaService,
    private numberGen: NumberGenService,
    private audit: AuditService,
    private hierarchy: BranchHierarchyService,
    private storage: StorageAdapter,
  ) {}

  /**
   * Create a new asset. Generates code automatically.
   */
  async create(dto: CreateAssetDto, userId?: number) {
    // Generate asset code: e.g., AST-000042
    const assetCode = await this.numberGen.next(dto.tenantId, 'asset', dto.branchId);

    const asset = await this.prisma.asset.create({
      data: {
        tenant_id: dto.tenantId,
        branch_id: dto.branchId,
        asset_type_code: dto.assetTypeCode,
        asset_code: assetCode,
        name: dto.name ?? null,
        latitude: dto.latitude ?? null,
        longitude: dto.longitude ?? null,
        zone_id: dto.zoneId ?? null,
        address: dto.address ?? null,
        landmarks: dto.landmarks ?? [],
        installed_at: dto.installedAt ?? null,
        manufacturer: dto.manufacturer ?? null,
        model_number: dto.modelNumber ?? null,
        serial_number: dto.serialNumber ?? null,
        condition_rating: dto.conditionRating ?? 5,
        custom_data: (dto.customData as any) ?? undefined,
        notes: dto.notes ?? null,
      },
    });

    // Update PostGIS geometry point if coordinates provided
    if (dto.latitude && dto.longitude) {
      await this.prisma.$executeRaw`
        UPDATE assets
        SET location = ST_SetSRID(ST_MakePoint(${dto.longitude}, ${dto.latitude}), 4326)
        WHERE id = ${asset.id}
      `;
    }

    await this.audit.log({
      tenantId: dto.tenantId,
      branchId: dto.branchId,
      userId,
      module: 'assets',
      entityType: 'Asset',
      entityId: asset.id.toString(),
      action: 'create',
      afterValue: asset as any,
    });

    return asset;
  }

  /**
   * List assets with scoping support (District sees Unions & Villages, etc.).
   */
  async list(
    tenantId: string,
    branchId: number,
    accessScope: string,
    filters?: {
      type?: string;
      zoneId?: number;
      search?: string;
      take?: number;
      skip?: number;
    },
  ) {
    const branchIds = accessScope === 'child_branches'
      ? await this.hierarchy.getDescendantBranchIds(tenantId, branchId)
      : [branchId];

    return this.prisma.asset.findMany({
      where: {
        tenant_id: tenantId,
        branch_id: { in: branchIds },
        is_deleted: false,
        ...(filters?.type && { asset_type_code: filters.type }),
        ...(filters?.zoneId && { zone_id: filters.zoneId }),
        ...(filters?.search && {
          OR: [
            { asset_code: { contains: filters.search, mode: 'insensitive' } },
            { name: { contains: filters.search, mode: 'insensitive' } },
            { notes: { contains: filters.search, mode: 'insensitive' } },
          ],
        }),
      },
      include: {
        images: true,
      },
      orderBy: { created_at: 'desc' },
      take: filters?.take ?? 50,
      skip: filters?.skip ?? 0,
    });
  }

  async findOne(tenantId: string, id: number) {
    const asset = await this.prisma.asset.findFirst({
      where: { id, tenant_id: tenantId, is_deleted: false },
      include: {
        images: true,
        maintenance_logs: { orderBy: { performed_at: 'desc' } },
        inspections: { orderBy: { inspected_at: 'desc' } },
        warranties: { where: { is_active: true } },
      },
    });
    if (!asset) throw new NotFoundException(`Asset #${id} not found`);
    return asset;
  }

  async update(tenantId: string, id: number, data: Partial<CreateAssetDto>, userId?: number) {
    const existing = await this.findOne(tenantId, id);

    const updated = await this.prisma.asset.update({
      where: { id },
      data: {
        name: data.name,
        asset_type_code: data.assetTypeCode,
        latitude: data.latitude,
        longitude: data.longitude,
        zone_id: data.zoneId,
        address: data.address,
        landmarks: data.landmarks,
        installed_at: data.installedAt,
        manufacturer: data.manufacturer,
        model_number: data.modelNumber,
        serial_number: data.serialNumber,
        condition_rating: data.conditionRating,
        custom_data: data.customData as any,
        notes: data.notes,
      },
    });

    if (data.latitude && data.longitude) {
      await this.prisma.$executeRaw`
        UPDATE assets
        SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)
        WHERE id = ${id}
      `;
    }

    await this.audit.log({
      tenantId,
      branchId: updated.branch_id,
      userId,
      module: 'assets',
      entityType: 'Asset',
      entityId: id.toString(),
      action: 'update',
      beforeValue: existing as any,
      afterValue: updated as any,
    });

    return updated;
  }

  async softDelete(tenantId: string, id: number, userId?: number) {
    const asset = await this.findOne(tenantId, id);
    await this.prisma.asset.update({
      where: { id },
      data: { is_deleted: true, deleted_at: new Date() },
    });

    await this.audit.log({
      tenantId,
      branchId: asset.branch_id,
      userId,
      module: 'assets',
      entityType: 'Asset',
      entityId: id.toString(),
      action: 'delete',
      beforeValue: asset as any,
    });

    return { success: true };
  }

  /**
   * Upload an asset photo, validate and extract EXIF data.
   */
  async uploadImage(
    tenantId: string,
    assetId: number,
    file: { buffer: Buffer; originalname: string; mimetype: string },
    imageType: 'installation' | 'current' | 'damage' | 'repair',
    caption?: string,
    uploadedBy?: number,
  ) {
    const asset = await this.prisma.asset.findUnique({ where: { id: assetId } });
    if (!asset || asset.tenant_id !== tenantId) {
      throw new NotFoundException('Asset not found');
    }

    // 1. Upload to storage
    const fileExtension = file.originalname.split('.').pop() || '';
    const uniqueKey = `${tenantId}/${asset.branch_id}/assets/${assetId}/${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExtension}`;
    await this.storage.save(uniqueKey, file.buffer);
    const imageUrl = await this.storage.getUrl(uniqueKey);

    // 2. Extract resolution using sharp
    let resolution: string | undefined;
    try {
      const meta = await sharp(file.buffer).metadata();
      resolution = meta.width && meta.height ? `${meta.width}x${meta.height}` : undefined;
    } catch (err) {
      this.logger.warn(`Could not read image dimensions: ${err.message}`);
    }

    // 3. Extract EXIF data using exifr
    let exifData: any = null;
    let gpsLat: number | undefined;
    let gpsLng: number | undefined;
    let capturedAt: Date | undefined;
    let device: string | undefined;

    try {
      const exif = await exifr.parse(file.buffer);
      if (exif) {
        exifData = exif;
        gpsLat = exif.latitude;
        gpsLng = exif.longitude;
        if (exif.DateTimeOriginal) capturedAt = new Date(exif.DateTimeOriginal);
        if (exif.Make || exif.Model) device = `${exif.Make ?? ''} ${exif.Model ?? ''}`.trim();
      }
    } catch (err) {
      this.logger.warn(`EXIF parsing skipped/failed: ${err.message}`);
    }

    // 4. Validate GPS proximity if image has coordinates and asset has coordinates
    let gpsAccuracyM: number | undefined;
    if (gpsLat && gpsLng && asset.latitude && asset.longitude) {
      const distance = this.calculateDistance(gpsLat, gpsLng, asset.latitude, asset.longitude);
      gpsAccuracyM = distance;
      if (distance > 100) { // Reject or warn if over 100 meters away from asset site
        this.logger.warn(`GPS mismatch warning: photo taken ${distance.toFixed(1)}m away from asset site.`);
      }
    }

    // 5. Create AssetImage record
    const assetImage = await this.prisma.assetImage.create({
      data: {
        asset_id: assetId,
        storage_key: uniqueKey,
        image_url: imageUrl,
        image_type: imageType,
        caption: caption ?? null,
        file_size_bytes: file.buffer.length,
        resolution: resolution ?? null,
        captured_device: device ?? null,
        exif_data: exifData ?? null,
        gps_lat: gpsLat ?? null,
        gps_lng: gpsLng ?? null,
        gps_accuracy_m: gpsAccuracyM ?? null,
        captured_at: capturedAt ?? null,
        uploaded_by: uploadedBy ?? null,
      },
    });

    return assetImage;
  }

  private calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371e3; // Earth radius in meters
    const phi1 = (lat1 * Math.PI) / 180;
    const phi2 = (lat2 * Math.PI) / 180;
    const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
    const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
      Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // in meters
  }
}
