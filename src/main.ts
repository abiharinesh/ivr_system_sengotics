import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { AppModule } from './app.module'
import { DbSetupService } from './prisma/db-setup.service'

async function bootstrap() {
  const app = await NestFactory.create(AppModule)

  // Enable CORS for frontend access
  app.enableCors()

  // Use validation pipe globally
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true
  }))

  // Log all incoming requests for debugging
  app.use((req, res, next) => {
    console.log(`[REQUEST] ${req.method} ${req.url}`);
    if (Object.keys(req.query).length) console.log('[QUERY]', req.query);
    if (Object.keys(req.body || {}).length) console.log('[BODY]', req.body);
    next();
  })

  // Support for URL-encoded bodies (Exotel sends this format)
  app.use((req, res, next) => {
    if (req.headers['content-type'] === 'application/x-www-form-urlencoded') {
      req.headers['content-type'] = 'application/json'
    }
    next()
  })

  // Bootstrap Database (Extensions, Seeding)
  const dbSetupService = app.get(DbSetupService)
  await dbSetupService.bootstrapDb()

  const port = process.env.PORT || 3000
  await app.listen(port)
  console.log(`Application is running on: http://localhost:${port}`)
}
bootstrap()
