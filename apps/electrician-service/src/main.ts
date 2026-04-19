import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { ElectricianServiceModule } from './electrician-service.module'

async function bootstrap() {
    const app = await NestFactory.create(ElectricianServiceModule)
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }))
    await app.listen(process.env.ELECTRICIAN_SERVICE_PORT ?? 3004)
    console.log(`[electrician-service] listening on port ${process.env.ELECTRICIAN_SERVICE_PORT ?? 3004}`)
}
bootstrap()
