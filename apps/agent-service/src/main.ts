import { NestFactory } from '@nestjs/core'
import { NestExpressApplication } from '@nestjs/platform-express'
import { ValidationPipe } from '@nestjs/common'
import { join } from 'path'
import { AgentServiceModule } from './agent-service.module'

async function bootstrap() {
    const app = await NestFactory.create<NestExpressApplication>(AgentServiceModule, { rawBody: true })
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({ whitelist: false, transform: true }))
    const uploadDir = join(process.cwd(), 'uploads')
    app.useStaticAssets(uploadDir, { prefix: '/uploads/' })
    await app.listen(process.env.AGENT_SERVICE_PORT ?? 3010)
    console.log(`[agent-service] listening on port ${process.env.AGENT_SERVICE_PORT ?? 3010}`)
}
bootstrap()
