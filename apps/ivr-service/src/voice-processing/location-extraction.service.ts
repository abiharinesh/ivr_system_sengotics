import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { PrismaService } from '@app/shared'
import OpenAI from 'openai'
import { GoogleGenerativeAI } from '@google/generative-ai'

export interface ExtractedLocation {
    village: string
    landmark: string
    landmark_english: string
    direction: string
    complaint_type: string
    call_summary: string
    caller_language: string
    caller_emotion: string
    urgency_level: string
    confidence_score: number
}

const DEFAULT_PROVIDER = 'gemini'

// ── Extraction prompt (shared by both providers) ───────────────────────────────

const EXTRACTION_PROMPT = `You extract location + complaint details from Colloquial Tamil/Tanglish/English voice transcripts about electrical issues in Tamil Nadu villages.
The input will be in Colloquial Tamil (spoken Tamil), Tanglish (romanized Tamil written in English letters), or English. You MUST always translate to English for english fields.

Return JSON only:
{
  "village": "",
  "landmark": "<original text verbatim>",
  "landmark_english": "<English translation of the landmark>",
  "direction": "<near|opposite|under|inside>",
  "complaint_type": "<light pole not working|power cut|wire damage|transformer issue|other>",
  "call_summary": "<1-2 sentence concise English summary of the user's issue and location>",
  "caller_language": "<proper tamil|colloquial/spokentamil|tanglish|english>",
  "caller_emotion": "<calm|angry|panicked|frustrated>",
  "urgency_level": "<high|medium|low>",
  "confidence_score": <0.0-1.0>
}

EXAMPLES:

1. Clear landmark (Tamil):
Input: "Mariamman kovil pakkathula light pole eraiyala"
Output: {"village":"","landmark":"Mariamman kovil pakkathula","landmark_english":"near Mariamman temple","direction":"near","complaint_type":"light pole not working","confidence_score":0.9,"transcript_english":"The light pole near Mariamman temple is not working"}

2. Clear landmark (Tanglish mix):
Input: "bus stand kitta current poguthu"
Output: {"village":"","landmark":"bus stand kitta","landmark_english":"near bus stand","direction":"near","complaint_type":"power cut","confidence_score":0.85,"transcript_english":"There is a power cut near the bus stand"}

3. Vague/no landmark:
Input: "light eraiyala fix pannunga"
Output: {"village":"","landmark":"","landmark_english":"","direction":"","complaint_type":"light pole not working","call_summary":"The street light is not working and needs fixing.","caller_language":"colloquial/spokentamil","caller_emotion":"calm","urgency_level":"medium","confidence_score":0.2}

4. Multiple landmarks:
Input: "school pakkam kovil kitta irukku light illa"
Output: {"village":"","landmark":"school pakkam kovil kitta","landmark_english":"near school, near temple","direction":"near","complaint_type":"light pole not working","call_summary":"The street light near the school and temple is not working.","caller_language":"colloquial/spokentamil","caller_emotion":"calm","urgency_level":"medium","confidence_score":0.8}

5. Person's house as landmark:
Input: "Raman veedu pakkam la light poiduchu"
Output: {"village":"","landmark":"Raman veedu pakkam","landmark_english":"near Raman's house","direction":"near","complaint_type":"light pole not working","call_summary":"There is a power issue near Raman's house.","caller_language":"colloquial/spokentamil","caller_emotion":"calm","urgency_level":"medium","confidence_score":0.6}

6. Garbled/noisy:
Input: "mmm light eriya... kovil..."
Output: {"village":"","landmark":"kovil","landmark_english":"temple","direction":"","complaint_type":"light pole not working","call_summary":"Caller reported a light issue near a temple, but audio was garbled.","caller_language":"colloquial/spokentamil","caller_emotion":"calm","urgency_level":"low","confidence_score":0.3}

7. Pure English:
Input: "The street light near the government school is not working"
Output: {"village":"","landmark":"near the government school","landmark_english":"near the government school","direction":"near","complaint_type":"light pole not working","call_summary":"The street light near the government school is broken.","caller_language":"english","caller_emotion":"calm","urgency_level":"medium","confidence_score":0.9}

RULES:
- Speech-to-Text AIs (like Whisper, Google STT, or RapidAPI) often make spelling mistakes in Tamil script (e.g. "ஆரியப்பத் கோவிலிட்ட இங்கிரலையிட்" actually means "மாரியம்மன் கோயில் பக்கத்துல" -> "near Mariamman temple"). You MUST sound out the Tamil words phonetically and map them to logical electrical landmarks.
- The transcript will be in Colloquial Tamil, Tanglish (romanized Tamil), or English — these are the ONLY supported languages
- "landmark" = verbatim from transcript
- "landmark_english" = always English translation
- If no landmark is identifiable, set confidence_score below 0.3
- If transcript is garbled but has partial words, extract what you can
- NEVER make up landmarks — only extract what the caller actually said\``

@Injectable()
export class LocationExtractionService {
    private readonly logger = new Logger(LocationExtractionService.name)

    // GROQ client (LLaMA)
    private openai: OpenAI
    // Gemini client
    private genAI: GoogleGenerativeAI

    constructor(
        private configService: ConfigService,
        private prisma: PrismaService
    ) {
        this.openai = new OpenAI({
            apiKey: this.configService.get<string>('GROQ_API_KEY') || 'dummy-key',
            baseURL: 'https://api.groq.com/openai/v1',
        })
        this.genAI = new GoogleGenerativeAI(
            this.configService.get<string>('GOOGLE_API_KEY') || 'dummy-key'
        )
    }

