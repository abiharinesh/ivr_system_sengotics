import { Injectable, Logger } from '@nestjs/common'
import OpenAI from 'openai'
import { ConfigService } from '@nestjs/config'

/** Maximum time (ms) to wait for audio download from Exotel. */
const AUDIO_FETCH_TIMEOUT_MS = 30_000

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

    async transcribeAudio(audioUrl: string, retryCount = 0): Promise<string> {
        this.logger.log(`Transcribing audio from: ${audioUrl}${retryCount > 0 ? ` (retry #${retryCount})` : ''}`)

        const headers: Record<string, string> = {}

        // Exotel recording URLs require HTTP Basic Auth to download.
        const exotelApiKey = this.configService.get<string>('EXOTEL_API_KEY')
        const exotelApiToken = this.configService.get<string>('EXOTEL_API_TOKEN')

        if (exotelApiKey && exotelApiToken && audioUrl.includes('exotel')) {
            const credentials = Buffer.from(`${exotelApiKey}:${exotelApiToken}`).toString('base64')
            headers['Authorization'] = `Basic ${credentials}`
            if (retryCount === 0) this.logger.log('Using Exotel Basic Auth for recording download')
        } else if (!exotelApiKey || !exotelApiToken) {
            if (retryCount === 0) this.logger.warn('EXOTEL_API_KEY or EXOTEL_API_TOKEN not set — fetching without auth (may fail)')
        }

        try {
            // Fetch with timeout to prevent indefinite hangs
            const controller = new AbortController()
            const timeout = setTimeout(() => controller.abort(), AUDIO_FETCH_TIMEOUT_MS)

            let response: Response
            try {
                response = await fetch(audioUrl, { headers, signal: controller.signal })
            } finally {
                clearTimeout(timeout)
            }

            if (!response.ok) {
                throw new Error(
                    `Failed to fetch audio: HTTP ${response.status} ${response.statusText} from ${audioUrl}`
                )
            }

            const audioBlob = await response.blob()

            if (audioBlob.size === 0) {
                throw new Error(`Audio file is empty (0 bytes) from ${audioUrl}`)
            }

            this.logger.log(`Audio downloaded: ${audioBlob.size} bytes`)

            const audioFile = new File([audioBlob], 'audio.mp3', { type: 'audio/mpeg' })

            const transcription = await this.openai.audio.transcriptions.create({
                file: audioFile,
                model: 'whisper-large-v3',
                prompt: 'Tamil complaint about electric pole, street light, power cut, landmarks, temple, bus stand, school, hospital',
            })

            const text = transcription.text?.trim() ?? ''

            if (!text) {
                this.logger.warn('Whisper returned empty transcription')
            } else {
                this.logger.log(`Transcription completed: ${text}`)
            }

            return text

        } catch (error) {
            const errMessage = (error as Error).message ?? String(error)
            const isRetryable = errMessage.includes('429') || errMessage.includes('503')
                || errMessage.includes('abort') || errMessage.includes('ECONNRESET')
                || errMessage.includes('502')

            if (isRetryable && retryCount < 1) {
                const delay = 3000
                this.logger.warn(`Transcription failed (${errMessage}). Retrying in ${delay}ms...`)
                await new Promise(resolve => setTimeout(resolve, delay))
                return this.transcribeAudio(audioUrl, retryCount + 1)
            }

            if (errMessage.includes('abort')) {
                this.logger.error(`Audio fetch timed out after ${AUDIO_FETCH_TIMEOUT_MS}ms: ${audioUrl}`)
                throw new Error(`Audio download timed out after ${AUDIO_FETCH_TIMEOUT_MS / 1000}s`)
            }

            this.logger.error(`Transcription failed: ${errMessage}`)
            throw error
        }
    }
}
