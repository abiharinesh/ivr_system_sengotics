import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from './prisma.service';

/**
 * Startup database checks.
 *
 * This deliberately does NOT define or patch schema. It previously carried
 * ~650 lines of hand-written `CREATE TABLE` / `ALTER TABLE` DDL that mirrored
 * schema.prisma — a second source of truth that silently drifted out of sync
 * (it was still creating a `vendors` table and `vendor_id` foreign keys long
 * after those were removed). Because every statement was wrapped in a
 * swallow-all try/catch labelled "non-fatal", that drift surfaced only as
 * warning noise on each boot.
 *
 * Schema is owned by `prisma/schema.prisma` (applied via `prisma migrate` /
 * `prisma db push`). Seed data is owned by `prisma/seed.js` and the explicit
 * seed scripts. This service only verifies the things Prisma cannot: that the
 * database is reachable and that required extensions are installed.
 */
@Injectable()
export class DbSetupService {
  private readonly logger = new Logger(DbSetupService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Lightweight check for serverless (Vercel), where cold-start time matters.
   */
  async bootstrapDbLite() {
    try {
      await this.prisma.$executeRawUnsafe(
        'CREATE EXTENSION IF NOT EXISTS postgis;',
      );
      await this.prisma.$queryRaw`SELECT 1`;
      this.logger.log('Database reachable (lite bootstrap).');
    } catch (error) {
      this.logger.error(`Lite database check failed: ${(error as Error).message}`);
      throw error;
    }
  }

  /**
   * Full startup check. Fails loudly — an unreachable database or a missing
   * PostGIS extension means geo queries will break at request time, so it is
   * better to refuse to start than to serve a half-working API.
   */
  async bootstrapDb() {
    try {
      await this.prisma.$executeRawUnsafe(
        'CREATE EXTENSION IF NOT EXISTS postgis;',
      );
      await this.prisma.$queryRaw`SELECT 1`;

      const orgUnitCount = await this.prisma.orgUnit.count();
      if (orgUnitCount === 0) {
        this.logger.warn(
          'Database is reachable but contains no org units. Run `node prisma/seed.js` to seed it.',
        );
      } else {
        this.logger.log(`Database ready (${orgUnitCount} org units).`);
      }
    } catch (error) {
      this.logger.error(
        `Database bootstrap failed: ${(error as Error).message}`,
      );
      throw error;
    }
  }
}
