import { Injectable, Logger } from '@nestjs/common'
import OpenAI from 'openai'
import { ConfigService } from '@nestjs/config'

@Injectable()
export class VoiceToTextService {
    private readonly logger = new Logger(VoiceToTextService.name)
    private openai: OpenAI

    constructor(private configService: ConfigService) {
        const apiKey = this.configService.get<string>('OPENAI_API_KEY')

        if (!apiKey) {
            this.logger.warn('OPENAI_API_KEY is not defined. Voice transcription features will not work.')
        }

        this.openai = new OpenAI({
            apiKey: apiKey || 'dummy-key',
        })
    }

    async transcribeAudio(audioUrl: string): Promise<string> {
        this.logger.log(`Transcribing audio from: ${audioUrl}`)

        try {
            const response = await fetch(audioUrl)

            if (!response.ok) {
                throw new Error(`Failed to fetch audio: HTTP ${response.status} from ${audioUrl}`)
            }

            const audioBlob = await response.blob()
            const audioFile = new File([audioBlob], 'audio.mp3', { type: 'audio/mpeg' })

            const transcription = await this.openai.audio.transcriptions.create({
                file: audioFile,
                model: 'whisper-1',
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
