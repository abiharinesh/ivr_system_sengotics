# Database migrations

The schema applies itself on deploy. `vercel-build` runs:

```
prisma generate && prisma migrate deploy && nest build
```

If a migration fails, the build fails and nothing ships. That is deliberate —
a deployed API whose schema does not match its code fails at request time, in
front of a user, instead of at build time in front of you.

## How to change the schema

1. Edit `prisma/schema.prisma`.
2. Write the SQL by hand in a new folder here, named
   `YYYYMMDDHHMMSS_short_description/migration.sql`.
3. Add a `rollback.sql` beside it. Nothing runs it automatically; it exists so
   that undoing a change at 11pm is reading a file rather than reconstructing
   one.
4. Run `npm run db:drift`. It must report no difference — that is the check
   that the SQL you wrote and the schema you edited actually agree.
5. Commit both. The next deploy applies it.

**Never run `prisma db push` against a shared database.** It syncs the schema
without recording anything, which is exactly how this project ended up with
twelve migration folders and no `_prisma_migrations` table: the migrations
described the schema, but nothing had ever applied them and nothing knew
whether they had been. They had to be baselined after the fact.

## Commands

| Command | What it does |
|---|---|
| `npm run db:status` | Which migrations are applied and which are pending |
| `npm run db:drift` | Fails if the live schema and `schema.prisma` disagree |

## Why `DIRECT_URL` is worth setting

`DATABASE_URL` points at Supabase's pooler, which is correct for the running
app. `migrate deploy` takes a Postgres advisory lock so two concurrent deploys
cannot apply the same migration twice, and that lock means nothing on a
transaction-pooled connection.

Port 5432 on the Supabase pooler is session mode and holds locks, so this
works today. Port 6543 is transaction mode and would not. Setting `DIRECT_URL`
to the non-pooled connection string removes the dependence on which port the
URL happens to name. `prisma.config.ts` prefers it when present.

## Writing the SQL

Every migration here uses `IF NOT EXISTS` / `IF EXISTS`. Keep doing that. A
migration that has been applied by hand to one environment and not another —
which is the state this project was in — should be re-runnable without
failing.
