import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { ExpressAdapter } from '@nestjs/platform-express'
import express from 'express'

const server = express()
let cachedApp: any

async function bootstrap() {
    if (cachedApp) return cachedApp
    // Dynamically import the required module
    const { QuotationServiceModule } = await import('../apps/quotation-service/src/quotation-service.module')
    const app = await NestFactory.create(QuotationServiceModule, new ExpressAdapter(server))
    app.enableCors()
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }))
    await app.init()
    cachedApp = app
    return app
}

export default async (req: any, res: any) => {
    // Add Vercel CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, PATCH, DELETE, POST, PUT');
    res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');
    if (req.method === 'OPTIONS') { res.status(200).end(); return; }

    await bootstrap()
    server(req, res)
}
