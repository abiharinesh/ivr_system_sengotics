/**
 * Canonical deployment seed.
 *
 * This is the only seed invoked by Prisma and Vercel. It intentionally does
 * not execute every historical `seed-*.js` file: some are alternate regional
 * datasets and `seed.js` truncates every table. The two steps below are the
 * complete, idempotent product dataset: authorization/catalogue first, then
 * the domain records that depend on it.
 */
require('dotenv').config();
const { spawnSync } = require('child_process');
const { makeClient } = require('./db');

function run(script) {
  const result = spawnSync(process.execPath, [script], {
    cwd: process.cwd(),
    env: process.env,
    stdio: 'inherit',
  });
  if (result.status !== 0) {
    throw new Error(`${script} failed with exit code ${result.status}`);
  }
}

async function verify() {
  const { prisma, close } = makeClient({ max: 1 });
  try {
    const [tenants, orgUnits, users, roles, permissions, screens] =
      await Promise.all([
        prisma.tenant.count(),
        prisma.orgUnit.count(),
        prisma.user.count(),
        prisma.role.count(),
        prisma.permission.count(),
        prisma.appScreen.count(),
      ]);
    const missing = [
      ['tenants', tenants],
      ['org units', orgUnits],
      ['users', users],
      ['roles', roles],
      ['permissions', permissions],
      ['app screens', screens],
    ]
      .filter(([, count]) => count === 0)
      .map(([label]) => label);
    if (missing.length) {
      throw new Error(`Deployment seed is incomplete: missing ${missing.join(', ')}`);
    }
    console.log(
      `Deployment seed verified: ${tenants} tenants, ${orgUnits} org units, ` +
        `${users} users, ${roles} roles, ${permissions} permissions, ${screens} screens.`,
    );
  } finally {
    await close();
  }
}

async function main() {
  console.log('Running canonical deployment seed...');
  run('prisma/seed-rbac.js');
  run('prisma/seed-demo.js');
  await verify();
}

main().catch((error) => {
  console.error('Deployment seed failed:', error);
  process.exitCode = 1;
});
