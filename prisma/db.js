/**
 * One Prisma client for the seed scripts, connected the way the running
 * application connects.
 *
 * Each seed used to build its own `new Pool({ connectionString: DATABASE_URL })`,
 * which meant session mode on port 5432 — a dedicated Postgres backend per
 * connection out of a ceiling of fifteen. A seed opening a default pool of ten
 * alongside anything else already talking to the database is most of that
 * ceiling on its own, and the failure it produces ("Client has encountered a
 * connection error and is not queryable") says nothing about the real cause.
 *
 * The port rewriting lives in `src/prisma/connection-url.ts`, which is tested;
 * this reaches for the compiled copy rather than restating the rules in a
 * second language where the two could drift apart. If the project has not been
 * built, the URL is used exactly as given — the behaviour every seed had
 * before this file existed, so nothing gets worse.
 */
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

let runtimeUrl;
try {
  ({ runtimeUrl } = require('../dist/prisma/connection-url'));
} catch {
  runtimeUrl = (url) => url;
}

/**
 * The connection string a seed should use, for scripts that tune their own
 * pool and only need the URL corrected.
 */
function connectionString() {
  return runtimeUrl(process.env.DATABASE_URL);
}

/**
 * @param {{ max?: number }} [opts]
 * @returns {{ prisma: PrismaClient, pool: Pool, close: () => Promise<void> }}
 */
function makeClient(opts = {}) {
  const pool = new Pool({
    connectionString: connectionString(),
    // Seeds are sequential; a wide pool buys nothing and costs connections.
    max: opts.max ?? 3,
    idleTimeoutMillis: 10_000,
    connectionTimeoutMillis: 15_000,
  });

  const prisma = new PrismaClient({ adapter: new PrismaPg(pool) });

  return {
    prisma,
    pool,
    close: async () => {
      await prisma.$disconnect();
      await pool.end();
    },
  };
}

module.exports = { makeClient, connectionString };
