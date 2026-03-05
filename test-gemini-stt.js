/**
 * Test Google Gemini Voice-to-Text
 * Run: node test-gemini-stt.js
 */
require('dotenv/config');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY;

if (!GOOGLE_API_KEY) {
    console.error('❌ GOOGLE_API_KEY not set in .env');
    process.exit(1);
}

console.log(`✅ GOOGLE_API_KEY: ${GOOGLE_API_KEY.substring(0, 10)}...`);

// Exotel recording URL from your database
const audioUrl = 'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772118444.76627_1.mp3';

const EXOTEL_API_KEY = process.env.EXOTEL_API_KEY;
const EXOTEL_API_TOKEN = process.env.EXOTEL_API_TOKEN;

async function test() {
    // Step 1: Download audio from Exotel
    console.log('\n── Step 1: Downloading audio ──');
    console.log(`URL: ${audioUrl}`);

    const headers = {};
    if (EXOTEL_API_KEY && EXOTEL_API_TOKEN) {
        const creds = Buffer.from(`${EXOTEL_API_KEY}:${EXOTEL_API_TOKEN}`).toString('base64');
        headers['Authorization'] = `Basic ${creds}`;
        console.log('Using Exotel Basic Auth ✅');
    }

    const response = await fetch(audioUrl, { headers });

    if (!response.ok) {
        console.error(`❌ Download failed: HTTP ${response.status} ${response.statusText}`);
        const text = await response.text();
        console.error('Body:', text.substring(0, 200));
        return;
    }

    const buffer = await response.arrayBuffer();
    console.log(`✅ Downloaded: ${buffer.byteLength} bytes`);

    if (buffer.byteLength < 100) {
        console.error('❌ File too small — likely empty or error page');
        return;
    }

    // Step 2: Send to Gemini
    console.log('\n── Step 2: Sending to Gemini ──');
    const audioBase64 = Buffer.from(buffer).toString('base64');
    console.log(`Base64 size: ${audioBase64.length} characters`);

    const genAI = new GoogleGenerativeAI(GOOGLE_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

    const startTime = Date.now();

    const result = await model.generateContent([
        {
            inlineData: {
                mimeType: 'audio/mpeg',
                data: audioBase64
            }
        },
        {
            text: `Transcribe this audio recording accurately. The speaker is speaking in Colloquial Tamil (spoken Tamil from Tamil Nadu villages).
The audio is a voice complaint about electrical/street light issues.
IMPORTANT RULES:
- Output ONLY the transcription text, nothing else
- Keep Tamil words as-is in their original romanized/Tamil script form
- If the audio is unclear or silent, return an empty string`
        }
    ]);

    const elapsed = Date.now() - startTime;
    const text = result.response.text()?.trim() ?? '';

    console.log(`\n✅ Gemini responded in ${elapsed}ms`);
    console.log(`\n📝 Transcription:\n"${text}"`);
}

test().catch(err => {
    console.error('❌ Error:', err.message);
});
