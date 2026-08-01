import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { normalizePhoneE164 } from '../common/phone.util';

export interface VendorCreateBody {
  name?: string;
  phone?: string;
  place?: string;
  notes?: string;
  active?: boolean;
}

@Injectable()
export class VendorService {
  constructor(private readonly prisma: PrismaService) {}

  list(orgUnitId?: number, opts: { active?: boolean } = {}) {
    return this.prisma.contractor.findMany({
      where: {
        ...(orgUnitId ? { org_unit_id: orgUnitId } : {}),
        ...(opts.active != null ? { is_active: opts.active } : {}),
      },
      orderBy: [{ is_active: 'desc' }, { name: 'asc' }],
      include: {
        org_unit: { select: { id: true, name: true } },
      },
    });
  }

  async get(orgUnitId: number, contractorId: number) {
    const vendor = await this.prisma.contractor.findUnique({
      where: { id: contractorId },
    });
    if (!vendor) throw new NotFoundException(`Vendor #${contractorId} not found`);
    if (vendor.org_unit_id !== orgUnitId) {
      throw new ForbiddenException('Vendor belongs to another panchayat');
    }
    return vendor;
  }

  /** Contractors are tenant-scoped; resolve the tenant from the org unit. */
  private async tenantIdFor(orgUnitId: number): Promise<string> {
    const orgUnit = await this.prisma.orgUnit.findUnique({
      where: { id: orgUnitId },
      select: { tenant_id: true },
    });
    if (!orgUnit) throw new NotFoundException(`Org unit #${orgUnitId} not found`);
    return orgUnit.tenant_id;
  }

  async create(orgUnitId: number, data: VendorCreateBody) {
    const name = data.name?.trim();
    if (!name) throw new BadRequestException('name is required');
    const phone = normalizePhoneE164(data.phone);
    const tenantId = await this.tenantIdFor(orgUnitId);

    // Contractors are unique per (tenant, phone) — the same company must not
    // exist twice just because it was reached via a different org unit.
    const existing = await this.prisma.contractor.findFirst({
      where: { tenant_id: tenantId, phone },
    });
    if (existing)
      throw new BadRequestException(
        `Contractor with phone ${phone} already exists in this tenant`,
      );

    return this.prisma.contractor.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        name,
        phone,
        place: data.place?.trim() || null,
        notes: data.notes?.trim() || null,
        is_active: data.active ?? true,
      },
    });
  }

  async update(orgUnitId: number, contractorId: number, patch: VendorCreateBody) {
    await this.get(orgUnitId, contractorId);
    const data: Record<string, unknown> = {};
    if (patch.name !== undefined) data.name = patch.name.trim() || null;
    if (patch.phone !== undefined)
      data.phone = normalizePhoneE164(patch.phone);
    if (patch.place !== undefined) data.place = patch.place?.trim() || null;
    if (patch.notes !== undefined) data.notes = patch.notes?.trim() || null;
    if (patch.active !== undefined) data.active = !!patch.active;
    return this.prisma.contractor.update({ where: { id: contractorId }, data });
  }

  async deactivate(orgUnitId: number, contractorId: number) {
    await this.get(orgUnitId, contractorId);
    return this.prisma.contractor.update({
      where: { id: contractorId },
      data: { is_active: false },
    });
  }

  /** Idempotent helper for public-with-phone tenders: upsert vendor stub by phone. */
  async upsertStubByPhone(args: {
    orgUnitId: number;
    phoneE164: string;
    name: string;
    place?: string | null;
  }) {
    const tenantId = await this.tenantIdFor(args.orgUnitId);
    const existing = await this.prisma.contractor.findFirst({
      where: { tenant_id: tenantId, phone: args.phoneE164 },
    });
    if (existing) {
      // Best-effort name backfill if previously empty.
      if (!existing.name && args.name) {
        return this.prisma.contractor.update({
          where: { id: existing.id },
          data: { name: args.name, place: args.place ?? existing.place },
        });
      }
      return existing;
    }
    return this.prisma.contractor.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: args.orgUnitId,
        phone: args.phoneE164,
        name: args.name || 'Public submitter',
        place: args.place ?? null,
        is_active: true,
      },
    });
  }
}
