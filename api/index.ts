import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { ExpressAdapter } from '@nestjs/platform-express'
import { AppModule } from '../src/app.module'
import { VoiceProcessingService } from '../src/voice-processing/voice-processing.service'
import { DbSetupService } from '../src/prisma/db-setup.service'
import express from 'express'
import { waitUntil } from '@vercel/functions'

const server = express()

let cachedApp: any

async function bootstrap() {
    if (cachedApp) return cachedApp

    const app = await NestFactory.create(AppModule, new ExpressAdapter(server))

    app.enableCors()

    app.useGlobalPipes(new ValidationPipe({
        whitelist: false,
        forbidNonWhitelisted: false,
        transform: true,
        disableErrorMessages: false
    }))

    try {
        await app.init()
    } catch (err) {
        console.error('NestFactory init failed:', err)
        throw err
    }

    // Run DB bootstrap in background with timeout to prevent cold start failures
    const dbSetupService = app.get(DbSetupService)
    Promise.race([
        dbSetupService.bootstrapDb(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('DB bootstrap timeout')), 8000))
    ]).catch(err => {
        console.warn('DB bootstrap failed (non-fatal):', err.message)
    })
    
    cachedApp = app
    return app
}

export default async (req: any, res: any) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, PATCH, DELETE, POST, PUT');
    res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');

    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    // Browsers request a favicon by default; avoid noisy 404 logs on Vercel.
    if (req.method === 'GET' && (req.url === '/favicon.ico' || req.url === '/favicon.png')) {
        res.status(204).end()
        return
    }

    try {
        const app = await bootstrap()

        const originalEnd = res.end.bind(res)
        res.end = function (...args: any[]) {
            waitUntil(
                (async () => {
                    try {
                        const voiceService = app.get(VoiceProcessingService)
                        await voiceService.processPendingPhase2Llm(5)
                    } catch (_) {}
                })()
            )
            return originalEnd(...args)
        }

        server(req, res)
    } catch (error) {
        console.error('Request handler error:', error)
        res.status(500).json({ error: 'Internal server error', message: error instanceof Error ? error.message : String(error) })
    }
}

export const config = {
    supportsResponseStreaming: true,
}
