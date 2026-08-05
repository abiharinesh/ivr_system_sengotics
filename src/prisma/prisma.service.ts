import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { createTenantScopedClient } from '../core/tenant/tenant-scoped-client';
import { isPooled, runtimeUrl } from './connection-url';

/** Use inside `$transaction` callbacks when Prisma 7 omits model delegates on `tx`. */
export type PrismaTx = PrismaClient;
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private static readonly log = new Logger(PrismaService.name);

  private pool: Pool;

  constructor(private configService: ConfigService) {
    // Ten, not three. Three was a defence against session mode, where every
    // connection costs a dedicated backend out of a ceiling of 15. Transaction
    // mode multiplexes, so connections are cheap, and a request here fans out
    // to as many as nine queries at once — a pool of three makes each request
    // queue against itself.
    const configured = parseInt(
      configService.get<string>('DB_POOL_MAX') ?? '10',
      10,
    );
    const max = Number.isNaN(configured) ? 10 : configured;

    // Transaction mode, not session mode — see `connection-url.ts`. Session
    // mode gives each instance a dedicated backend and the ceiling is 15, so a
    // burst of dashboard requests across a handful of serverless instances
    // exhausted it and returned 500s from whichever endpoints lost the race.
    const raw = configService.get<string>('DATABASE_URL');
    const connectionString = runtimeUrl(raw);

    const pool = new Pool({
      connectionString,
      max,
      // A frozen serverless instance never runs `onModuleDestroy`, so without
      // this its connections are held until the pooler times them out. Ten
      // seconds is longer than any request here and short enough that idle
      // instances stop occupying the pool.
      idleTimeoutMillis: 10_000,
      // Wait for a free connection, but not forever: a caller that cannot get
      // one in ten seconds should fail and free its request slot rather than
      // pile up behind a saturated pool.
      connectionTimeoutMillis: 10_000,
    });

    const adapter = new PrismaPg(pool);
    super({ adapter });
    this.pool = pool;

    if (isPooled(raw)) {
      PrismaService.log.log(
        `Database pool: transaction mode, max ${max} connections per instance`,
      );
    }
  }

  /**
   * Returns the underlying pg Pool for direct SQL queries.
   * Use this for health checks and raw queries that bypass the Prisma adapter.
   */
  getPool(): Pool {
    return this.pool;
  }

  /**
   * Opt-in tenant-scoped client — auto-filters read queries to one tenant.
   * See `createTenantScopedClient` for exactly which operations it covers.
   */
  scopedToTenant(tenantId: string) {
    return createTenantScopedClient(this, tenantId);
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
