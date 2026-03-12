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

    await app.init()
    // Keep serverless startup schema checks aligned with local bootstrap.
    const dbSetupService = app.get(DbSetupService)
    await dbSetupService.bootstrapDb()
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
}

export const config = {
    supportsResponseStreaming: true,
}
