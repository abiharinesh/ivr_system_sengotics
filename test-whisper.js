const { OpenAI } = require('openai');
const fs = require('fs');

async function main() {
    const openai = new OpenAI({
        apiKey: process.env.GROQ_API_KEY,
        baseURL: 'https://api.groq.com/openai/v1',
    });

    const audioPath = process.argv[2];
    if (!audioPath) {
        console.error('Usage: node test-whisper.js <path-to-audio-file>');
        process.exit(1);
    }

    const audioFile = fs.createReadStream(audioPath);

    try {
        console.log('Sending audio to Whisper (without language constraints)...');
        const transcription = await openai.audio.transcriptions.create({
            file: audioFile,
            model: 'whisper-large-v3',
        });

        console.log('\n--- Transcription Result ---');
        console.log(transcription.text);
        console.log('----------------------------\n');
    } catch (e) {
        console.error('Error:', e.message);
    }
}

main();
