import { NestFactory } from '@nestjs/core'
import { NestExpressApplication } from '@nestjs/platform-express'
import { ValidationPipe } from '@nestjs/common'
import { IvrServiceModule } from './ivr-service.module'

async function bootstrap() {
    const app = await NestFactory.create<NestExpressApplication>(IvrServiceModule, { rawBody: true })
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: false, forbidNonWhitelisted: false, transform: true }))
    await app.listen(process.env.IVR_SERVICE_PORT ?? 3011)
    console.log(`[ivr-service] listening on port ${process.env.IVR_SERVICE_PORT ?? 3011}`)
}
bootstrap()
