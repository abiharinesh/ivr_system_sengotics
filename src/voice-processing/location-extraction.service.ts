import { Injectable, Logger } from '@nestjs/common'
import OpenAI from 'openai'
import { ConfigService } from '@nestjs/config'

export interface ExtractedLocation {
    village: string
    landmark: string            // original landmark phrase (Tamil/Tanglish as-is)
    landmark_english: string    // English translation (for matching)
    direction: string
    complaint_type: string
    confidence_score: number
    transcript_english: string  // full English translation
}

// ── Optimized extraction prompt — compact with edge-case examples ──────────────

const EXTRACTION_PROMPT = `You extract location + complaint from Colloquial Tamil/Tanglish/English voice transcripts about electrical issues in Tamil Nadu villages.
The input will be in Colloquial Tamil (spoken Tamil), Tanglish (romanized Tamil written in English letters), or English. You MUST always translate to English.

Return JSON only:
{"village":"","landmark":"<original text verbatim>","landmark_english":"<English translation>","direction":"","complaint_type":"<light pole not working|power cut|wire damage|transformer issue|other>","confidence_score":<0.0-1.0>,"transcript_english":"<full English translation>"}

Tamil→English dictionary & Phonetic Corrections (Whisper often mishears Tamil):
- "மாரியம்மன்" (Mariamman) is often misheard as "ஆரியப்பத்", "மாரியம்மன்", "மாரியப்பன்"
- "கோயில் / கோவில்" (Temple) is often misheard as "கோவிலிட்ட", "கோவிலில்", "கோவில்"
- "பக்கத்துல / கிட்ட" (Near) is often misheard as "பக்கத்துல", "கிட்ட", "இங்கிரலையிட்", "இட்ட"
- general mappings: kovil/koil/koyil=temple, pallivasal/masjid=mosque, palli/pallikoodam=school, kulam=pond, kadai=shop, aalamaram=banyan tree, maram=tree, pakkathula/pakkam/kitta=near, ethirla=opposite, keezha=under, ration kadai=ration shop, thanni tank=water tank, aaspatri/aspathri=hospital, petrol bunk=petrol pump, bus stand/bus stop=bus stand, veedu=house, theru=street, road=road, bridge=bridge, junction=junction

EXAMPLES:

1. Clear landmark (Tamil):
Input: "Mariamman kovil pakkathula light pole eraiyala"
Output: {"village":"","landmark":"Mariamman kovil pakkathula","landmark_english":"near Mariamman temple","direction":"near","complaint_type":"light pole not working","confidence_score":0.9,"transcript_english":"The light pole near Mariamman temple is not working"}

2. Clear landmark (Tanglish mix):
Input: "bus stand kitta current poguthu"
Output: {"village":"","landmark":"bus stand kitta","landmark_english":"near bus stand","direction":"near","complaint_type":"power cut","confidence_score":0.85,"transcript_english":"There is a power cut near the bus stand"}

3. Vague/no landmark:
Input: "light eraiyala fix pannunga"
Output: {"village":"","landmark":"","landmark_english":"","direction":"","complaint_type":"light pole not working","confidence_score":0.2,"transcript_english":"The light is not working, please fix it"}

4. Multiple landmarks:
Input: "school pakkam kovil kitta irukku light illa"
Output: {"village":"","landmark":"school pakkam kovil kitta","landmark_english":"near school, near temple","direction":"near","complaint_type":"light pole not working","confidence_score":0.8,"transcript_english":"The light near the school, close to the temple, is not working"}

5. Person's house as landmark:
Input: "Raman veedu pakkam la light poiduchu"
Output: {"village":"","landmark":"Raman veedu pakkam","landmark_english":"near Raman's house","direction":"near","complaint_type":"light pole not working","confidence_score":0.6,"transcript_english":"The light near Raman's house is gone"}

6. Garbled/noisy:
Input: "mmm light eriya... kovil..."
Output: {"village":"","landmark":"kovil","landmark_english":"temple","direction":"","complaint_type":"light pole not working","confidence_score":0.3,"transcript_english":"Light not working... temple..."}

7. Pure English:
Input: "The street light near the government school is not working"
Output: {"village":"","landmark":"near the government school","landmark_english":"near the government school","direction":"near","complaint_type":"light pole not working","confidence_score":0.9,"transcript_english":"The street light near the government school is not working"}

RULES:
- Whisper AI often makes spelling mistakes in Tamil script (e.g. "ஆரியப்பத் கோவிலிட்ட இங்கிரலையிட்" actually means "மாரியம்மன் கோயில் பக்கத்துல" -> "near Mariamman temple"). You MUST sound out the Tamil words phonetically and map them to logical electrical landmarks.
- The transcript will be in Colloquial Tamil, Tanglish (romanized Tamil), or English — these are the ONLY supported languages
- ALWAYS provide "transcript_english" as a proper English translation — NEVER copy Tamil/Tanglish text as-is
- "landmark" = verbatim from transcript
- "landmark_english" = always English translation
- If no landmark is identifiable, set confidence_score below 0.3
- If transcript is garbled but has partial words, extract what you can
- NEVER make up landmarks — only extract what the caller actually said`

