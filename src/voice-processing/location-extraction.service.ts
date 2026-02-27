import { Injectable, Logger } from '@nestjs/common'
import OpenAI from 'openai'
import { ConfigService } from '@nestjs/config'

export interface ExtractedLocation {
    village: string
    landmark: string            // original landmark phrase (may be Tamil or English)
    landmark_english: string    // English translation of the landmark (for matching)
    direction: string
    complaint_type: string
    confidence_score: number
    transcript_english: string  // full English translation of the complaint
}

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

    async extractLocation(transcript: string): Promise<ExtractedLocation> {
        this.logger.log(`Extracting location from transcript: "${transcript}"`)

        const systemPrompt = `You are a location extraction and translation engine for electrical complaints in Tamil Nadu, India.
The transcript you receive is from Whisper and will be in Tamil (native script or Romanized/Tanglish) or sometimes English.

Your job:
1. Extract structured location and complaint information.
2. ALWAYS provide English translations — both for the landmark AND the full complaint text.

Return strictly JSON with these fields:
{
  "village": "name of the village or panchayat mentioned (or empty string if not mentioned — the system will fill this from the IVR number)",
  "landmark": "The ORIGINAL landmark phrase exactly as it appears in the transcript. Keep it verbatim — Tamil, Tanglish, or English.",
  "landmark_english": "English translation of the landmark. Examples: 'கோயிலுக்கு பக்கத்தில' → 'near the temple', 'pallivasal' → 'mosque', 'bus stand pakkathula' → 'near bus stand'. MUST always be in English.",
  "direction": "any directional hint in English (left side, right side, opposite, beside, near, etc.)",
  "complaint_type": "type of complaint, one of: light pole not working, power cut, wire damage, transformer issue, other",
  "confidence_score": 0.0 to 1.0 (0.9+ if clear landmark is mentioned, 0.3 if very vague),
  "transcript_english": "Complete English translation of the ENTIRE transcript. Translate the full complaint sentence(s) to natural English. Example: 'Thayanur la Mariamman kovil pakathula light pole eraiyala' → 'The light pole near Mariamman temple in Thayanur is not working'."
}

Rules:
- "landmark" = verbatim original text (for admin reference)
- "landmark_english" = always English (for pole matching). Common Tamil: kovil/koil = temple, pallivasal = mosque, palli = school, kulam = pond, kadai = shop, maram = tree, aruge/pakkathula = near, ethire = opposite
- "transcript_english" = translate the FULL complaint to natural English (not just keywords)
- If the transcript is already in English, keep it as-is for landmark and transcript_english
- If multiple landmarks are mentioned, capture the whole connected phrase
- If unable to extract a field, use empty string`

        try {
            const response = await this.openai.chat.completions.create({
                model: 'llama-3.3-70b-versatile',
                temperature: 0.1,
                response_format: { type: 'json_object' },
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: `Extract and translate this complaint transcript: "${transcript}"` }
                ]
            })

            const extracted = JSON.parse(response.choices[0].message.content || '{}')
            this.logger.log(`Extraction result: ${JSON.stringify(extracted)}`)

            // Ensure fallbacks
            if (!extracted.landmark_english && extracted.landmark) {
                extracted.landmark_english = extracted.landmark
            }
            if (!extracted.transcript_english) {
                extracted.transcript_english = transcript  // fallback to original if translation fails
            }

            return extracted
        } catch (error) {
            this.logger.error(`Location extraction failed: ${error.message}`)
            throw error
        }
    }
}
