import { NestFactory } from '@nestjs/core'
import { NestExpressApplication } from '@nestjs/platform-express'
import { ValidationPipe } from '@nestjs/common'
import { join } from 'path'
import { QuotationServiceModule } from './quotation-service.module'

async function bootstrap() {
    const app = await NestFactory.create<NestExpressApplication>(QuotationServiceModule, { rawBody: true })
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: false, transform: true }))
    const uploadDir = join(process.cwd(), 'uploads')
    app.useStaticAssets(uploadDir, { prefix: '/uploads/' })
    await app.listen(process.env.QUOTATION_SERVICE_PORT ?? 3007)
    console.log(`[quotation-service] listening on port ${process.env.QUOTATION_SERVICE_PORT ?? 3007}`)
}
bootstrap()