@Injectable()
export class LocationExtractionService {
    private readonly logger = new Logger(LocationExtractionService.name)
    private openai: OpenAI

    constructor(private configService: ConfigService) {
        this.openai = new OpenAI({
            apiKey: this.configService.get<string>('GROQ_API_KEY') || 'dummy-key',
            baseURL: 'https://api.groq.com/openai/v1',
        })
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
            // Pass raw transcript to LLM — the AI is smart enough to handle
            // filler words and Tamil particles without pre-filtering
            const result = await this.callWithRetry(transcript.trim(), knownLandmarks)

            // Ensure landmark_english always has a value
            if (!result.landmark_english && result.landmark) {
                result.landmark_english = result.landmark
            }
            if (!result.transcript_english) {
                result.transcript_english = transcript
            }

            return result

        } catch (error) {
            const msg = (error as Error).message ?? String(error)
            this.logger.error(`Location extraction failed: ${msg}`)
            throw error
        }
    }

    /**
     * Call LLM with 1 retry on transient errors (429, 503, timeout).
     */
    private async callWithRetry(cleanedTranscript: string, knownLandmarks?: string[], retryCount = 0): Promise<ExtractedLocation> {
        try {
            const controller = new AbortController()
            const timeout = setTimeout(() => controller.abort(), 10_000)

            // Build user message with optional landmark context
            let userMessage = cleanedTranscript
            if (knownLandmarks && knownLandmarks.length > 0) {
                userMessage += `\n\nKNOWN LANDMARKS IN THIS AREA (from database — match the transcript to one of these if possible):\n${knownLandmarks.map(l => `- ${l}`).join('\n')}`
            }

            let response: OpenAI.Chat.Completions.ChatCompletion
            try {
                response = await this.openai.chat.completions.create(
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
            } finally {
                clearTimeout(timeout)
            }

            const raw = response.choices[0]?.message?.content || '{}'
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
                confidence_score: this.clampConfidence(extracted.confidence_score),
                transcript_english: String(extracted.transcript_english ?? cleanedTranscript),
            }

        } catch (error) {
            const msg = (error as Error).message ?? String(error)
            const isRetryable = msg.includes('429') || msg.includes('503') || msg.includes('abort') || msg.includes('ECONNRESET')

            if (isRetryable && retryCount < 1) {
                const delay = 2000 * (retryCount + 1) // 2s backoff
                this.logger.warn(`Retryable error (${msg}). Retrying in ${delay}ms...`)
                await new Promise(resolve => setTimeout(resolve, delay))
                return this.callWithRetry(cleanedTranscript, knownLandmarks, retryCount + 1)
            }

            throw error
        }
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
            confidence_score: 0.1,
            transcript_english: transcript || '',
        }
    }
}
