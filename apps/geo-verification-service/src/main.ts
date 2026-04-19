import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { GeoVerificationServiceModule } from './geo-verification-service.module'

async function bootstrap() {
    const app = await NestFactory.create(GeoVerificationServiceModule)
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }))
    await app.listen(process.env.GEO_SERVICE_PORT ?? 3009)
    console.log(`[geo-verification-service] listening on port ${process.env.GEO_SERVICE_PORT ?? 3009}`)
}
bootstrap()
