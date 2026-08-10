/**
 * Canonical deployment seed.
 *
 * This is the only seed invoked by Prisma and Vercel. It intentionally does
 * not execute every historical `seed-*.js` file: some are alternate regional
 * datasets and `seed.js` truncates every table. The two steps below are the
 * production baseline. The full dataset is created only for a fresh database;
 * rebuilding it on every Vercel deployment makes routine source changes take
 * minutes.
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

const SEED_VERSION = '1';
const SEED_VERSION_KEY = 'deployment_seed_version';

async function deploymentState() {
  const { prisma, close } = makeClient({ max: 1 });
  try {
    const [marker, tenants, orgUnits, users, roles, permissions, screens] =
      await Promise.all([
        prisma.systemSettings.findUnique({ where: { key: SEED_VERSION_KEY } }),
        prisma.tenant.count(),
        prisma.orgUnit.count(),
        prisma.user.count(),
        prisma.role.count(),
        prisma.permission.count(),
        prisma.appScreen.count(),
      ]);
    return {
      current: marker?.value === SEED_VERSION,
      initialized:
        tenants > 0 && orgUnits > 0 && users > 0 && roles > 0 &&
        permissions > 0 && screens > 0,
      mark: () =>
        prisma.systemSettings.upsert({
          where: { key: SEED_VERSION_KEY },
          update: { value: SEED_VERSION },
          create: { key: SEED_VERSION_KEY, value: SEED_VERSION },
        }),
      close,
    };
  } catch (error) {
    await close();
    throw error;
  }
}

async function main() {
  console.log('Running canonical deployment seed...');
  const state = await deploymentState();
  if (state.current) {
    await state.close();
    console.log(`Deployment seed v${SEED_VERSION} already verified; skipping.`);
    return;
  }
  if (state.initialized) {
    await state.mark();
    await state.close();
    await verify();
    console.log(`Existing database marked as deployment seed v${SEED_VERSION}; skipping rebuild.`);
    return;
  }
  await state.close();
  run('prisma/seed-rbac.js');
  // A brand-new database needs its foundation org units and domain records.
  // On every later deployment the version marker above avoids this expensive
  // path. `SEED_DEMO_DATA=true` is retained for operators who explicitly want
  // to rebuild the sample corpus after clearing a database.
  run('prisma/seed-demo.js');
  await verify();
  const completed = await deploymentState();
  await completed.mark();
  await completed.close();
}

main().catch((error) => {
  console.error('Deployment seed failed:', error);
  process.exitCode = 1;
});
