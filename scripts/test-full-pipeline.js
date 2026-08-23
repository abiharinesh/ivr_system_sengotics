const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
const OpenAI = require('openai');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function testFullPipeline() {
  const audioUrl = "https://recordings.exotel.com/exotelrecordings/nexerawe1/1772118444.76627_1.mp3";
  console.log('1. Downloading audio...');
  
  const headers = {};
  if (process.env.EXOTEL_API_KEY && process.env.EXOTEL_API_TOKEN) {
    const credentials = Buffer.from(
      `${process.env.EXOTEL_API_KEY}:${process.env.EXOTEL_API_TOKEN}`
    ).toString('base64');
    headers['Authorization'] = `Basic ${credentials}`;
  }

  const response = await fetch(audioUrl, { headers });
  const buffer = await response.arrayBuffer();
  console.log(`Downloaded ${buffer.byteLength} bytes.`);

  // Google Speech STT
  console.log('2. Transcribing with Google Speech...');
  const audioBase64 = Buffer.from(buffer).toString('base64');
  const speechRes = await fetch(
    `https://speech.googleapis.com/v1/speech:recognize?key=${process.env.GOOGLE_SPEECH_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        config: {
          encoding: 'MP3',
          sampleRateHertz: 8000,
          languageCode: 'ta-IN',
          model: 'latest_short',
        },
        audio: { content: audioBase64 },
      }),
    }
  );

  const speechData = await speechRes.json();
  const transcript = speechData.results?.[0]?.alternatives?.[0]?.transcript || '';
  console.log('Transcript (Tamil):', transcript);

  // Fast translate to English
  console.log('3. Translating to English...');
  const transRes = await fetch(
    `https://translation.googleapis.com/language/translate/v2?key=${process.env.GOOGLE_SPEECH_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ q: transcript, target: 'en' }),
    }
  );
  const transData = await transRes.json();
  const english = transData.data?.translations?.[0]?.translatedText || transcript;
  console.log('English translation:', english);

  // Fetch wards
  console.log('4. Fetching wards from DB...');
  const wards = await prisma.ward.findMany({
    where: { org_unit_id: 12, is_active: true },
    select: { id: true, ward_number: true, name_en: true, aliases: true },
    orderBy: { ward_number: 'asc' },
  });
  console.log(`Loaded ${wards.length} wards.`);

  // Groq LLM match
  console.log('5. Matching ward with Groq (gpt-oss-120b)...');
  const openai = new OpenAI({
    apiKey: process.env.GROQ_API_KEY,
    baseURL: 'https://api.groq.com/openai/v1',
  });

  const WARD_PROMPT = `You identify which ward (1-33) of Mettupalayam municipality the caller is referring to.
INPUT: Caller's transcribed speech + list of wards with names and aliases
OUTPUT: JSON -> {"ward_number": <1-33|null>, "confidence": <0.0-1.0>, "reason": "<brief>"}`;

  const userMessage = `Caller said: "${english}" (Tamil: "${transcript}")
Wards: ${JSON.stringify(wards.map(w => ({ number: w.ward_number, name: w.name_en, aliases: w.aliases })))}`;

  const startTime = Date.now();
  const llmRes = await openai.chat.completions.create({
    model: 'openai/gpt-oss-120b',
    temperature: 0.0,
    max_tokens: 150,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: WARD_PROMPT },
      { role: 'user', content: userMessage },
    ],
  });

  console.log(`LLM match took ${Date.now() - startTime}ms.`);
  console.log('LLM Result:', llmRes.choices[0].message.content);
}

testFullPipeline()
  .catch(console.error)
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
