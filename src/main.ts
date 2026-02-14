import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { AppModule } from './app.module'

async function bootstrap() {
  const app = await NestFactory.create(AppModule)

  // Enable CORS for frontend access
  app.enableCors()

  // Use validation pipe globally
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true
  }))

  // Support for URL-encoded bodies (Exotel sends this format)
  app.use((req, res, next) => {
    if (req.headers['content-type'] === 'application/x-www-form-urlencoded') {
      req.headers['content-type'] = 'application/json'
    }
    next()
  })

  const port = process.env.PORT || 3000
  await app.listen(port)
  console.log(`Application is running on: http://localhost:${port}`)
}
bootstrap()
