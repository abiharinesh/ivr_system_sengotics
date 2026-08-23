const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const OpenAI = require('openai');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('Testing STT & Ward Match pipeline...');
  const audioUrl = "https://recordings.exotel.com/exotelrecordings/nexerawe1/1772118444.76627_1.mp3";
  
  // Test Groq client
  const openai = new OpenAI({
    apiKey: process.env.GROQ_API_KEY,
    baseURL: 'https://api.groq.com/openai/v1',
  });

  try {
    const models = await openai.models.list();
    console.log('Groq connected successfully!');
  } catch (e) {
    console.error('Groq connection error:', e.message);
  }

  // Test Gemini client
  try {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    const result = await model.generateContent('Say hello in JSON: {"msg": "hello"}');
    console.log('Gemini 1.5 response:', result.response.text());
  } catch (e) {
    console.error('Gemini 1.5 error:', e.message);
  }

  try {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });
    const result = await model.generateContent('Say hello in JSON: {"msg": "hello"}');
    console.log('Gemini 2.0 response:', result.response.text());
  } catch (e) {
    console.error('Gemini 2.0 error:', e.message);
  }
}

main().finally(async () => {
  await prisma.$disconnect();
  await pool.end();
});
