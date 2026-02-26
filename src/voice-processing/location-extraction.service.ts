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
            apiKey: this.configService.get<string>('OPENAI_API_KEY')
        })
    }

    async extractLocation(transcript: string): Promise<ExtractedLocation> {
        this.logger.log(`Extracting location from transcript: ${transcript}`)

        const systemPrompt = `You are a location extraction engine for electrical complaints in Tamil Nadu, India.
Extract structured information from complaint text in Tamil or English.
Return strictly JSON format with these fields:
{
  "village": "name of the village or panchayat mentioned (translate to English if Tamil)",
  "landmark": "the most descriptive landmark phrase used to describe the pole location (e.g. 'near Mariamman temple', 'opposite the school gate', 'beside the ration shop'). Be as specific and verbatim as possible. Translate to English if needed.",
  "direction": "any directional hint (left side, right side, opposite, etc.)",
  "complaint_type": "type of complaint, one of: light pole not working, power cut, wire damage, transformer issue, other",
  "confidence_score": 0.0 to 1.0
}

Rules:
- Extract the landmark VERBATIM from the complaint, then translate to English if it was in Tamil.
- If multiple landmarks are mentioned, pick the most specific one.
- Confidence score should reflect how clearly the location was described (low if only a village name, high if a specific landmark is mentioned).
- If unable to extract a field, use empty string.`

        try {
            const response = await this.openai.chat.completions.create({
                model: 'gpt-4o-mini',
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
