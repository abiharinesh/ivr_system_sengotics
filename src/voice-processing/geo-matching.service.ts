import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

@Injectable()
export class GeoMatchingService {
    private readonly logger = new Logger(GeoMatchingService.name)

    constructor(private prisma: PrismaService) { }

    async findPanchayatByName(villageName: string): Promise<number | null> {
        this.logger.log(`Finding panchayat for village: ${villageName}`)

        const panchayat = await this.prisma.panchayat.findFirst({
            where: {
                name: {
                    equals: villageName,
                    mode: 'insensitive'
                }
            }
        })

        return panchayat?.id || null
    }

    async findNearestPole(panchayatId: number, landmarkHint?: string): Promise<number | null> {
        this.logger.log(`Finding nearest pole for panchayat: ${panchayatId}`)

        // Basic implementation: find first pole in panchayat
        // TODO: Advanced implementation with landmark geocoding
        const pole = await this.prisma.electricPole.findFirst({
            where: { panchayat_id: panchayatId },
            orderBy: { id: 'asc' }
        })

        return pole?.id || null
    }

    async findNearestPoleByCoordinates(
        panchayatId: number,
        latitude: number,
        longitude: number,
        radiusMeters: number = 5000
    ): Promise<number | null> {
        this.logger.log(`Finding pole near (${latitude}, ${longitude}) within ${radiusMeters}m`)

        // Using PostGIS ST_Distance
        const result = await this.prisma.$queryRaw<Array<{ id: number; distance: number }>>`
      SELECT id, 
        ST_Distance(
          location::geography,
          ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
        ) as distance
      FROM electric_poles
      WHERE panchayat_id = ${panchayatId}
      ORDER BY distance ASC
      LIMIT 1
    `

        return result[0]?.id || null
    }
}
