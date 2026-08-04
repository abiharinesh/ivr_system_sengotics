/**
 * Demo dataset.
 *
 * Fills every module with realistic Tamil Nadu records so no screen in the
 * product renders an empty state. Safe to re-run: each section skips a table
 * that already has rows, so history is never stacked twice.
 *
 * Run: node prisma/seed-demo.js
 */
const { prisma, pool } = require('./demo/lib');
const { seedFoundation } = require('./demo/01-foundation');
const { seedCitizen } = require('./demo/02-citizen');
const { seedInfrastructure } = require('./demo/03-infrastructure');
const { seedRevenue } = require('./demo/04-revenue');
const { seedRegulatory } = require('./demo/05-regulatory');
const { seedSolidWaste } = require('./demo/06-solid-waste');
const { seedProcurement } = require('./demo/07-procurement');
const { seedPlatform } = require('./demo/08-platform');
const { seedOperations } = require('./demo/09-operations');
const { seedStaffing } = require('./demo/10-staffing');
const { seedToday } = require('./demo/11-today');

async function main() {
  console.log('\n════ Demo dataset ════');
  const ctx = await seedFoundation();
  await seedCitizen(ctx);
  await seedInfrastructure(ctx);
  await seedRevenue(ctx);
  await seedRegulatory(ctx);
  await seedSolidWaste(ctx);
  await seedProcurement(ctx);
  await seedPlatform(ctx);
  await seedOperations(ctx);
  await seedStaffing(ctx);
  await seedToday(ctx);
  console.log('\nDone.\n');
}

main()
  .catch((e) => { console.error('\nSeed failed:', e.message, '\n', e.stack); process.exitCode = 1; })
  .finally(async () => { await prisma.$disconnect(); await pool.end(); });
