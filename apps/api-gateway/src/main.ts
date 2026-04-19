import { NestFactory } from '@nestjs/core'
import { NestExpressApplication } from '@nestjs/platform-express'
import { ValidationPipe, Logger } from '@nestjs/common'
import { join } from 'path'
import { ApiGatewayModule } from './api-gateway.module'

async function bootstrap() {
    const logger = new Logger('Gateway')
    const app = await NestFactory.create<NestExpressApplication>(ApiGatewayModule, { rawBody: true })

    // Professional root health check listing all available microservice routes
    app.use((req, res, next) => {
        if (req.path === '/') {
            const responseData = {
                status: 'online',
                service: 'Sengotics API Gateway',
                version: '1.0.0',
                message: 'Welcome to the Sengotics API Gateway. Please route requests to the specific service endpoints listed below.',
                endpoints: {
                    auth: '/api/auth',
                    admin: '/api/admin',
                    superadmin: '/api/superadmin',
                    agent: '/api/agent',
                    procurement: '/api/procurement',
                    ivr: '/api/ivr',
                    whatsapp: '/api/whatsapp',
                    electrician: '/api/electrician'
                },
                timestamp: new Date().toISOString()
            };
            res.setHeader('Content-Type', 'application/json');
            return res.status(200).send(JSON.stringify(responseData, null, 2));
        }
        next();
    });

    const uploadDir = join(process.cwd(), 'uploads')
    app.useStaticAssets(uploadDir, { prefix: '/uploads/' })

    app.enableCors()
    app.setGlobalPrefix('api')
    app.useGlobalPipes(new ValidationPipe({
        whitelist: false,
        forbidNonWhitelisted: false,
        transform: true,
        disableErrorMessages: false,
    }))

    const port = process.env.GATEWAY_PORT ?? 3000
    await app.listen(port)
    logger.log(`API Gateway is running on: http://localhost:${port}`)
}
bootstrap()
