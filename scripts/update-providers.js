const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  // Upsert stt_provider → google-speech
  await prisma.systemSettings.upsert({
    where: { key: 'stt_provider' },
    create: { key: 'stt_provider', value: 'google-speech' },
    update: { value: 'google-speech' },
  });
  console.log('✅ stt_provider = google-speech');

  // Upsert llm_provider → groq
  await prisma.systemSettings.upsert({
    where: { key: 'llm_provider' },
    create: { key: 'llm_provider', value: 'groq' },
    update: { value: 'groq' },
  });
  console.log('✅ llm_provider = groq');

  // Update ai_provider → groq
  await prisma.systemSettings.upsert({
    where: { key: 'ai_provider' },
    create: { key: 'ai_provider', value: 'groq' },
    update: { value: 'groq' },
  });
  console.log('✅ ai_provider = groq');

  // Verify
  const settings = await prisma.systemSettings.findMany();
  console.log('\nCurrent settings:');
  for (const s of settings) {
    if (['stt_provider', 'llm_provider', 'ai_provider'].includes(s.key)) {
      console.log(`  ${s.key} = ${s.value}`);
    }
  }
}

main()
  .catch(console.error)
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
