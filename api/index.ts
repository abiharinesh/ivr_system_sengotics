import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { ExpressAdapter } from '@nestjs/platform-express'
import { AppModule } from '../src/app.module'
import express from 'express'

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
    cachedApp = app
    return app
}

export default async (req: any, res: any) => {
    // Add CORS headers explicitly
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, PATCH, DELETE, POST, PUT');
    res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');

    // Handle preflight requests
    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    await bootstrap()
    server(req, res)
}
