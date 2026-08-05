/**
 * Picks the right Supabase pooler port for what the connection is about to do.
 *
 * Supabase exposes its pooler (Supavisor) on two ports, and they are not
 * interchangeable:
 *
 *   5432 — session mode. Every client connection is handed a dedicated
 *          Postgres backend for its whole lifetime. Session state works:
 *          advisory locks, prepared statements, `SET`. The pool is small
 *          (15 on the free tier) because each client costs a real backend.
 *
 *   6543 — transaction mode. A backend is borrowed only for the duration of a
 *          statement or transaction, so hundreds of clients share a handful of
 *          backends. Session state does not survive between statements.
 *
 * The running application wants 6543. It is serverless: every concurrent
 * request can land on a fresh instance with its own pool, and instances are
 * frozen rather than shut down, so their connections are never returned. At
 * 5432 that reaches the 15-connection ceiling almost immediately — which is
 * exactly what happened in production: a burst of dashboard requests returned
 * `(EMAXCONNSESSION) max clients reached in session mode`, and the endpoints
 * that failed were simply the ones that lost the race, not the ones with bugs.
 *
 * Migrations want 5432. `prisma migrate deploy` guards itself with a Postgres
 * advisory lock, and an advisory lock taken on a transaction-pooled connection
 * is released the moment the statement ends — the lock silently protects
 * nothing, and two concurrent deploys can apply the same migration twice.
 *
 * Rather than depend on which port someone happened to paste into the
 * environment, each caller asks for the mode it needs. A URL that is not a
 * Supabase pooler — a local Postgres, Docker, a direct db.*.supabase.co host —
 * is returned untouched, because none of this applies to it.
 */

/** Supabase's pooler hostnames look like `aws-1-ap-southeast-1.pooler.supabase.com`. */
const POOLER_HOST = /(^|\.)pooler\.supabase\.com$/i;

const SESSION_PORT = '5432';
const TRANSACTION_PORT = '6543';

function reportedAsPooler(url: URL): boolean {
  return POOLER_HOST.test(url.hostname);
}

function retarget(
  raw: string | undefined,
  port: string,
  pgbouncer: boolean,
): string | undefined {
  if (!raw) return raw;

  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    // Not a URL we can reason about (a libpq keyword string, say). Leave it be;
    // whatever consumes it will report a better error than we could.
    return raw;
  }

  if (!reportedAsPooler(url)) return raw;

  url.port = port;
  // Prisma uses `pgbouncer=true` to mean "do not rely on prepared statements
  // persisting between calls" — true of transaction mode, wrong for session.
  if (pgbouncer) url.searchParams.set('pgbouncer', 'true');
  else url.searchParams.delete('pgbouncer');

  return url.toString();
}

/** The URL the running application should open connections with. */
export function runtimeUrl(raw: string | undefined): string | undefined {
  return retarget(raw, TRANSACTION_PORT, true);
}

/** The URL `prisma migrate` should use. */
export function migrationUrl(raw: string | undefined): string | undefined {
  return retarget(raw, SESSION_PORT, false);
}

/** True when the two modes would differ — i.e. the URL is a Supabase pooler. */
export function isPooled(raw: string | undefined): boolean {
  if (!raw) return false;
  try {
    return reportedAsPooler(new URL(raw));
  } catch {
    return false;
  }
}
