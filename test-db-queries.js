const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
const { randomUUID } = require('crypto');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('Fetching electric poles with null public_report_token...');
  const poles = await prisma.electricPole.findMany({
    where: { public_report_token: null },
    select: { id: true, pole_number: true }
  });
  
  console.log(`Found ${poles.length} poles with null public_report_token.`);

  for (const pole of poles) {
    const token = randomUUID();
    await prisma.electricPole.update({
      where: { id: pole.id },
      data: { public_report_token: token }
    });
    console.log(`Updated Pole ${pole.pole_number} (ID: ${pole.id}) with token: ${token}`);
  }
  
  console.log('Populating completed!');
}

main().catch(err => {
  console.error('Error during update:', err);
}).finally(async () => {
  await prisma.$disconnect();
  await pool.end();
});
