const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  const orgs = await prisma.orgUnit.findMany({
    select: { id: true, name: true, ivr_number: true },
  });
  console.log('Orgs:', JSON.stringify(orgs, null, 2));

  const wards = await prisma.ward.findMany({
    select: { id: true, ward_number: true, name_en: true, org_unit_id: true, aliases: true },
    orderBy: { ward_number: 'asc' },
  });
  console.log(`Wards count: ${wards.length}`);
  console.log('Sample wards:', JSON.stringify(wards.slice(0, 5), null, 2));

  const settings = await prisma.systemSettings.findMany();
  console.log('Settings:', JSON.stringify(settings, null, 2));
}

main()
  .catch(console.error)
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
