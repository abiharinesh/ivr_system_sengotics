import { NestFactory } from '@nestjs/core'
import { NestExpressApplication } from '@nestjs/platform-express'
import { ValidationPipe } from '@nestjs/common'
import { join } from 'path'
import { WorkOrderServiceModule } from './work-order-service.module'

async function bootstrap() {
    const app = await NestFactory.create<NestExpressApplication>(WorkOrderServiceModule, { rawBody: true })
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: false, transform: true }))
    const uploadDir = join(process.cwd(), 'uploads')
    app.useStaticAssets(uploadDir, { prefix: '/uploads/' })
    await app.listen(process.env.WORK_ORDER_SERVICE_PORT ?? 3008)
    console.log(`[work-order-service] listening on port ${process.env.WORK_ORDER_SERVICE_PORT ?? 3008}`)
}
bootstrap()
