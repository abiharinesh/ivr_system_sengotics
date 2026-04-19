import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { TenderServiceModule } from './tender-service.module'

async function bootstrap() {
    const app = await NestFactory.create(TenderServiceModule)
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }))
    await app.listen(process.env.TENDER_SERVICE_PORT ?? 3006)
    console.log(`[tender-service] listening on port ${process.env.TENDER_SERVICE_PORT ?? 3006}`)
}
bootstrap()
