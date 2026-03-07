import { Injectable, Logger } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { PrismaService } from '../prisma/prisma.service'
import OpenAI from 'openai'
import { GoogleGenerativeAI } from '@google/generative-ai'
import FormData from 'form-data'

/** Maximum time (ms) to wait for audio download from Exotel. */
const AUDIO_FETCH_TIMEOUT_MS = 30_000

/** Default AI provider if no setting exists in DB */
const DEFAULT_PROVIDER = 'gemini'

@Injectable()
export class VoiceToTextService {
    private readonly logger = new Logger(VoiceToTextService.name)

    // GROQ client (Whisper)
    private openai: OpenAI
    // Gemini client
    private genAI: GoogleGenerativeAI

    constructor(
        private configService: ConfigService,
        private prisma: PrismaService
    ) {
        // Initialize GROQ (OpenAI-compatible)
        const groqKey = this.configService.get<string>('GROQ_API_KEY')
        this.openai = new OpenAI({
            apiKey: groqKey || 'dummy-key',
            baseURL: 'https://api.groq.com/openai/v1',
        })

        // Initialize Gemini
        const googleKey = this.configService.get<string>('GOOGLE_API_KEY')
        this.genAI = new GoogleGenerativeAI(googleKey || 'dummy-key')

        if (!groqKey) this.logger.warn('GROQ_API_KEY not set — GROQ transcription will not work')
        if (!googleKey) this.logger.warn('GOOGLE_API_KEY not set — Gemini transcription will not work')
    }

    /** Read the active STT provider from the database. */
    private async getProvider(): Promise<string> {
        try {
            const setting = await this.prisma.systemSettings.findUnique({
                where: { key: 'stt_provider' }
            })
            return setting?.value ?? DEFAULT_PROVIDER
        } catch {
            return DEFAULT_PROVIDER
        }
    }

