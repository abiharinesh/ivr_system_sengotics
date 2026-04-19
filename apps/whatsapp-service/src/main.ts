import { NestFactory } from '@nestjs/core'
import { NestExpressApplication } from '@nestjs/platform-express'
import { ValidationPipe } from '@nestjs/common'
import { WhatsappServiceModule } from './whatsapp-service.module'

async function bootstrap() {
    const app = await NestFactory.create<NestExpressApplication>(WhatsappServiceModule, { rawBody: true })
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: false, transform: true }))
    await app.listen(process.env.WHATSAPP_SERVICE_PORT ?? 3012)
    console.log(`[whatsapp-service] listening on port ${process.env.WHATSAPP_SERVICE_PORT ?? 3012}`)
}
bootstrap()
