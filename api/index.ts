// Surface module-load and uncaught errors in Vercel logs *before* anything else.
process.on('uncaughtException', (err) => {
    console.error('[FATAL] uncaughtException:', err)
})
process.on('unhandledRejection', (reason) => {
    console.error('[FATAL] unhandledRejection:', reason)
})

import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { ExpressAdapter } from '@nestjs/platform-express'
import { AppModule } from '../src/app.module'
import { VoiceProcessingService } from '../src/voice-processing/voice-processing.service'
import { DbSetupService } from '../src/prisma/db-setup.service'
import { DocumentStorageService } from '../src/storage/document-storage.service'
import express from 'express'
import { join } from 'path'
import { waitUntil } from '@vercel/functions'

const server = express()
server.use('/docs', express.static(join(process.cwd(), 'docs')))

let cachedApp: any
let bootstrapError: Error | null = null

function assertRequiredEnv() {
    const required = ['DATABASE_URL', 'JWT_SECRET']
    const missing = required.filter((k) => !process.env[k])
    if (missing.length) {
        throw new Error(
            `Missing required environment variables on Vercel: ${missing.join(', ')}. ` +
            `Set them in Project → Settings → Environment Variables and redeploy.`
        )
    }
}

async function bootstrap() {
    if (cachedApp) return cachedApp
    if (bootstrapError) throw bootstrapError

    try {
        assertRequiredEnv()

        const app = await NestFactory.create(AppModule, new ExpressAdapter(server), {
            logger: ['error', 'warn', 'log'],
        })

        app.enableCors()

        app.useGlobalPipes(new ValidationPipe({
            whitelist: false,
            forbidNonWhitelisted: false,
            transform: true,
            disableErrorMessages: false
        }))

        await app.init()

        // On Vercel, only run a quick DB reachability check. Full schema bootstrap
        // (ensureSchema) is slow and was timing out; run that locally or via migrate.
        const dbSetupService = app.get(DbSetupService)
        const bootstrapTask = process.env.VERCEL
            ? dbSetupService.bootstrapDbLite()
            : dbSetupService.bootstrapDb()
        const bootstrapTimeoutMs = process.env.VERCEL ? 10000 : 120000
        Promise.race([
            bootstrapTask,
            new Promise((_, reject) =>
                setTimeout(() => reject(new Error('DB bootstrap timeout')), bootstrapTimeoutMs),
            ),
        ]).catch(err => {
            console.warn('DB bootstrap failed (non-fatal):', err?.message ?? err)
        })

        cachedApp = app
        return app
    } catch (err) {
        console.error('[BOOTSTRAP] failed:', err)
        bootstrapError = err instanceof Error ? err : new Error(String(err))
        throw bootstrapError
    }
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

    // Lightweight health endpoint that doesn't require the Nest app to boot.
    // Lets us confirm the function itself is alive even if Nest fails to init.
    if (req.method === 'GET' && (req.url === '/__health' || req.url === '/api/__health')) {
        let storageTest: any = null
        if (cachedApp) {
            try {
                const storageService = cachedApp.get(DocumentStorageService)
                storageTest = await storageService.testConnection()
            } catch (err: any) {
                storageTest = { ok: false, error: err?.message ?? String(err) }
            }
        }
        res.status(200).json({
            ok: true,
            bootstrapped: Boolean(cachedApp),
            bootstrapError: bootstrapError ? bootstrapError.message : null,
            env: {
                DATABASE_URL: Boolean(process.env.DATABASE_URL),
                JWT_SECRET: Boolean(process.env.JWT_SECRET),
                SUPABASE_URL: Boolean(process.env.SUPABASE_URL),
                SUPABASE_SERVICE_ROLE_KEY: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY),
                SUPABASE_STORAGE_BUCKET: process.env.SUPABASE_STORAGE_BUCKET ?? null,
                GOTENBERG_URL: process.env.GOTENBERG_URL ?? null,
                NODE_ENV: process.env.NODE_ENV ?? null,
            },
            storageTest,
        })
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
        const err = error instanceof Error ? error : new Error(String(error))
        console.error('[HANDLER] error:', err)
        if (!res.headersSent) {
            res.status(500).json({
                error: 'Internal server error',
                message: err.message,
                stack: process.env.VERCEL_ENV !== 'production' ? err.stack : undefined,
            })
        }
    }
}

export const config = {
    supportsResponseStreaming: true,
}
