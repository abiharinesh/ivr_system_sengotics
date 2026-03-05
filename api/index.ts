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
    await bootstrap()
    server(req, res)
}
