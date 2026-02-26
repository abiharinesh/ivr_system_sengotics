import { Injectable, Logger } from '@nestjs/common'
import OpenAI from 'openai'
import { ConfigService } from '@nestjs/config'

export interface ExtractedLocation {
    village: string
    landmark: string
    direction: string
    complaint_type: string
    confidence_score: number
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
        this.logger.log(`Extracting location from transcript: ${transcript}`)

        const systemPrompt = `You are a location extraction engine for electrical complaints in Tamil Nadu, India.
Extract structured information from complaint text in Tamil or English.
Return strictly JSON format with these fields:
{
  "village": "name of the village or panchayat mentioned (or empty string if none)",
  "landmark": "Capture the ENTIRE phrase used to describe the location verbatim (e.g. 'கோயிலுக்கு பக்கத்தில இருக்குற' or 'near Mariamman temple'). Do not summarize or cut words out. Translate to English IF and ONLY IF you are absolutely certain of the meaning, otherwise leave it in the original language.",
  "direction": "any directional hint (left side, right side, opposite, etc.)",
  "complaint_type": "type of complaint, one of: light pole not working, power cut, wire damage, transformer issue, other",
  "confidence_score": 0.0 to 1.0 (0.9 if clear landmark is mentioned, 0.3 if very vague)
}

Rules:
- Capture the landmark phrase VERBATIM to avoid losing context.
- If multiple landmarks are mentioned, capture the whole connected phrase.
- If unable to extract a field, use empty string.`

        try {
            const response = await this.openai.chat.completions.create({
                model: 'llama-3.3-70b-versatile',
                temperature: 0.1,
                response_format: { type: 'json_object' },
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: `Extract from this complaint: "${transcript}"` }
                ]
            })

            const extracted = JSON.parse(response.choices[0].message.content || '{}')
            this.logger.log(`Extraction completed: ${JSON.stringify(extracted)}`)
            return extracted
        } catch (error) {
            this.logger.error(`Location extraction failed: ${error.message}`)
            throw error
        }
    }
}
