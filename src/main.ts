import { NestFactory } from '@nestjs/core'
import { ValidationPipe, Logger } from '@nestjs/common'
import { AppModule } from './app.module'
import { DbSetupService } from './prisma/db-setup.service'
import * as express from 'express'

async function bootstrap() {
  const logger = new Logger('Bootstrap')

  const app = await NestFactory.create(AppModule)

  // Enable CORS for frontend access
  app.enableCors()

  // Parse URL-encoded bodies (Exotel sends this format) and JSON
  app.use(express.urlencoded({ extended: true }))
  app.use(express.json())

  // Use validation pipe globally
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true
  }))

  // Log all incoming requests (only in development)
  if (process.env.NODE_ENV !== 'production') {
    app.use((req: express.Request, _res: express.Response, next: express.NextFunction) => {
      logger.debug(`[REQUEST] ${req.method} ${req.url}`)
      if (Object.keys(req.query).length) logger.debug(`[QUERY] ${JSON.stringify(req.query)}`)
      if (req.body && Object.keys(req.body).length) logger.debug(`[BODY] ${JSON.stringify(req.body)}`)
      next()
    })
  }

  // Bootstrap Database (Extensions, Seeding)
  const dbSetupService = app.get(DbSetupService)
  await dbSetupService.bootstrapDb()

  const port = process.env.PORT || 3000
  await app.listen(port)
  logger.log(`Application is running on: http://localhost:${port}`)
}

bootstrap().catch(err => {
  console.error('❌ Application failed to start:', err)
  process.exit(1)
})
