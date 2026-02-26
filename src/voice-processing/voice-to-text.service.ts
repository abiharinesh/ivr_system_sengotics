import { Injectable, Logger } from '@nestjs/common'
import OpenAI from 'openai'
import { ConfigService } from '@nestjs/config'

@Injectable()
export class VoiceToTextService {
    private readonly logger = new Logger(VoiceToTextService.name)
    private openai: OpenAI

    constructor(private configService: ConfigService) {
        const apiKey = this.configService.get<string>('GROQ_API_KEY')

        if (!apiKey) {
            this.logger.warn('GROQ_API_KEY is not defined. Voice transcription features will not work.')
        }

        this.openai = new OpenAI({
            apiKey: apiKey || 'dummy-key',
            baseURL: 'https://api.groq.com/openai/v1',
        })
    }

    async transcribeAudio(audioUrl: string): Promise<string> {
        this.logger.log(`Transcribing audio from: ${audioUrl}`)

        // Exotel recording URLs require HTTP Basic Auth to download.
        // Credentials: EXOTEL_API_KEY : EXOTEL_API_TOKEN
        const exotelApiKey = this.configService.get<string>('EXOTEL_API_KEY')
        const exotelApiToken = this.configService.get<string>('EXOTEL_API_TOKEN')

        const headers: Record<string, string> = {}

        if (exotelApiKey && exotelApiToken && audioUrl.includes('exotel')) {
            const credentials = Buffer.from(`${exotelApiKey}:${exotelApiToken}`).toString('base64')
            headers['Authorization'] = `Basic ${credentials}`
            this.logger.log('Using Exotel Basic Auth for recording download')
        } else if (!exotelApiKey || !exotelApiToken) {
            this.logger.warn('EXOTEL_API_KEY or EXOTEL_API_TOKEN not set — fetching without auth (may fail)')
        }

        try {
            const response = await fetch(audioUrl, { headers })

            if (!response.ok) {
                throw new Error(`Failed to fetch audio: HTTP ${response.status} ${response.statusText} from ${audioUrl}`)
            }

            const audioBlob = await response.blob()
            const audioFile = new File([audioBlob], 'audio.mp3', { type: 'audio/mpeg' })

            const transcription = await this.openai.audio.transcriptions.create({
                file: audioFile,
                model: 'whisper-large-v3',
                language: 'ta',   // Tamil hint for better accuracy
            })

            this.logger.log(`Transcription completed: ${transcription.text}`)
            return transcription.text

        } catch (error) {
            this.logger.error(`Transcription failed: ${error.message}`)
            throw error
        }
    }
}
