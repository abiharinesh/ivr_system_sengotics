import { Injectable, NotFoundException } from '@nestjs/common'
import { PrismaService } from '@app/shared'

@Injectable()
export class PoleServiceService {
    constructor(private readonly prisma: PrismaService) {}

    async create(data: {
        panchayat_id: number; pole_number?: string; keypad_id?: string;
        latitude?: number; longitude?: number; landmarks?: string[];
    }) {
        return this.prisma.electricPole.create({
            data: {
                panchayat_id: data.panchayat_id,
                pole_number: data.pole_number,
                keypad_id: data.keypad_id,
                latitude: data.latitude,
                longitude: data.longitude,
                landmarks: data.landmarks ?? [],
            },
        })
    }

    async list(panchayatId?: number) {
        return this.prisma.electricPole.findMany({
            where: panchayatId ? { panchayat_id: panchayatId } : {},
            include: { panchayat: { select: { id: true, name: true } } },
            orderBy: { id: 'asc' },
        })
    }

    async update(id: number, data: {
        panchayat_id?: number; pole_number?: string; keypad_id?: string;
        latitude?: number; longitude?: number; landmarks?: string[];
    }) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id } })
        if (!pole) throw new NotFoundException('Pole not found')
        return this.prisma.electricPole.update({ where: { id }, data })
    }

    async remove(id: number) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id } })
        if (!pole) throw new NotFoundException('Pole not found')
        return this.prisma.electricPole.delete({ where: { id } })
    }
}