    async transcribeAudio(audioUrl: string, retryCount = 0): Promise<string> {
        const provider = await this.getProvider()
        this.logger.log(`[STT:${provider}] Transcribing audio from: ${audioUrl}${retryCount > 0 ? ` (retry #${retryCount})` : ''}`)

        // ── Download audio ───────────────────────────────────────────────────
        const audioBuffer = await this.downloadAudio(audioUrl, retryCount)
        this.logger.log(`Audio downloaded: ${audioBuffer.byteLength} bytes`)

        try {
            // ── Transcribe with selected provider ────────────────────────────
            let text: string

            if (provider === 'groq') {
                text = await this.transcribeWithGroq(audioBuffer)
            } else if (provider === 'rapidapi') {
                text = await this.transcribeWithRapidAPI(audioBuffer)
            } else {
                text = await this.transcribeWithGemini(audioBuffer, audioUrl)
            }

            if (!text) {
                this.logger.warn(`[${provider}] Returned empty transcription`)
                return ''
            }

            // ── Hallucination detection ──────────────────────────────────────
            if (this.isHallucination(text)) {
                this.logger.warn(`Hallucination detected: "${text}"`)
                if (retryCount < 1) {
                    this.logger.log('Retrying transcription after hallucination...')
                    await new Promise(resolve => setTimeout(resolve, 1000))
                    return this.transcribeAudio(audioUrl, retryCount + 1)
                }
                this.logger.warn('Hallucination persists after retry — returning empty')
                return ''
            }

            this.logger.log(`Transcription completed: ${text}`)
            return text

        } catch (error) {
            const errMessage = (error as Error).message ?? String(error)
            const isRetryable = errMessage.includes('429') || errMessage.includes('503')
                || errMessage.includes('abort') || errMessage.includes('ECONNRESET')
                || errMessage.includes('502') || errMessage.includes('RESOURCE_EXHAUSTED')

            if (isRetryable && retryCount < 1) {
                const delay = 3000
                this.logger.warn(`Transcription failed (${errMessage}). Retrying in ${delay}ms...`)
                await new Promise(resolve => setTimeout(resolve, delay))
                return this.transcribeAudio(audioUrl, retryCount + 1)
            }

            this.logger.error(`Transcription failed: ${errMessage}`)
            throw error
        }
    }

    // ── Provider: GROQ (Whisper) ─────────────────────────────────────────────

    private async transcribeWithGroq(audioBuffer: ArrayBuffer): Promise<string> {
        const audioFile = new File([audioBuffer], 'audio.mp3', { type: 'audio/mpeg' })

        const transcription = await this.openai.audio.transcriptions.create({
            file: audioFile,
            model: 'whisper-large-v3',
        })

        return transcription.text?.trim() ?? ''
    }

    // ── Provider: Google Gemini ──────────────────────────────────────────────

    private async transcribeWithGemini(audioBuffer: ArrayBuffer, audioUrl: string): Promise<string> {
        const audioBase64 = Buffer.from(audioBuffer).toString('base64')
        const mimeType = audioUrl.includes('.wav') ? 'audio/wav'
            : audioUrl.includes('.ogg') ? 'audio/ogg'
                : 'audio/mpeg'

        const model = this.genAI.getGenerativeModel({ model: 'gemini-2.0-flash' })

        const result = await model.generateContent([
            {
                inlineData: { mimeType, data: audioBase64 }
            },
            {
                text: `Transcribe this audio recording accurately. The speaker is speaking in Colloquial Tamil (spoken Tamil from Tamil Nadu villages). 
The audio is a voice complaint about electrical/street light issues.
Common words you may hear: kovil (temple), pakkathula/kitta (near), light pole, current, eriyala (not working), bus stand, school, hospital, kadai (shop), theru (street), veedu (house), maram (tree).

IMPORTANT RULES:
- Output ONLY the transcription text, nothing else
- Keep Tamil words as-is in their original romanized/Tamil script form
- Do NOT add any commentary, labels, or explanations
- If the audio is unclear or silent, return an empty string
- Preserve the exact words spoken, including Tanglish (Tamil-English mix)`
            }
        ])

        return result.response.text()?.trim() ?? ''
    }

    // ── Provider: RapidAPI (Speech-to-Text AI) ───────────────────────────────

    private async transcribeWithRapidAPI(audioBuffer: ArrayBuffer): Promise<string> {
        // Read API key from .env first, then fall back to DB
        let rapidApiKey = this.configService.get<string>('RAPIDAPI_KEY')
        if (!rapidApiKey) {
            const keySetting = await this.prisma.systemSettings.findUnique({
                where: { key: 'rapidapi_key' }
            })
            rapidApiKey = keySetting?.value ?? undefined
        }
        if (!rapidApiKey) {
            throw new Error('RapidAPI key not configured. Set RAPIDAPI_KEY in .env or via PUT /api/superadmin/settings/api-keys')
        }

        const form = new FormData()
        form.append('file', Buffer.from(audioBuffer), {
            filename: 'audio.mp3',
            contentType: 'audio/mpeg'
        })

        const controller = new AbortController()
        const timeout = setTimeout(() => controller.abort(), AUDIO_FETCH_TIMEOUT_MS)

        try {
            const response = await fetch('https://speech-to-text-ai.p.rapidapi.com/transcribe', {
                method: 'POST',
                headers: {
                    ...form.getHeaders(),
                    'x-rapidapi-host': 'speech-to-text-ai.p.rapidapi.com',
                    'x-rapidapi-key': rapidApiKey
                },
                body: form as any,
                signal: controller.signal
            })

            if (!response.ok) {
                const errorText = await response.text()
                throw new Error(`RapidAPI Error - ${response.status}: ${errorText}`)
            }

            const data = await response.json()
            return data.text?.trim() ?? ''
        } finally {
            clearTimeout(timeout)
        }
    }

    // ── Audio download ───────────────────────────────────────────────────────

    private async downloadAudio(audioUrl: string, retryCount: number): Promise<ArrayBuffer> {
        const headers: Record<string, string> = {}

        const exotelApiKey = this.configService.get<string>('EXOTEL_API_KEY')
        const exotelApiToken = this.configService.get<string>('EXOTEL_API_TOKEN')

        if (exotelApiKey && exotelApiToken && audioUrl.includes('exotel')) {
            const credentials = Buffer.from(`${exotelApiKey}:${exotelApiToken}`).toString('base64')
            headers['Authorization'] = `Basic ${credentials}`
            if (retryCount === 0) this.logger.log('Using Exotel Basic Auth for recording download')
        } else if (!exotelApiKey || !exotelApiToken) {
            if (retryCount === 0) this.logger.warn('EXOTEL_API_KEY or EXOTEL_API_TOKEN not set — fetching without auth (may fail)')
        }

        const controller = new AbortController()
        const timeout = setTimeout(() => controller.abort(), AUDIO_FETCH_TIMEOUT_MS)

        let response: Response
        try {
            response = await fetch(audioUrl, { headers, signal: controller.signal })
        } finally {
            clearTimeout(timeout)
        }

        if (!response.ok) {
            throw new Error(`Failed to fetch audio: HTTP ${response.status} ${response.statusText} from ${audioUrl}`)
        }

        const buffer = await response.arrayBuffer()
        if (buffer.byteLength === 0) {
            throw new Error(`Audio file is empty (0 bytes) from ${audioUrl}`)
        }

        return buffer
    }

    // ── Hallucination detection ──────────────────────────────────────────────

    private isHallucination(text: string): boolean {
        const lower = text.toLowerCase().trim()

        const HALLUCINATION_PHRASES = [
            '4k audio', 'main role', 'thank you for watching', 'thanks for watching',
            'please subscribe', 'like and subscribe', 'subtitles by', 'transcribed by',
            'translated by', 'music', 'applause', 'laughter', 'you', 'bye', 'the end',
            'silence', 'i cannot transcribe', 'i can\'t transcribe', 'the audio is', 'this audio',
        ]

        if (HALLUCINATION_PHRASES.some(h => lower.includes(h))) return true

        const words = lower.split(/\s+/).filter(Boolean)
        const isAllAscii = /^[a-z0-9\s.,!?'"()-]+$/.test(lower)
        const hasTamilKeywords = /kovil|koil|koyil|pakkam|kitta|maram|kadai|theru|veedu|school|bus|stand|hospital|temple|mosque|church|light|pole|current|wire/i.test(lower)

        if (isAllAscii && words.length <= 4 && !hasTamilKeywords) return true

        return false
    }
}
