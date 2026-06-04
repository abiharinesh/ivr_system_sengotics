import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ValidationPipe, Logger } from '@nestjs/common';
import { join } from 'path';
import { AppModule } from './app.module';
import { DbSetupService } from './prisma/db-setup.service';

async function bootstrap() {
  const logger = new Logger('Bootstrap');

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    rawBody: true,
  });

  // CORS before static assets so Flutter web Image.network (crossOrigin=anonymous) can load uploads.
  app.enableCors();

  const uploadDir = join(process.cwd(), 'uploads');
  app.useStaticAssets(uploadDir, {
    prefix: '/uploads/',
    setHeaders: (res) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
    },
  });

  const docsDir = join(process.cwd(), 'docs');
  app.useStaticAssets(docsDir, {
    prefix: '/docs/',
    setHeaders: (res) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
    },
  });

  // Use validation pipe globally — NestJS handles JSON + URL-encoded parsing internally
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: false, // Don't strip unknown properties (Exotel sends variable payloads)
      forbidNonWhitelisted: false,
      transform: true,
      disableErrorMessages: false,
    }),
  );

  // Log all incoming requests (development only)
  if (process.env.NODE_ENV !== 'production') {
    app.use((req: any, _res: any, next: any) => {
      logger.debug(`[REQUEST] ${req.method} ${req.url}`);
      if (req.query && Object.keys(req.query).length)
        logger.debug(`[QUERY] ${JSON.stringify(req.query)}`);
      if (req.body && Object.keys(req.body).length)
        logger.debug(`[BODY] ${JSON.stringify(req.body)}`);
      next();
    });
  }

  // Bootstrap Database (Extensions, Seeding)
  const dbSetupService = app.get(DbSetupService);
  await dbSetupService.bootstrapDb();

  const port = process.env.PORT || 3000;
  await app.listen(port);
  logger.log(`Application is running on: http://localhost:${port}`);
}

// Only run the standalone server when this file is executed directly
// (i.e. `nest start` / `node dist/main`). On Vercel the entry is
// `api/index.ts`; main.ts must NOT auto-bootstrap there or it crashes the
// serverless function with "No exports found in module .../src/main.js".
if (!process.env.VERCEL) {
  bootstrap().catch((err) => {
    console.error('❌ Application failed to start:', err);
    process.exit(1);
  });
}

export {};
