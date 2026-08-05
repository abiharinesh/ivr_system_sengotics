import 'dotenv/config';
import { defineConfig } from 'prisma/config';
import { migrationUrl } from './src/prisma/connection-url';

/**
 * Prisma CLI configuration.
 *
 * ── Why DIRECT_URL is preferred here ───────────────────────────────────────
 * `DATABASE_URL` points at Supabase's connection pooler, which is right for
 * the running application: it is what lets a serverless function open a
 * connection per request without exhausting Postgres.
 *
 * Migrations are different. `prisma migrate deploy` takes a Postgres advisory
 * lock so two concurrent deploys cannot apply the same migration twice, and an
 * advisory lock means nothing on a transaction-pooled connection — it would be
 * taken and released on different backends. Port 5432 on the Supabase pooler
 * is session mode, which does hold locks, so this works today. Port 6543 is
 * transaction mode and would not.
 *
 * Setting `DIRECT_URL` to the non-pooled connection string removes the
 * dependence on which port the URL happens to name. It is optional: without
 * it the pooled URL is used, with its port corrected to session mode by
 * `migrationUrl` — so a single `DATABASE_URL` is enough to make both the
 * application and its migrations connect the way each of them needs to,
 * whichever port was pasted in.
 */
export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    // The demo dataset. The generated default pointed at `prisma/seed.ts`,
    // which was never written, so `prisma db seed` failed on a fresh clone.
    seed: 'node prisma/seed-demo.js',
  },
  datasource: {
    url:
      process.env['DIRECT_URL'] || migrationUrl(process.env['DATABASE_URL']),
  },
});
