const OpenAI = require('openai');
require('dotenv').config();

const openai = new OpenAI({
  apiKey: process.env.GROQ_API_KEY,
  baseURL: 'https://api.groq.com/openai/v1',
});

const WARD_PROMPT = `You identify which ward (1-33) of Mettupalayam municipality the caller is referring to.
INPUT: Caller's transcribed speech + list of wards with names and aliases
OUTPUT: JSON -> {"ward_number": <1-33|null>, "confidence": <0.0-1.0>, "reason": "<brief>"}`;

const wards = [
  { number: 1, name: "Ward 1 - Mettupalayam Town", aliases: ["town", "center"] },
  { number: 2, name: "Ward 2 - Karamadai Road", aliases: ["karamadai", "karamadai road"] },
  { number: 5, name: "Ward 5 - Ooty Road", aliases: ["ooty road", "udhagai"] }
];

async function main() {
  const testCases = ["ward 5", "ainthavathu ward", "karamadai road", "unknown area xyz"];
  for (const tc of testCases) {
    const res = await openai.chat.completions.create({
      model: 'openai/gpt-oss-120b',
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: WARD_PROMPT },
        { role: 'user', content: `Caller said: "${tc}"\nWards: ${JSON.stringify(wards)}` },
      ],
    });
    console.log(tc, '->', res.choices[0].message.content);
  }
}

main().catch(console.error);
