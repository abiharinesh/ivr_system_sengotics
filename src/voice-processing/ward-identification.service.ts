import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { VoiceToTextService } from './voice-to-text.service';
import { GoogleGenerativeAI } from '@google/generative-ai';
import OpenAI from 'openai';

// ── Ward Identification Prompt ────────────────────────────────────────────────

const WARD_IDENTIFY_PROMPT = `You identify which ward (1-33) of Mettupalayam municipality the caller is referring to.

The caller may say:
- A ward number directly: "ward 5", "5", "ainthu" (Tamil for five)
- A ward name or area name: "bus stand area", "karamadai road"
- A landmark or place that belongs to a ward: "railway station pakkam", "hospital road"
- Tamil/Tanglish: "ஐந்தாவது வார்டு", "bus stand pakkathu ward"

Tamil number words: onnu/ondru=1, rendu/irandu=2, moonu/mundru=3, naalu/nangu=4, anju/ainthu=5,
aaru=6, ezhu=7, ettu=8, ombathu=9, pathu=10, pathinonnu=11, pannirandu=12, pathimoonu=13,
pathinaalu=14, pathinanju=15, pathinaaru=16, pathineezhu=17, pathinettu=18, pathonbathu=19,
iruvathu=20, iruvathu onnu=21, iruvathu rendu=22, iruvathu moonu=23, iruvathu naalu=24,
iruvathu anju=25, iruvathu aaru=26, iruvathu ezhu=27, iruvathu ettu=28, iruvathu ombathu=29,
muppathu=30, muppathu onnu=31, muppathu rendu=32, muppathu moonu=33

INPUT: Caller's transcribed speech + list of wards with names and aliases
OUTPUT: JSON → {"ward_number": <1-33|null>, "confidence": <0.0-1.0>, "reason": "<brief>"}

RULES:
1. If the caller says a number (in any language), match it directly to a ward.
2. If the caller says a place name, match it to the ward whose name or aliases match.
3. If the caller says something ambiguous that could match multiple wards, return the best match with lower confidence.
4. If genuinely no match can be found, return ward_number=null with confidence < 0.3.
5. Speech-to-text may have errors — sound out words phonetically.`;

export interface WardIdentificationResult {
  wardId: number | null;
  wardNumber: number | null;
  wardName: string | null;
  confidence: number;
  transcript: string;
  transcriptEnglish: string;
  reason: string;
}

@Injectable()
export class WardIdentificationService {
  private readonly logger = new Logger(WardIdentificationService.name);
  private openai: OpenAI;
  private genAI: GoogleGenerativeAI;