    private async getProvider(): Promise<string> {
        try {
            const setting = await this.prisma.systemSettings.findUnique({
                where: { key: 'llm_provider' }
            })
            return setting?.value ?? DEFAULT_PROVIDER
        } catch {
            return DEFAULT_PROVIDER
        }
    }

    async extractLocation(transcript: string, knownLandmarks?: string[]): Promise<ExtractedLocation> {
        this.logger.log(`Extracting location from: "${transcript}"`)
        if (knownLandmarks?.length) {
            this.logger.log(`Known landmarks provided: [${knownLandmarks.join(', ')}]`)
        }

        if (!transcript || transcript.trim().length === 0) {
            this.logger.warn('Empty transcript — returning defaults')
            return this.defaultExtraction(transcript)
        }

        try {
            const result = await this.callWithRetry(transcript.trim(), knownLandmarks)

            if (!result.landmark_english && result.landmark) {
                result.landmark_english = result.landmark
            }
            if (!result.call_summary) {
                result.call_summary = transcript
            }

            return result

        } catch (error) {
            const msg = (error as Error).message ?? String(error)
            this.logger.error(`Location extraction failed: ${msg}`)
            // Return a safe default so the pipeline can fall back to manual review
            return this.defaultExtraction(transcript)
        }
    }

    private async callWithRetry(cleanedTranscript: string, knownLandmarks?: string[], retryCount = 0): Promise<ExtractedLocation> {
        try {
            let userMessage = cleanedTranscript
            if (knownLandmarks && knownLandmarks.length > 0) {
                userMessage += `\n\nKNOWN LANDMARKS IN THIS AREA (from database — match the transcript to one of these if possible):\n${knownLandmarks.map(l => `- ${l}`).join('\n')}`
            }

            const provider = await this.getProvider()
            this.logger.log(`[LLM:${provider}] Extracting location`)

            let raw: string

            if (provider === 'groq') {
                raw = await this.extractWithGroq(userMessage)
            } else {
                raw = await this.extractWithGemini(userMessage)
            }

            let extracted: Record<string, any>
            try {
                extracted = JSON.parse(raw)
            } catch {
                this.logger.error(`AI returned invalid JSON: ${raw}`)
                return this.defaultExtraction(cleanedTranscript)
            }

            this.logger.log(`Extraction: ${JSON.stringify(extracted)}`)

            return {
                village: String(extracted.village ?? ''),
                landmark: String(extracted.landmark ?? ''),
                landmark_english: String(extracted.landmark_english ?? ''),
                direction: String(extracted.direction ?? ''),
                complaint_type: String(extracted.complaint_type ?? 'other'),
                call_summary: String(extracted.call_summary ?? cleanedTranscript),
                caller_language: String(extracted.caller_language ?? 'unknown'),
                caller_emotion: String(extracted.caller_emotion ?? 'calm'),
                urgency_level: String(extracted.urgency_level ?? 'medium'),
                confidence_score: this.clampConfidence(extracted.confidence_score)
            }

        } catch (error) {
            const msg = (error as Error).message ?? String(error)
            const isRetryable = msg.includes('429') || msg.includes('503') || msg.includes('abort')
                || msg.includes('ECONNRESET') || msg.includes('RESOURCE_EXHAUSTED')

            if (isRetryable && retryCount < 1) {
                const delay = 2000 * (retryCount + 1)
                this.logger.warn(`Retryable error (${msg}). Retrying in ${delay}ms...`)
                await new Promise(resolve => setTimeout(resolve, delay))
                return this.callWithRetry(cleanedTranscript, knownLandmarks, retryCount + 1)
            }

            throw error
        }
    }

    // ── GROQ (LLaMA) ────────────────────────────────────────────────────────

    private async extractWithGroq(userMessage: string): Promise<string> {
        const controller = new AbortController()
        const timeout = setTimeout(() => controller.abort(), 10_000)

        try {
            const response = await this.openai.chat.completions.create(
                {
                    model: 'llama-3.3-70b-versatile',
                    temperature: 0.1,
                    max_tokens: 300,
                    response_format: { type: 'json_object' },
                    messages: [
                        { role: 'system', content: EXTRACTION_PROMPT },
                        { role: 'user', content: userMessage }
                    ]
                },
                { signal: controller.signal }
            )
            return response.choices[0]?.message?.content || '{}'
        } finally {
            clearTimeout(timeout)
        }
    }

    // ── Google Gemini ────────────────────────────────────────────────────────

    private async extractWithGemini(userMessage: string): Promise<string> {
        const model = this.genAI.getGenerativeModel({
            model: 'gemini-2.0-flash',
            generationConfig: {
                temperature: 0.1,
                maxOutputTokens: 300,
                responseMimeType: 'application/json',
            },
        })

        const promise = model.generateContent([
            { text: EXTRACTION_PROMPT },
            { text: userMessage }
        ])

        const timeout = new Promise<any>((_, reject) => setTimeout(() => reject(new Error('Gemini extraction timed out')), 15000))
        const result = await Promise.race([promise, timeout])

        return result.response.text() || '{}'
    }

    private clampConfidence(value: unknown): number {
        const num = Number(value)
        if (isNaN(num)) return 0.5
        return Math.max(0, Math.min(1, num))
    }

    private defaultExtraction(transcript: string): ExtractedLocation {
        return {
            village: '',
            landmark: '',
            landmark_english: '',
            direction: '',
            complaint_type: 'other',
            call_summary: transcript || 'Could not parse audio.',
            caller_language: 'unknown',
            caller_emotion: 'calm',
            urgency_level: 'low',
            confidence_score: 0.1
        }
    }
}

