import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { ConfigService } from '@nestjs/config'
import OpenAI from 'openai'

// ── Helpers ────────────────────────────────────────────────────────────────────

/** Strip diacritics, collapse whitespace, lowercase, remove common filler. */
function normalizeText(text: string): string {
    return text
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')   // strip diacritics
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, ' ')      // keep only alphanumeric + space
        .replace(/\b(the|a|an|in|at|on|of|to|is|near|beside|opposite|next)\b/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
}

/** Returns a 0-1 similarity score between two normalized strings. */
function similarityScore(a: string, b: string): number {
    const na = normalizeText(a)
    const nb = normalizeText(b)

    if (!na || !nb) return 0

    // Exact match
    if (na === nb) return 1.0

    // One contains the other
    if (na.includes(nb) || nb.includes(na)) return 0.9

    // Word-level overlap (Jaccard-like)
    const wordsA = new Set(na.split(' ').filter(Boolean))
    const wordsB = new Set(nb.split(' ').filter(Boolean))
    const intersection = [...wordsA].filter(w => wordsB.has(w))
    const union = new Set([...wordsA, ...wordsB])

    if (union.size === 0) return 0
    return intersection.length / union.size
}

@Injectable()
export class GeoMatchingService {
    private readonly logger = new Logger(GeoMatchingService.name)
    private openai: OpenAI