  constructor(
    private prisma: PrismaService,
    private configService: ConfigService,
    private voiceToText: VoiceToTextService,
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
      return setting?.value ?? 'groq';
    } catch {
      return 'groq';
    }
  }

  /**
   * Main entry point: transcribe audio → identify ward.
   */
  async identifyWardFromAudio(
    audioUrl: string,
    ivrNumber: string,
  ): Promise<WardIdentificationResult> {
    this.logger.log(`[Ward] Identifying ward from audio: ${audioUrl}`);

    // 1. Transcribe the audio
    const transcript = await this.voiceToText.transcribeAudio(audioUrl, 0);
    const transcriptEnglish = transcript
      ? await this.fastTranslateToEnglish(transcript)
      : '';

    this.logger.log(
      `[Ward] Transcript: "${transcript}" → English: "${transcriptEnglish}"`,
    );

    if (!transcript?.trim() && !transcriptEnglish?.trim()) {
      return {
        wardId: null,
        wardNumber: null,
        wardName: null,
        confidence: 0,
        transcript: transcript || '',
        transcriptEnglish: transcriptEnglish || '',
        reason: 'Empty transcript',
      };
    }

    // 2. Find the panchayat/municipality from IVR number
    const orgUnit = await this.prisma.orgUnit.findFirst({
      where: { ivr_number: ivrNumber },
      select: { id: true, name: true },
    });

    // If no org unit found by IVR number, try to find any org unit with wards
    const targetOrgUnit = orgUnit
      ? orgUnit
      : await this.prisma.orgUnit.findFirst({
          where: { wards: { some: {} } },
          select: { id: true, name: true },
        });

    if (!targetOrgUnit) {
      this.logger.warn('[Ward] No org unit with wards found');
      return {
        wardId: null,
        wardNumber: null,
        wardName: null,
        confidence: 0,
        transcript: transcript || '',
        transcriptEnglish: transcriptEnglish || '',
        reason: 'No municipality with wards found',
      };
    }

    // 3. Fetch all wards for this org unit
    const wards = await this.prisma.ward.findMany({
      where: { org_unit_id: targetOrgUnit.id, is_active: true },
      orderBy: { ward_number: 'asc' },
    });

    if (wards.length === 0) {
      this.logger.warn(
        `[Ward] No wards found for org unit ${targetOrgUnit.id}`,
      );
      return {
        wardId: null,
        wardNumber: null,
        wardName: null,
        confidence: 0,
        transcript: transcript || '',
        transcriptEnglish: transcriptEnglish || '',
        reason: 'No wards configured',
      };
    }

    // 4. Try deterministic match first (exact ward number extraction)
    const deterministicResult = this.deterministicWardMatch(
      transcriptEnglish || transcript || '',
      wards,
    );
    if (deterministicResult) {
      this.logger.log(
        `[Ward] ✅ Deterministic match: ward ${deterministicResult.ward_number} (${deterministicResult.name_en})`,
      );
      return {
        wardId: deterministicResult.id,
        wardNumber: deterministicResult.ward_number,
        wardName: deterministicResult.name_en,
        confidence: 0.95,
        transcript: transcript || '',
        transcriptEnglish: transcriptEnglish || '',
        reason: 'Direct number/name match',
      };
    }

    // 5. AI-based ward identification
    return this.aiWardMatch(
      transcript || '',
      transcriptEnglish || '',
      wards,
    );
  }

  /**
   * Deterministic match: extract ward number from transcript directly.
   */
  private deterministicWardMatch(
    text: string,
    wards: Array<{
      id: number;
      ward_number: number;
      name_en: string;
      name_ta: string | null;
      aliases: string[];
    }>,
  ): (typeof wards)[0] | null {
    const lower = text.toLowerCase().trim();

    // Pattern 1: Direct number mention — "ward 5", "ward number 5", "5"
    const numberMatch = lower.match(
      /(?:ward\s*(?:number\s*)?)(\d{1,2})/,
    );
    if (numberMatch) {
      const num = parseInt(numberMatch[1], 10);
      const ward = wards.find((w) => w.ward_number === num);
      if (ward) return ward;
    }

    // Pattern 2: Just a number spoken alone
    const pureNumber = lower.match(/^\s*(\d{1,2})\s*$/);
    if (pureNumber) {
      const num = parseInt(pureNumber[1], 10);
      const ward = wards.find((w) => w.ward_number === num);
      if (ward) return ward;
    }

    // Pattern 3: Tamil number words
    const tamilNumbers: Record<string, number> = {
      onnu: 1, ondru: 1, onru: 1,
      rendu: 2, irandu: 2, randu: 2,
      moonu: 3, mundru: 3, moondru: 3,
      naalu: 4, nangu: 4, naalgu: 4,
      anju: 5, ainthu: 5, aindu: 5,
      aaru: 6, aru: 6,
      ezhu: 7, yezhu: 7, yelu: 7,
      ettu: 8, yettu: 8,
      ombathu: 9, ombodu: 9,
      pathu: 10, paththu: 10,
    };

    for (const [word, num] of Object.entries(tamilNumbers)) {
      if (lower.includes(word)) {
        const ward = wards.find((w) => w.ward_number === num);
        if (ward) return ward;
      }
    }

    // Pattern 4: Match against ward aliases
    for (const ward of wards) {
      for (const alias of ward.aliases) {
        if (
          alias &&
          lower.includes(alias.toLowerCase())
        ) {
          return ward;
        }
      }
      // Also try matching against the ward name
      if (
        ward.name_en &&
        lower.includes(ward.name_en.toLowerCase().replace(/^ward \d+ - /, ''))
      ) {
        return ward;
      }
    }

    return null;
  }

  /**
   * AI-based ward identification using Gemini or GROQ.
   */
  private async aiWardMatch(
    transcript: string,
    transcriptEnglish: string,
    wards: Array<{
      id: number;
      ward_number: number;
      name_en: string;
      name_ta: string | null;
      aliases: string[];
    }>,
  ): Promise<WardIdentificationResult> {
    const wardList = wards.map((w) => ({
      number: w.ward_number,
      name: w.name_en,
      name_ta: w.name_ta,
      aliases: w.aliases,
    }));

    const userMessage = `Caller said: "${transcriptEnglish || transcript}"
${transcript !== transcriptEnglish ? `Original Tamil: "${transcript}"` : ''}

Wards: ${JSON.stringify(wardList)}`;

    try {
      const provider = await this.getProvider();
      this.logger.log(`[Ward AI:${provider}] Identifying ward`);

      let raw: string;

      try {
        if (provider === 'groq') {
          raw = await this.matchWithGroq(userMessage);
        } else {
          raw = await this.matchWithGemini(userMessage);
        }
      } catch (primaryErr) {
        this.logger.warn(
          `[Ward AI] Primary provider '${provider}' failed: ${(primaryErr as Error).message}. Trying fallback...`,
        );
        // Fallback to the other provider
        if (provider === 'groq') {
          raw = await this.matchWithGemini(userMessage);
        } else {
          raw = await this.matchWithGroq(userMessage);
        }
      }

      let result: {
        ward_number: number | null;
        confidence: number;
        reason?: string;
      };

      try {
        result = JSON.parse(raw);
      } catch {
        this.logger.error(`[Ward AI] Invalid JSON: ${raw}`);
        return {
          wardId: null,
          wardNumber: null,
          wardName: null,
          confidence: 0,
          transcript,
          transcriptEnglish,
          reason: 'AI returned invalid JSON',
        };
      }

      this.logger.log(`[Ward AI] Result: ${JSON.stringify(result)}`);

      if (!result.ward_number || (result.confidence ?? 0) < 0.3) {
        return {
          wardId: null,
          wardNumber: null,
          wardName: null,
          confidence: result.confidence ?? 0,
          transcript,
          transcriptEnglish,
          reason: result.reason ?? 'Low confidence',
        };
      }

      const matchedWard = wards.find(
        (w) => w.ward_number === result.ward_number,
      );
      if (!matchedWard) {
        return {
          wardId: null,
          wardNumber: null,
          wardName: null,
          confidence: 0,
          transcript,
          transcriptEnglish,
          reason: `AI returned ward ${result.ward_number} which doesn't exist`,
        };
      }

      this.logger.log(
        `[Ward] ✅ AI matched ward ${matchedWard.ward_number} (${matchedWard.name_en}) confidence=${result.confidence}`,
      );

      return {
        wardId: matchedWard.id,
        wardNumber: matchedWard.ward_number,
        wardName: matchedWard.name_en,
        confidence: result.confidence,
        transcript,
        transcriptEnglish,
        reason: result.reason ?? 'AI match',
      };
    } catch (err) {
      this.logger.error(
        `[Ward AI] Failed: ${(err as Error).message}`,
      );
      return {
        wardId: null,
        wardNumber: null,
        wardName: null,
        confidence: 0,
        transcript,
        transcriptEnglish,
        reason: `AI error: ${(err as Error).message}`,
      };
    }
  }

  private async matchWithGroq(userMessage: string): Promise<string> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);
    try {
      const response = await this.openai.chat.completions.create(
        {
          model: 'openai/gpt-oss-120b',
          temperature: 0.0,
          max_tokens: 150,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: WARD_IDENTIFY_PROMPT },
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

  private async matchWithGemini(userMessage: string): Promise<string> {
    const model = this.genAI.getGenerativeModel({
      model: 'gemini-2.5-flash',
      generationConfig: {
        temperature: 0.0,
        maxOutputTokens: 150,
        responseMimeType: 'application/json',
      },
    });

    const promise = model.generateContent([
      { text: WARD_IDENTIFY_PROMPT },
      { text: userMessage },
    ]);

    const timeout = new Promise<any>((_, reject) =>
      setTimeout(
        () => reject(new Error('Gemini ward identification timed out')),
        15000,
      ),
    );
    const result = await Promise.race([promise, timeout]);
    return result.response.text() || '{}';
  }

  private async fastTranslateToEnglish(text: string): Promise<string> {
    let googleKey = process.env.GOOGLE_SPEECH_API_KEY;
    if (!googleKey) {
      try {
        const setting = await this.prisma.systemSettings.findUnique({
          where: { key: 'google_speech_api_key' },
        });
        googleKey = setting?.value ?? undefined;
      } catch {}
    }
    if (!googleKey) return text;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    try {
      const response = await fetch(
        `https://translation.googleapis.com/language/translate/v2?key=${googleKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ q: text, target: 'en' }),
          signal: controller.signal,
        },
      );
      if (!response.ok) return text;
      const data = await response.json();
      return (
        data?.data?.translations?.[0]?.translatedText
          ?.replace(/&#(\d+);/g, (_: string, dec: number) =>
            String.fromCharCode(dec),
          )
          ?.replace(/&quot;/g, '"')
          ?.replace(/&amp;/g, '&') || text
      );
    } catch {
      return text;
    } finally {
      clearTimeout(timeout);
    }
  }
}
