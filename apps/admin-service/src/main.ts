import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { AdminServiceModule } from './admin-service.module'

async function bootstrap() {
    const app = await NestFactory.create(AdminServiceModule)
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }))
    await app.listen(process.env.ADMIN_SERVICE_PORT ?? 3005)
    console.log(`[admin-service] listening on port ${process.env.ADMIN_SERVICE_PORT ?? 3005}`)
}
bootstrap()
