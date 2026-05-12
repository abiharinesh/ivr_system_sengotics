import {
    BadRequestException,
    ForbiddenException,
    Injectable,
    NotFoundException,
} from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { normalizePhoneE164 } from '../common/phone.util'

export interface VendorCreateBody {
    name?: string
    phone_e164?: string
    place?: string
    notes?: string
    active?: boolean
}

@Injectable()
export class VendorService {
    constructor(private readonly prisma: PrismaService) {}

    list(panchayatId: number, opts: { active?: boolean } = {}) {
        return this.prisma.vendor.findMany({
            where: { panchayat_id: panchayatId, ...(opts.active != null ? { active: opts.active } : {}) },
            orderBy: [{ active: 'desc' }, { name: 'asc' }],
        })
    }

    async get(panchayatId: number, vendorId: number) {
        const vendor = await this.prisma.vendor.findUnique({ where: { id: vendorId } })
        if (!vendor) throw new NotFoundException(`Vendor #${vendorId} not found`)
        if (vendor.panchayat_id !== panchayatId) {
            throw new ForbiddenException('Vendor belongs to another panchayat')
        }
        return vendor
    }

    async create(panchayatId: number, data: VendorCreateBody) {
        const name = data.name?.trim()
        if (!name) throw new BadRequestException('name is required')
        const phone = normalizePhoneE164(data.phone_e164)

        const existing = await this.prisma.vendor.findFirst({
            where: { panchayat_id: panchayatId, phone_e164: phone },
        })
        if (existing) throw new BadRequestException(`Vendor with phone ${phone} already exists in this panchayat`)

        return this.prisma.vendor.create({
            data: {
                panchayat_id: panchayatId,
                name,
                phone_e164: phone,
                place: data.place?.trim() || null,
                notes: data.notes?.trim() || null,
                active: data.active ?? true,
            },
        })
    }

    async update(panchayatId: number, vendorId: number, patch: VendorCreateBody) {
        await this.get(panchayatId, vendorId)
        const data: Record<string, unknown> = {}
        if (patch.name !== undefined) data.name = patch.name.trim() || null
        if (patch.phone_e164 !== undefined) data.phone_e164 = normalizePhoneE164(patch.phone_e164)
        if (patch.place !== undefined) data.place = patch.place?.trim() || null
        if (patch.notes !== undefined) data.notes = patch.notes?.trim() || null
        if (patch.active !== undefined) data.active = !!patch.active
        return this.prisma.vendor.update({ where: { id: vendorId }, data })
    }

    async deactivate(panchayatId: number, vendorId: number) {
        await this.get(panchayatId, vendorId)
        return this.prisma.vendor.update({ where: { id: vendorId }, data: { active: false } })
    }

    /** Idempotent helper for public-with-phone tenders: upsert vendor stub by phone. */
    async upsertStubByPhone(args: {
        panchayatId: number
        phoneE164: string
        name: string
        place?: string | null
    }) {
        const existing = await this.prisma.vendor.findFirst({
            where: { panchayat_id: args.panchayatId, phone_e164: args.phoneE164 },
        })
        if (existing) {
            // Best-effort name backfill if previously empty.
            if (!existing.name && args.name) {
                return this.prisma.vendor.update({
                    where: { id: existing.id },
                    data: { name: args.name, place: args.place ?? existing.place },
                })
            }
            return existing
        }
        return this.prisma.vendor.create({
            data: {
                panchayat_id: args.panchayatId,
                phone_e164: args.phoneE164,
                name: args.name || 'Public submitter',
                place: args.place ?? null,
                active: true,
            },
        })
    }
}