    constructor(
        private prisma: PrismaService,
        private configService: ConfigService
    ) {
        this.openai = new OpenAI({
            apiKey: this.configService.get<string>('GROQ_API_KEY') || 'dummy-key',
            baseURL: 'https://api.groq.com/openai/v1',
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

        return panchayat?.id ?? null
    }

    async findPanchayatByIvrNumber(ivrNumber: string): Promise<{ id: number; name: string } | null> {
        this.logger.log(`Finding panchayat for IVR number: ${ivrNumber}`)

        const panchayat = await this.prisma.panchayat.findFirst({
            where: { ivr_number: ivrNumber },
            select: { id: true, name: true }
        })

        return panchayat ?? null
    }

    /**
     * Finds the nearest pole for a panchayat using a two-pass approach:
     *   Pass 1 — Deterministic: normalized string comparison against stored landmarks.
     *   Pass 2 — AI Fallback:   semantic landmark matching via Groq LLM.
     * Returns null if no confident match is found.
     */
    async findNearestPole(panchayatId: number, landmarkHint?: string): Promise<number | null> {
        this.logger.log(`Finding pole for panchayat: ${panchayatId}, landmark: "${landmarkHint}"`)

        if (!landmarkHint || landmarkHint.trim() === '') {
            this.logger.warn(`[FAIL] No landmark hint provided — cannot identify specific pole`)
            return null
        }

        // Fetch all poles that have at least one landmark stored
        const poles = await this.prisma.electricPole.findMany({
            where: { panchayat_id: panchayatId }
        })

        if (poles.length === 0) {
            this.logger.warn(`[FAIL] No poles found for panchayat ${panchayatId}`)
            return null
        }

        const polesWithLandmarks = poles.filter(p => p.landmarks && p.landmarks.length > 0)

        if (polesWithLandmarks.length === 0) {
            this.logger.warn(`[FAIL] No poles with landmarks found in panchayat ${panchayatId}`)
            return null
        }

        // ── Pass 1: Deterministic string matching ──────────────────────────────
        const deterministicResult = this.deterministicMatch(landmarkHint, polesWithLandmarks)

        if (deterministicResult) {
            this.logger.log(
                `[PASS] Deterministic match! pole_id=${deterministicResult.poleId}, ` +
                `score=${deterministicResult.score.toFixed(2)}, ` +
                `matched="${deterministicResult.matchedLandmark}"`
            )
            return deterministicResult.poleId
        }
        this.logger.log(`[INFO] No deterministic match — falling back to AI matching`)

        // ── Pass 2: AI semantic matching (fallback) ────────────────────────────
        return this.aiMatch(landmarkHint, polesWithLandmarks)
    }

    /**
     * Pass 1: Compare landmark hint against every stored landmark using
     * normalized string similarity. Returns the best match if score >= 0.5.
     */
    private deterministicMatch(
        landmarkHint: string,
        poles: Array<{ id: number; pole_number: string | null; landmarks: string[] }>
    ): { poleId: number; score: number; matchedLandmark: string } | null {
        let bestMatch: { poleId: number; score: number; matchedLandmark: string } | null = null

        for (const pole of poles) {
            for (const storedLandmark of pole.landmarks) {
                const score = similarityScore(landmarkHint, storedLandmark)

                this.logger.debug(
                    `  Comparing "${landmarkHint}" vs "${storedLandmark}" → score=${score.toFixed(2)}`
                )

                if (score >= 0.5 && (!bestMatch || score > bestMatch.score)) {
                    bestMatch = { poleId: pole.id, score, matchedLandmark: storedLandmark }
                }
            }
        }

        return bestMatch
    }

    /**
     * Pass 2: Send the landmark hint and pole list to the LLM for semantic matching.
     * Used only when deterministic matching fails (ambiguous or differently-worded landmarks).
     */
    private async aiMatch(
        landmarkHint: string,
        poles: Array<{ id: number; pole_number: string | null; landmarks: string[] }>
    ): Promise<number | null> {
        const poleList = poles.map(p => ({
            pole_id: p.id,
            pole_number: p.pole_number,
            landmarks: p.landmarks
        }))

        this.logger.log(`AI matching landmark "${landmarkHint}" against ${poleList.length} poles`)

        try {
            const response = await this.openai.chat.completions.create({
                model: 'llama-3.3-70b-versatile',
                temperature: 0.0,
                response_format: { type: 'json_object' },
                messages: [
                    {
                        role: 'system',
                        content: `You are a highly advanced semantic landmark matching engine for electric poles in Tamil Nadu villages.
You will receive a spoken landmark phrase (often in Tanglish, Tamil, or poor English translation) and a list of electric poles with their known landmarks.
Your EXCLUSIVE job is to find the best matching pole. 

Critical matching rules:
1. SEMANTIC EQUIVALENCE: "kovil" = "temple", "pallivasal" = "mosque", "palli" = "school", "kulam" = "pond", "kanmai" = "lake", "kadai" = "shop", "maram" = "tree", "aruge" = "near", "pakkathil" = "beside", "ethire" = "opposite".
2. PHONETIC/SPELLING VARIATIONS: "mariyamman" = "mariamman", "pillayar" = "vinayagar", "ayyanar" = "aiyanar", "bus stand" = "bus stop".
3. PARTIAL MATCHES: If the caller says "near the big banyan tree" and a pole has "banyan tree", that is a MATCH.
4. If the caller's phrase contains a key entity (like a specific temple name) that exists in a pole's landmarks, SCORE IT HIGHLY (>0.8).

Return ONLY a JSON object in this format:
{
  "matched_pole_id": <number or null>,
  "confidence": <0.0 to 1.0>,
  "reason": "<explain exactly which words matched, e.g. 'Caller said kovil, matched with temple'> "
}

If no pole has a reasonably matching landmark (confidence < 0.5), return matched_pole_id as null.`
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

            const raw = response.choices[0]?.message?.content || '{}'
            let result: { matched_pole_id: number | null; confidence: number; reason?: string }

            try {
                result = JSON.parse(raw)
            } catch {
                this.logger.error(`[FAIL] AI returned invalid JSON: ${raw}`)
                return null
            }

            this.logger.log(`AI match result: ${JSON.stringify(result)}`)

            if (!result.matched_pole_id || (result.confidence ?? 0) < 0.5) {
                this.logger.warn(
                    `[FAIL] AI: No confident match (confidence: ${result.confidence}). ` +
                    `Reason: ${result.reason ?? 'unknown'}`
                )
                return null
            }

            // Verify the matched pole_id actually exists in our pole list
            const validPole = poles.find(p => p.id === result.matched_pole_id)
            if (!validPole) {
                this.logger.error(
                    `[FAIL] AI returned pole_id=${result.matched_pole_id} which doesn't exist in panchayat`
                )
                return null
            }

            this.logger.log(
                `[PASS] AI matched pole_id=${result.matched_pole_id} ` +
                `with confidence=${result.confidence}`
            )
            return result.matched_pole_id

        } catch (error) {
            this.logger.error(`[FAIL] AI landmark matching failed: ${(error as Error).message}`)
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

        try {
            const result = await this.prisma.$queryRaw<Array<{ id: number; distance: number }>>`
                SELECT id, 
                    ST_Distance(
                        location::geography,
                        ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
                    ) as distance
                FROM electric_poles
                WHERE panchayat_id = ${panchayatId}
                    AND location IS NOT NULL
                ORDER BY distance ASC
                LIMIT 1
            `
            return result[0]?.id ?? null
        } catch (error) {
            this.logger.error(`Coordinate-based pole search failed: ${(error as Error).message}`)
            return null
        }
    }
}
