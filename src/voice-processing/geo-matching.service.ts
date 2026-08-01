import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import OpenAI from 'openai';
import { GoogleGenerativeAI } from '@google/generative-ai';

const DEFAULT_PROVIDER = 'gemini';

// ── Helpers ────────────────────────────────────────────────────────────────────

function normalizeForMatch(text: string): string {
  return text
    .normalize('NFC')
    .toLowerCase()
    .replace(/[^\u0B80-\u0BFFa-z0-9\s]/g, ' ')
    .replace(/\b(the|a|an|in|at|on|of|to|is|and)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function similarityScore(a: string, b: string): number {
  const na = normalizeForMatch(a);
  const nb = normalizeForMatch(b);

  if (!na || !nb) return 0;
  if (na === nb) return 1.0;
  if (na.includes(nb) || nb.includes(na)) return 0.9;

  const wordsA = new Set(na.split(' ').filter(Boolean));
  const wordsB = new Set(nb.split(' ').filter(Boolean));
  const intersection = [...wordsA].filter((w) => wordsB.has(w));
  const union = new Set([...wordsA, ...wordsB]);

  if (union.size === 0) return 0;
  return intersection.length / union.size;
}

// ── AI Matching Prompt (shared by both providers) ──────────────────────────────

const AI_MATCH_PROMPT = `You match a caller's spoken location to an electric pole in a Tamil Nadu village.

INPUT: One or more landmark descriptions (from multiple call attempts) + poles with their known landmarks.
OUTPUT: JSON → {"matched_pole_id":<number|null>,"confidence":<0.0-1.0>,"reason":"<brief explanation>"}

MATCHING RULES:
1. Tamil=English equivalences: kovil/koil=temple, pallivasal=mosque, palli=school, kulam=pond, kadai=shop, maram=tree, aalamaram=banyan tree, pakkathula/pakkam/kitta=near, ethirla=opposite, keezha=under, bus stand=bus stop
2. Phonetic/spelling variants: mariyamman=mariamman, pillayar=vinayagar, bus stand=bus stop, aaspatri=hospital, petrol bunk=petrol pump
3. Partial match is OK: "banyan tree" matches "under the big banyan tree"
4. UNIQUENESS RULE: If the caller says a general category (e.g., "kovil", "school", "kadai") and ONLY ONE pole in the list has that category in its landmarks, MATCH IT with high confidence. Only reject as vague if MULTIPLE poles share the same category.
5. MULTI-ATTEMPT: When multiple descriptions are given, treat them as cumulative clues about the SAME location. Combine all clues to find the best match.
6. Return null + confidence < 0.4 if genuinely no match found.`;

@Injectable()
export class GeoMatchingService {
  private readonly logger = new Logger(GeoMatchingService.name);

  // GROQ client (LLaMA)
  private openai: OpenAI;
  // Gemini client
  private genAI: GoogleGenerativeAI;

  constructor(
    private prisma: PrismaService,
    private configService: ConfigService,
  ) {
    this.openai = new OpenAI({
      apiKey: this.configService.get<string>('GROQ_API_KEY') || 'dummy-key',
      baseURL: 'https://api.groq.com/openai/v1',
    });
    this.genAI = new GoogleGenerativeAI(
      this.configService.get<string>('GEMINI_API_KEY') || 'dummy-key',
    );
  }

  private async getProvider(): Promise<string> {
    try {
      const setting = await this.prisma.systemSettings.findUnique({
        where: { key: 'llm_provider' },
      });
      return setting?.value ?? DEFAULT_PROVIDER;
    } catch {
      return DEFAULT_PROVIDER;
    }
  }

  async findPanchayatByName(villageName: string): Promise<number | null> {
    this.logger.log(`Finding panchayat for village: ${villageName}`);

    const panchayat = await this.prisma.orgUnit.findFirst({
      where: {
        name: {
          equals: villageName,
          mode: 'insensitive',
        },
      },
    });

    return panchayat?.id ?? null;
  }

  async findPanchayatByIvrNumber(
    ivrNumber: string,
  ): Promise<{ id: number; name: string } | null> {
    this.logger.log(`Finding panchayat for IVR number: ${ivrNumber}`);

    const panchayat = await this.prisma.orgUnit.findFirst({
      where: { ivr_number: ivrNumber },
      select: { id: true, name: true },
    });

    return panchayat ?? null;
  }

  async getLandmarksForPanchayat(orgUnitId: number): Promise<string[]> {
    const poles = await this.prisma.electricPole.findMany({
      where: { org_unit_id: orgUnitId },
      select: { landmarks: true },
    });

    const allLandmarks: string[] = [];
    for (const pole of poles) {
      if (pole.landmarks && pole.landmarks.length > 0) {
        allLandmarks.push(...pole.landmarks);
      }
    }

    return [...new Set(allLandmarks)];
  }

  async findNearestPole(
    orgUnitId: number,
    landmarkHints: string | string[],
  ): Promise<number | null> {
    const hints = Array.isArray(landmarkHints)
      ? landmarkHints
      : [landmarkHints];
    const validHints = hints.filter((h) => h && h.trim() !== '');

    this.logger.log(
      `Finding pole for org_unit: ${orgUnitId}, hints (${validHints.length}): [${validHints.join(' | ')}]`,
    );

    if (validHints.length === 0) {
      this.logger.warn(`[FAIL] No landmark hints provided`);
      return null;
    }

    const poles = await this.prisma.electricPole.findMany({
      where: { org_unit_id: orgUnitId },
    });

    if (poles.length === 0) {
      this.logger.warn(`[FAIL] No poles found for panchayat ${orgUnitId}`);
      return null;
    }

    const polesWithLandmarks = poles.filter(
      (p) => p.landmarks && p.landmarks.length > 0,
    );

    if (polesWithLandmarks.length === 0) {
      this.logger.warn(
        `[FAIL] No poles with landmarks found in panchayat ${orgUnitId}`,
      );
      return null;
    }

    // ── Pass 1: Deterministic string matching ────────────────────────────
    for (const hint of validHints) {
      const match = this.deterministicMatch(hint, polesWithLandmarks);
      if (match) {
        this.logger.log(
          `[PASS 1] ✅ String match! pole_id=${match.poleId}, ` +
            `score=${match.score.toFixed(2)}, hint="${hint}", matched="${match.matchedLandmark}"`,
        );
        return match.poleId;
      }
    }

    this.logger.log(
      `[INFO] No string match from ${validHints.length} hints — falling back to AI`,
    );

    // ── Pass 2: AI semantic matching ─────────────────────────────────────
    return this.aiMatchWithRetry(validHints, polesWithLandmarks);
  }

  /**
   * Phase 1 Fast Match: Strict deterministic match without AI usage.
   * Searches known poles in the panchayat for a direct keyword match against the transcript.
   */
  async strictMatchPole(
    orgUnitId: number,
    transcriptEnglish: string,
  ): Promise<number | null> {
    this.logger.log(
      `[Phase 1] Trying strict match for panchayat ${orgUnitId} against transcript`,
    );

    if (!transcriptEnglish || transcriptEnglish.trim() === '') {
      return null;
    }

    const poles = await this.prisma.electricPole.findMany({
      where: { org_unit_id: orgUnitId },
    });

    const polesWithLandmarks = poles.filter(
      (p) => p.landmarks && p.landmarks.length > 0,
    );
    if (polesWithLandmarks.length === 0) return null;

    // Pass the whole transcript to see if any known landmark is mentioned
    const match = this.deterministicMatch(
      transcriptEnglish,
      polesWithLandmarks,
    );
    if (match) {
      this.logger.log(
        `[Phase 1] ✅ Direct DB match: pole_id=${match.poleId}, ` +
          `score=${match.score.toFixed(2)}, matched="${match.matchedLandmark}"`,
      );
      return match.poleId;
    }

    return null;
  }

  private deterministicMatch(
    landmarkHint: string,
    poles: Array<{
      id: number;
      pole_number: string | null;
      landmarks: string[];
    }>,
  ): { poleId: number; score: number; matchedLandmark: string } | null {
    let bestMatch: {
      poleId: number;
      score: number;
      matchedLandmark: string;
    } | null = null;

    for (const pole of poles) {
      for (const storedLandmark of pole.landmarks) {
        const score = similarityScore(landmarkHint, storedLandmark);

        if (score >= 0.4 && (!bestMatch || score > bestMatch.score)) {
          bestMatch = {
            poleId: pole.id,
            score,
            matchedLandmark: storedLandmark,
          };
        }
      }
    }

    return bestMatch;
  }

  private async aiMatchWithRetry(
    landmarkHints: string[],
    poles: Array<{
      id: number;
      pole_number: string | null;
      landmarks: string[];
    }>,
    retryCount = 0,
  ): Promise<number | null> {
    const compactPoles: Record<number, string[]> = {};
    for (const p of poles) {
      compactPoles[p.id] = p.landmarks;
    }

    const userMessage = `Caller described the location across ${landmarkHints.length} attempt(s):\n${landmarkHints.map((h, i) => `  ${i + 1}. "${h}"`).join('\n')}\n\nPoles: ${JSON.stringify(compactPoles)}`;

    this.logger.log(
      `AI matching ${landmarkHints.length} hint(s) against ${poles.length} poles`,
    );

    try {
      const provider = await this.getProvider();
      this.logger.log(`[AI Match:${provider}]`);

      let raw: string;

      if (provider === 'groq') {
        raw = await this.matchWithGroq(userMessage);
      } else {
        raw = await this.matchWithGemini(userMessage);
      }

      let result: {
        matched_pole_id: number | null;
        confidence: number;
        reason?: string;
      };

      try {
        result = JSON.parse(raw);
      } catch {
        this.logger.error(`[FAIL] AI returned invalid JSON: ${raw}`);
        return null;
      }

      this.logger.log(`AI result: ${JSON.stringify(result)}`);

      if (!result.matched_pole_id || (result.confidence ?? 0) < 0.4) {
        this.logger.warn(
          `[FAIL] AI: No confident match (confidence: ${result.confidence}). ` +
            `Reason: ${result.reason ?? 'unknown'}`,
        );
        return null;
      }

      const validPole = poles.find((p) => p.id === result.matched_pole_id);
      if (!validPole) {
        this.logger.error(
          `[FAIL] AI returned pole_id=${result.matched_pole_id} which doesn't exist`,
        );
        return null;
      }

      this.logger.log(
        `[PASS 2] ✅ AI matched pole_id=${result.matched_pole_id} (confidence=${result.confidence})`,
      );
      return result.matched_pole_id;
    } catch (error) {
      const msg = (error as Error).message ?? String(error);
      const isRetryable =
        msg.includes('429') ||
        msg.includes('503') ||
        msg.includes('abort') ||
        msg.includes('ECONNRESET') ||
        msg.includes('RESOURCE_EXHAUSTED');

      if (isRetryable && retryCount < 1) {
        const delay = 2000 * (retryCount + 1);
        this.logger.warn(`Retryable error (${msg}). Retrying in ${delay}ms...`);
        await new Promise((resolve) => setTimeout(resolve, delay));
        return this.aiMatchWithRetry(landmarkHints, poles, retryCount + 1);
      }

      if (msg.includes('abort')) {
        this.logger.error(`[FAIL] AI matching timed out after 10s`);
      } else {
        this.logger.error(`[FAIL] AI matching failed: ${msg}`);
      }
      return null;
    }
  }

  // ── GROQ (LLaMA) ────────────────────────────────────────────────────────

  private async matchWithGroq(userMessage: string): Promise<string> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);

    try {
      const response = await this.openai.chat.completions.create(
        {
          model: 'llama-3.3-70b-versatile',
          temperature: 0.0,
          max_tokens: 150,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: AI_MATCH_PROMPT },
            { role: 'user', content: userMessage },
          ],
        },
        { signal: controller.signal },
      );
      return response.choices[0]?.message?.content || '{}';
    } finally {
      clearTimeout(timeout);
    }
  }

  // ── Google Gemini ────────────────────────────────────────────────────────

  private async matchWithGemini(userMessage: string): Promise<string> {
    const model = this.genAI.getGenerativeModel({
      model: 'gemini-2.0-flash',
      generationConfig: {
        temperature: 0.0,
        maxOutputTokens: 150,
        responseMimeType: 'application/json',
      },
    });

    const promise = model.generateContent([
      { text: AI_MATCH_PROMPT },
      { text: userMessage },
    ]);

    const timeout = new Promise<any>((_, reject) =>
      setTimeout(() => reject(new Error('Gemini match timed out')), 15000),
    );
    const result = await Promise.race([promise, timeout]);

    return result.response.text() || '{}';
  }

  async findNearestPoleByCoordinates(
    orgUnitId: number,
    latitude: number,
    longitude: number,
    radiusMeters: number = 5000,
  ): Promise<number | null> {
    this.logger.log(
      `Finding pole near (${latitude}, ${longitude}) within ${radiusMeters}m`,
    );

    try {
      const result = await this.prisma.$queryRaw<
        Array<{ id: number; distance: number }>
      >`
                SELECT id, 
                    ST_Distance(
                        location::geography,
                        ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
                    ) as distance
                FROM electric_poles
                WHERE org_unit_id = ${orgUnitId}
                    AND location IS NOT NULL
                ORDER BY distance ASC
                LIMIT 1
            `;
      return result[0]?.id ?? null;
    } catch (error) {
      this.logger.error(
        `Coordinate-based pole search failed: ${(error as Error).message}`,
      );
      return null;
    }
  }

  async findNearestPipelineSegment(
    orgUnitId: number,
    landmarkHints: string | string[],
  ): Promise<number | null> {
    const hints = Array.isArray(landmarkHints)
      ? landmarkHints
      : [landmarkHints];
    const validHints = hints.filter((h) => h && h.trim() !== '');

    if (validHints.length === 0) return null;

    const pipelines = await this.prisma.waterPipeline.findMany({
      where: { org_unit_id: orgUnitId },
    });

    if (pipelines.length === 0) return null;

    for (const hint of validHints) {
      const normalizedHint = hint.toLowerCase();
      const match = pipelines.find(
        (p) => p.name && p.name.toLowerCase().includes(normalizedHint),
      );
      if (match) return match.id;
    }

    return pipelines[0].id;
  }

  async findNearestWaterTank(
    orgUnitId: number,
    landmarkHints: string | string[],
  ): Promise<number | null> {
    const hints = Array.isArray(landmarkHints)
      ? landmarkHints
      : [landmarkHints];
    const validHints = hints.filter((h) => h && h.trim() !== '');

    if (validHints.length === 0) return null;

    const tanks = await this.prisma.waterTankBorewell.findMany({
      where: { org_unit_id: orgUnitId },
    });

    if (tanks.length === 0) return null;

    for (const hint of validHints) {
      const normalizedHint = hint.toLowerCase();
      const match = tanks.find((t) =>
        t.name.toLowerCase().includes(normalizedHint),
      );
      if (match) return match.id;
    }

    return tanks[0].id;
  }
}
