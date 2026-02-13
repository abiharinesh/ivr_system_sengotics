import { Injectable, Logger, NotFoundException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { CreatePoleDto, UpdatePoleDto } from './dto/pole.dto'
import { CreatePanchayatDto, UpdatePanchayatDto } from './dto/panchayat.dto'
import { UpdateComplaintStatusDto } from './dto/complaint.dto'

@Injectable()
export class AdminService {
    private readonly logger = new Logger(AdminService.name)

    constructor(private prisma: PrismaService) { }

    // Pole Management
    async createPole(data: CreatePoleDto) {
        const pole = await this.prisma.electricPole.create({
            data: {
                pole_number: data.pole_number,
                latitude: data.latitude,
                longitude: data.longitude,
                panchayat_id: data.panchayat_id
            }
        })

        // Update the location geometry field using raw SQL
        await this.prisma.$executeRaw`
            UPDATE electric_poles 
            SET location = ST_SetSRID(ST_MakePoint(${data.longitude}, ${data.latitude}), 4326)
            WHERE id = ${pole.id}
        `

        return pole
    }

    async updatePole(id: number, data: UpdatePoleDto) {
        const pole = await this.prisma.electricPole.update({
            where: { id },
            data: {
                pole_number: data.pole_number,
                latitude: data.latitude,
                longitude: data.longitude,
                panchayat_id: data.panchayat_id
            }
        })
        return pole
    }

    async deletePole(id: number) {
        await this.prisma.electricPole.delete({ where: { id } })
        return { success: true }
    }

    async listPoles(panchayatId?: number) {
        return this.prisma.electricPole.findMany({
            where: panchayatId ? { panchayat_id: panchayatId } : {},
            include: {
                panchayat: true
            }
        })
    }

    // Panchayat Management
    async createPanchayat(data: CreatePanchayatDto) {
        return this.prisma.panchayat.create({
            data: {
                name: data.name,
                center_lat: data.center_lat,
                center_lng: data.center_lng,
                ivr_number: data.ivr_number
            }
        })
    }

    async updatePanchayat(id: number, data: UpdatePanchayatDto) {
        return this.prisma.panchayat.update({
            where: { id },
            data
        })
    }

    async listPanchayats() {
        return this.prisma.panchayat.findMany({
            include: {
                _count: {
                    select: {
                        electric_poles: true,
                        complaints: true
                    }
                }
            }
        })
    }

    // Complaint Management
    async listComplaints(status?: string, panchayatId?: number) {
        return this.prisma.complaint.findMany({
            where: {
                ...(status && { status }),
                ...(panchayatId && { panchayat_id: panchayatId })
            },
            include: {
                pole: true,
                panchayat: true,
                voice_call: true
            },
            orderBy: { created_at: 'desc' }
        })
    }

    async updateComplaintStatus(id: number, data: UpdateComplaintStatusDto) {
        const complaint = await this.prisma.complaint.findUnique({
            where: { id }
        })

        if (!complaint) {
            throw new NotFoundException('Complaint not found')
        }

        return this.prisma.complaint.update({
            where: { id },
            data: { status: data.status }
        })
    }

    async getStats() {
        const [totalComplaints, pendingComplaints, resolvedComplaints, totalPoles, totalPanchayats] = await Promise.all([
            this.prisma.complaint.count(),
            this.prisma.complaint.count({ where: { status: 'pending' } }),
            this.prisma.complaint.count({ where: { status: 'resolved' } }),
            this.prisma.electricPole.count(),
            this.prisma.panchayat.count()
        ])

        return {
            total_complaints: totalComplaints,
            pending_complaints: pendingComplaints,
            resolved_complaints: resolvedComplaints,
            in_progress_complaints: totalComplaints - pendingComplaints - resolvedComplaints,
            total_poles: totalPoles,
            total_panchayats: totalPanchayats
        }
    }
}
