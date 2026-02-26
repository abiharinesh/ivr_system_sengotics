import OpenAI from 'openai';
import * as dotenv from 'dotenv';
import * as fs from 'fs';

dotenv.config();

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

async function testFetchAndTranscribe() {
    try {
        // Use a known Exotel recording URL from earlier logs
        const audioUrl = 'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772118444.76627_1.mp3';
        console.log(`Audio URL: ${audioUrl}`);

        const exotelApiKey = process.env.EXOTEL_API_KEY;
        const exotelApiToken = process.env.EXOTEL_API_TOKEN;

        console.log(`Using EXOTEL_API_KEY: ${exotelApiKey ? 'Set' : 'Not Set'}`);
        console.log(`Using EXOTEL_API_TOKEN: ${exotelApiToken ? 'Set' : 'Not Set'}`);

        const headers: Record<string, string> = {};
        if (exotelApiKey && exotelApiToken) {
            const credentials = Buffer.from(`${exotelApiKey}:${exotelApiToken}`).toString('base64');
            headers['Authorization'] = `Basic ${credentials}`;
        }

        console.log('Downloading audio from Exotel...');
        const response = await fetch(audioUrl, { headers });

        if (!response.ok) {
            console.error(`❌ Download failed: HTTP ${response.status} ${response.statusText}`);
            const text = await response.text();
            console.error('Response body:', text);
            return;
        }

        console.log('✅ Download successful! Blob size:', response.headers.get('content-length'));

        const audioBlob = await response.blob();
        if (audioBlob.size < 100) {
            console.error('❌ Downloaded file is too small, likely an error page or empty recording. Check auth/credentials.');
            const text = await audioBlob.text();
            console.error('Content:', text);
            return;
        }

        const audioFile = new File([audioBlob], 'audio.mp3', { type: 'audio/mpeg' });

        console.log('Sending to OpenAI Whisper...');
        const transcription = await openai.audio.transcriptions.create({
            file: audioFile,
            model: 'whisper-1',
            language: 'ta',
        });

        console.log('✅ Transcription successful!');
        console.log('Transcript:', transcription.text);

    } catch (error) {
        console.error('❌ Error during test:', error);
    }
}

testFetchAndTranscribe();
