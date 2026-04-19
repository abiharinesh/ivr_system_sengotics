import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { PoleServiceModule } from './pole-service.module'

async function bootstrap() {
    const app = await NestFactory.create(PoleServiceModule)
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }))
    await app.listen(process.env.POLE_SERVICE_PORT ?? 3003)
    console.log(`[pole-service] listening on port ${process.env.POLE_SERVICE_PORT ?? 3003}`)
}
bootstrap()
