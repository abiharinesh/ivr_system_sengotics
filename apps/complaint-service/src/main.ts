import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { ComplaintServiceModule } from './complaint-service.module'

async function bootstrap() {
    const app = await NestFactory.create(ComplaintServiceModule)
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }))
    await app.listen(process.env.COMPLAINT_SERVICE_PORT ?? 3002)
    console.log(`[complaint-service] listening on port ${process.env.COMPLAINT_SERVICE_PORT ?? 3002}`)
}
bootstrap()
