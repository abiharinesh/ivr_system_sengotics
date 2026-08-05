import { isPooled, migrationUrl, runtimeUrl } from './connection-url';

const POOLER =
  'postgresql://postgres.abcdef:secret@aws-1-ap-southeast-1.pooler.supabase.com:5432/postgres';

describe('connection-url', () => {
  describe('runtimeUrl', () => {
    it('moves a session-mode pooler URL to transaction mode', () => {
      const url = new URL(runtimeUrl(POOLER)!);
      expect(url.port).toBe('6543');
      expect(url.searchParams.get('pgbouncer')).toBe('true');
    });

    it('leaves an already-transaction-mode URL on its port', () => {
      const already = POOLER.replace(':5432', ':6543');
      expect(new URL(runtimeUrl(already)!).port).toBe('6543');
    });

    it('keeps credentials, database and existing query parameters', () => {
      const withParams = `${POOLER}?sslmode=require&connection_limit=5`;
      const url = new URL(runtimeUrl(withParams)!);
      expect(url.username).toBe('postgres.abcdef');
      expect(url.password).toBe('secret');
      expect(url.pathname).toBe('/postgres');
      expect(url.searchParams.get('sslmode')).toBe('require');
      expect(url.searchParams.get('connection_limit')).toBe('5');
    });

    it('leaves a local Postgres URL alone', () => {
      const local = 'postgresql://postgres:postgres@localhost:5432/ivr';
      expect(runtimeUrl(local)).toBe(local);
    });

    it('leaves a direct (non-pooler) Supabase host alone', () => {
      // db.<ref>.supabase.co is the direct connection; it is not Supavisor and
      // has no second port to move to.
      const direct =
        'postgresql://postgres:secret@db.abcdef.supabase.co:5432/postgres';
      expect(runtimeUrl(direct)).toBe(direct);
    });

    it('does not treat a lookalike host as the pooler', () => {
      const evil =
        'postgresql://u:p@pooler.supabase.com.attacker.test:5432/postgres';
      expect(runtimeUrl(evil)).toBe(evil);
      expect(isPooled(evil)).toBe(false);
    });

    it('passes through undefined and unparseable values', () => {
      expect(runtimeUrl(undefined)).toBeUndefined();
      expect(runtimeUrl('host=localhost dbname=ivr')).toBe(
        'host=localhost dbname=ivr',
      );
    });
  });

  describe('migrationUrl', () => {
    it('moves a transaction-mode pooler URL back to session mode', () => {
      const tx = `${POOLER.replace(':5432', ':6543')}?pgbouncer=true`;
      const url = new URL(migrationUrl(tx)!);
      expect(url.port).toBe('5432');
      // Advisory locks need real session state; pgbouncer=true says the
      // opposite and must not be carried over.
      expect(url.searchParams.get('pgbouncer')).toBeNull();
    });

    it('leaves a session-mode URL on its port', () => {
      expect(new URL(migrationUrl(POOLER)!).port).toBe('5432');
    });

    it('leaves non-pooler URLs alone', () => {
      const local = 'postgresql://postgres:postgres@localhost:5432/ivr';
      expect(migrationUrl(local)).toBe(local);
    });
  });

  it('sends the application and its migrations to different ports', () => {
    // The whole point: one env var, two correct destinations.
    expect(new URL(runtimeUrl(POOLER)!).port).toBe('6543');
    expect(new URL(migrationUrl(POOLER)!).port).toBe('5432');
  });

  describe('isPooled', () => {
    it('recognises the pooler and nothing else', () => {
      expect(isPooled(POOLER)).toBe(true);
      expect(isPooled('postgresql://u:p@localhost:5432/ivr')).toBe(false);
      expect(isPooled(undefined)).toBe(false);
    });
  });
});
