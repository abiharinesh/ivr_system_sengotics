import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { LocalFilesService } from '../storage/local-files.service'
import type { UploadedImageFile } from '../common/upload.types'

@Injectable()
export class AgentService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly files: LocalFilesService
    ) { }

    async listPoles(panchayatId: number, search?: string) {
        return this.prisma.electricPole.findMany({
            where: {
                panchayat_id: panchayatId,
                ...(search?.trim() && {
                    OR: [
                        { pole_number: { contains: search.trim(), mode: 'insensitive' } },
                        { keypad_id: { contains: search.trim(), mode: 'insensitive' } },
                    ],
                }),
            },
            orderBy: { id: 'desc' },
            include: {
                _count: { select: { complaints: true } },
            },
        })
    }

    async getPole(panchayatId: number, poleId: number) {
        const pole = await this.prisma.electricPole.findUnique({ where: { id: poleId } })
        if (!pole) throw new NotFoundException(`Pole #${poleId} not found`)
        if (pole.panchayat_id !== panchayatId) {
            throw new ForbiddenException('Access denied — pole belongs to another panchayat')
        }
        return pole
    }

    async createPole(
        panchayatId: number,
        _userId: number,
        data: {
            pole_number?: string
            keypad_id?: string
            latitude?: number
            longitude?: number
            landmarks?: string[]
        }
    ) {
        const pole = await this.prisma.electricPole.create({
            data: {
                pole_number: data.pole_number,
                keypad_id: data.keypad_id,
                latitude: data.latitude,
                longitude: data.longitude,
                landmarks: data.landmarks ?? [],
                panchayat_id: panchayatId,
            },
        })
        if (data.latitude != null && data.longitude != null) {
            await this.prisma.$executeRaw`
                UPDATE electric_poles
                SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)
                WHERE id = ${pole.id}
            `
        }
        return pole
    }

    async attachPoleImage(
        panchayatId: number,
        agentUserId: number,
        poleId: number,
        file: UploadedImageFile,
        geo: { latitude: number; longitude: number; capturedAt: Date }
    ) {
        const pole = await this.getPole(panchayatId, poleId)
        const url = await this.files.saveBuffer('poles', file.buffer, file.originalname)

        const updated = await this.prisma.electricPole.update({
            where: { id: poleId },
            data: {
                image_url: url,
                image_latitude: geo.latitude,
                image_longitude: geo.longitude,
                image_captured_at: geo.capturedAt,
                image_uploaded_at: new Date(),
                image_uploaded_by: agentUserId,
                latitude: geo.latitude,
                longitude: geo.longitude,
            },
        })

        await this.prisma.$executeRaw`
            UPDATE electric_poles
            SET location = ST_SetSRID(ST_MakePoint(${geo.longitude}, ${geo.latitude}), 4326)
            WHERE id = ${poleId}
        `

        return updated
    }

    async createPoleWithImage(
        panchayatId: number,
        agentUserId: number,
        data: {
            pole_number?: string
            keypad_id?: string
            landmarks?: string[]
        },
        file: UploadedImageFile,
        geo: { latitude: number; longitude: number; capturedAt: Date }
    ) {
        if (!data.keypad_id?.trim() && !data.pole_number?.trim()) {
            throw new BadRequestException('Provide keypad_id and/or pole_number')
        }
        const pole = await this.createPole(panchayatId, agentUserId, {
            pole_number: data.pole_number,
            keypad_id: data.keypad_id,
            latitude: geo.latitude,
            longitude: geo.longitude,
            landmarks: data.landmarks,
        })
        return this.attachPoleImage(panchayatId, agentUserId, pole.id, file, geo)
    }
}
