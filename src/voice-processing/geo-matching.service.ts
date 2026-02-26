import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { ConfigService } from '@nestjs/config'
import OpenAI from 'openai'

@Injectable()
export class GeoMatchingService {
    private readonly logger = new Logger(GeoMatchingService.name)
    private openai: OpenAI

    constructor(
        private prisma: PrismaService,
        private configService: ConfigService
    ) {
        this.openai = new OpenAI({
            apiKey: this.configService.get<string>('OPENAI_API_KEY')
        })
    }

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

    /**
     * Finds the nearest pole for a panchayat using AI-based semantic landmark matching.
     * The AI compares the extracted landmark hint against all stored pole landmarks,
     * handling Tamil/English translations and fuzzy phrasing automatically.
     * Returns null if no confident match is found.
     */
    async findNearestPole(panchayatId: number, landmarkHint?: string): Promise<number | null> {
        this.logger.log(`Finding pole for panchayat: ${panchayatId}, landmark: "${landmarkHint}"`)

        // Fetch all poles in this panchayat
        const poles = await this.prisma.electricPole.findMany({
            where: { panchayat_id: panchayatId }
        })

        if (poles.length === 0) {
            this.logger.warn(`No poles found for panchayat ${panchayatId}`)
            return null
        }

        // If no landmark hint is provided, we can't do semantic matching
        if (!landmarkHint || landmarkHint.trim() === '') {
            this.logger.warn(`No landmark hint provided — cannot identify specific pole`)
            return null
        }

        // Filter to poles that have at least one landmark stored
        const polesWithLandmarks = poles.filter(p => p.landmarks && p.landmarks.length > 0)

        if (polesWithLandmarks.length === 0) {
            this.logger.warn(`No poles with landmarks found in panchayat ${panchayatId}`)
            return null
        }

        // Build a JSON list of poles for the AI to match against
        const poleList = polesWithLandmarks.map(p => ({
            pole_id: p.id,
            pole_number: p.pole_number,
            landmarks: p.landmarks
        }))

        this.logger.log(`AI matching landmark "${landmarkHint}" against ${poleList.length} poles`)

        try {
            const response = await this.openai.chat.completions.create({
                model: 'gpt-4o-mini',
                temperature: 0.0,
                response_format: { type: 'json_object' },
                messages: [
                    {
                        role: 'system',
                        content: `You are a landmark matching engine for electric poles in Tamil Nadu villages.
You will receive a landmark description spoken by a caller and a list of electric poles with their known landmarks.
Your job is to find the best matching pole, accounting for:
- Tamil to English translation differences (e.g. "kovil" = "temple", "pallivasal" = "mosque", "kadai" = "shop")
- Synonym variations (e.g. "tree" vs "banyan tree")
- Minor phrasing differences (e.g. "near the temple" vs "beside the temple")
- Directional hints (left, right, opposite)

Return ONLY a JSON object in this format:
{
  "matched_pole_id": <number or null>,
  "confidence": <0.0 to 1.0>,
  "reason": "<brief explanation>"
}

If no pole has a reasonably matching landmark (confidence < 0.6), return matched_pole_id as null.`
                    },
                    {
                        role: 'user',
                        content: `Caller described the pole location as: "${landmarkHint}"

Available poles and their landmarks:
${JSON.stringify(poleList, null, 2)}

Match the caller's description to the correct pole.`
                    }
                ]
            })

            const result = JSON.parse(response.choices[0].message.content || '{}')
            this.logger.log(`AI match result: ${JSON.stringify(result)}`)

            if (!result.matched_pole_id || result.confidence < 0.6) {
                this.logger.warn(`No confident match found (confidence: ${result.confidence}). Reason: ${result.reason}`)
                return null
            }

            this.logger.log(`Matched pole_id=${result.matched_pole_id} with confidence=${result.confidence}`)
            return result.matched_pole_id

        } catch (error) {
            this.logger.error(`AI landmark matching failed: ${error.message}`)
            return null
        }
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
