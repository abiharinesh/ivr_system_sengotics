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
  "village": "",
  "landmark": "",
  "direction": "",
  "complaint_type": "",
  "confidence_score": 0.0 to 1.0
}

Examples of complaint types: "light pole not working", "power cut", "wire damage", "transformer issue"
If unable to extract a field, use empty string. Confidence score should reflect certainty of extraction.`

        try {
            const response = await this.openai.chat.completions.create({
                model: 'gpt-4o-mini',
                temperature: 0.2,
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
