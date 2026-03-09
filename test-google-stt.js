const fs = require('fs');
require('dotenv').config();

const API_KEY = process.env.GOOGLE_SPEECH_API_KEY || 'AIzaSyDIusYCJZIP-lK3vix96LoQJHYh2_WH46w';
const AUDIO_URL = 'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772823868.3624484_1.mp3';

const EXOTEL_KEY = process.env.EXOTEL_API_KEY;
const EXOTEL_TOKEN = process.env.EXOTEL_API_TOKEN;

async function testRealExotelAudio() {
    console.log(`1. Downloading Exotel Recording with Auth...`);

    let audioBuffer;
    try {
        const auth = Buffer.from(`${EXOTEL_KEY}:${EXOTEL_TOKEN}`).toString('base64');
        const audioResponse = await fetch(AUDIO_URL, {
            headers: {
                'Authorization': `Basic ${auth}`
            }
        });

        if (!audioResponse.ok) {
            throw new Error(`Failed to download audio: ${audioResponse.status} ${audioResponse.statusText}`);
        }
        audioBuffer = Buffer.from(await audioResponse.arrayBuffer());
    } catch (e) {
        console.error('Download error:', e.message);
        return;
    }

    const base64Audio = audioBuffer.toString('base64');
    console.log(`2. Downloaded ${audioBuffer.length} bytes. Base64 size: ${base64Audio.length}`);

    console.log(`3. Sending to Google Speech API (ta-IN)...`);
    const url = `https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}`;

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                config: {
                    encoding: 'MP3',
                    sampleRateHertz: 8000,
                    languageCode: 'ta-IN' // Tamil
                },
                audio: {
                    content: base64Audio
                }
            })
        });

        console.log(`\nHTTP Status: ${response.status} ${response.statusText}`);
        const data = await response.json();
        console.log('\nResponse Details:', JSON.stringify(data, null, 2));

        if (data.results && data.results.length > 0) {
            console.log('\n✅ TRANSCRIPT:', data.results[0].alternatives[0].transcript);
        } else {
            console.log('\n⚠️ No speech was recognized or audio was too quiet/empty.');
        }

    } catch (e) {
        console.error('Network error during Google API call:', e);
    }
}

testRealExotelAudio();
