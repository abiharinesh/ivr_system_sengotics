/**
 * Move any user out of the `__system__` sentinel tenant.
 *
 * `__system__` exists to hold cross-tenant role templates. It owns no org
 * units and no data, and every service scopes its reads by the caller's
 * tenant — so an account placed there sees an empty product: no roles, no
 * people, no dashboard panels, nothing.
 *
 * `superadmin@sengotics.com` was created there. It appeared to work only
 * because `listRoles` reads `tenant_id IN (yours, '__system__')` and the whole
 * role roster used to live in `__system__` too. Once the roster moved into the
 * operating tenant so it could be edited, that accident stopped covering for
 * the misplaced account and every screen went blank.
 *
 * Idempotent. Run: node prisma/fix-tenant-placement.js
 */
require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter: new PrismaPg(pool) });

const SENTINEL = '__system__';

async function main() {
  const stranded = await prisma.user.findMany({
    where: { tenant_id: SENTINEL },
    select: { id: true, email: true, role: true, primary_org_unit_id: true },
  });

  if (stranded.length === 0) {
    console.log('  No user sits in the sentinel tenant. Nothing to do.');
    return;
  }

  // Send them to the tenant their branch actually belongs to, rather than
  // assuming "default" — a user posted to a branch belongs to that branch's
  // tenant by definition.
  for (const u of stranded) {
    let target = 'default';
    if (u.primary_org_unit_id) {
      const org = await prisma.orgUnit.findUnique({
        where: { id: u.primary_org_unit_id },
        select: { tenant_id: true, name: true },
      });
      if (org) target = org.tenant_id;
    }

    await prisma.user.update({
      where: { id: u.id },
      data: { tenant_id: target },
    });
    console.log(`  ${u.email.padEnd(34)} ${SENTINEL} -> ${target}`);
  }

  console.log(`\n  Moved ${stranded.length} account(s).`);
}

main()
  .catch((e) => {
    console.error('\nFailed:', e.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
