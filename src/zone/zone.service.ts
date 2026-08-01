import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface CreateZoneDto {
  name: string;
  boundary_geojson: Record<string, unknown>;
  color?: string;
  opacity?: number;
  places?: string[];
}

export interface UpdateZoneDto {
  name?: string;
  boundary_geojson?: Record<string, unknown>;
  color?: string;
  opacity?: number;
  places?: string[];
  is_active?: boolean;
}

export interface NominatimResult {
  place_id: number;
  display_name: string;
  type: string;
  geojson?: Record<string, unknown>;
  boundingbox?: string[];
  lat: string;
  lon: string;
}

@Injectable()
export class ZoneService {
  constructor(private readonly prisma: PrismaService) {}

  // ── CRUD ───────────────────────────────────────────────────────────────

  async listByPanchayat(orgUnitId: number) {
    return this.prisma.zone.findMany({
      where: { org_unit_id: orgUnitId },
      orderBy: { created_at: 'desc' },
    });
  }

  async listAll() {
    return this.prisma.zone.findMany({
      include: { org_unit: { select: { id: true, name: true } } },
      orderBy: { created_at: 'desc' },
    });
  }

  async create(orgUnitId: number, dto: CreateZoneDto) {
    this.validateGeoJson(dto.boundary_geojson);
    return this.prisma.zone.create({
      data: {
        org_unit_id: orgUnitId,
        name: dto.name,
        boundary_geojson: dto.boundary_geojson as any,
        color: dto.color ?? '#2563EB',
        opacity: dto.opacity ?? 0.3,
        places: dto.places ?? [],
      },
    });
  }

  async update(orgUnitId: number, zoneId: number, dto: UpdateZoneDto) {
    const existing = await this.prisma.zone.findFirst({
      where: { id: zoneId, org_unit_id: orgUnitId },
    });
    if (!existing) {
      throw new NotFoundException(
        `Zone #${zoneId} not found in panchayat #${orgUnitId}`,
      );
    }

    if (dto.boundary_geojson) {
      this.validateGeoJson(dto.boundary_geojson);
    }

    return this.prisma.zone.update({
      where: { id: zoneId },
      data: {
        ...(dto.name != null && { name: dto.name }),
        ...(dto.boundary_geojson != null && {
          boundary_geojson: dto.boundary_geojson as any,
        }),
        ...(dto.color != null && { color: dto.color }),
        ...(dto.opacity != null && { opacity: dto.opacity }),
        ...(dto.places != null && { places: dto.places }),
        ...(dto.is_active != null && { is_active: dto.is_active }),
      },
    });
  }

  async delete(orgUnitId: number, zoneId: number) {
    const existing = await this.prisma.zone.findFirst({
      where: { id: zoneId, org_unit_id: orgUnitId },
    });
    if (!existing) {
      throw new NotFoundException(
        `Zone #${zoneId} not found in panchayat #${orgUnitId}`,
      );
    }
    await this.prisma.zone.delete({ where: { id: zoneId } });
    return { deleted: true };
  }

  // ── OSM Nominatim Boundary Lookup ──────────────────────────────────────

  /**
   * Searches OSM Nominatim for a place by name and returns its boundary polygon.
   * This proxies the request to avoid CORS issues and rate-limit concerns on the frontend.
   *
   * OSM Nominatim is used because it provides detailed village/panchayat boundary
   * polygons for Indian administrative divisions, which Google's Geocoding API
   * typically does not.
   */
  async lookupBoundary(
    placeName: string,
    countryCode = 'in',
  ): Promise<NominatimResult[]> {
    if (!placeName || placeName.trim().length < 2) {
      throw new BadRequestException('Place name must be at least 2 characters');
    }

    const params = new URLSearchParams({
      q: placeName.trim(),
      format: 'json',
      polygon_geojson: '1',
      addressdetails: '1',
      limit: '8',
      countrycodes: countryCode,
    });

    const url = `https://nominatim.openstreetmap.org/search?${params}`;

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'IVR-System-Sengotics/1.0 (admin zone management)',
        Accept: 'application/json',
      },
    });

    if (!response.ok) {
      throw new BadRequestException(`Nominatim API error: ${response.status}`);
    }

    const results: NominatimResult[] = await response.json();
    // Filter to entries that actually have polygon boundaries
    return results.filter(
      (r) =>
        r.geojson &&
        (r.geojson.type === 'Polygon' || r.geojson.type === 'MultiPolygon'),
    );
  }

  // ── Validation ────────────────────────────────────────────────────────

  private validateGeoJson(geojson: Record<string, unknown>) {
    if (!geojson || typeof geojson !== 'object') {
      throw new BadRequestException(
        'boundary_geojson must be a valid GeoJSON object',
      );
    }

    const type = geojson.type as string;
    if (
      type !== 'Polygon' &&
      type !== 'MultiPolygon' &&
      type !== 'Feature' &&
      type !== 'FeatureCollection'
    ) {
      throw new BadRequestException(
        `boundary_geojson type must be Polygon, MultiPolygon, Feature, or FeatureCollection. Got: ${type}`,
      );
    }

    // For Polygon/MultiPolygon, ensure coordinates exist
    if (
      (type === 'Polygon' || type === 'MultiPolygon') &&
      !geojson.coordinates
    ) {
      throw new BadRequestException(
        'Polygon/MultiPolygon must have coordinates',
      );
    }
  }
}
