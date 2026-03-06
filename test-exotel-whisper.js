const { OpenAI } = require('openai');
const fs = require('fs');
const https = require('https');
const path = require('path');

async function downloadFile(url, dest, headers) {
    return new Promise((resolve, reject) => {
        const file = fs.createWriteStream(dest);
        https.get(url, { headers }, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`Failed to get '${url}' (${response.statusCode})`));
                return;
            }
            response.pipe(file);
            file.on('finish', () => {
                file.close(resolve);
            });
        }).on('error', (err) => {
            fs.unlink(dest, () => reject(err));
        });
    });
}

async function main() {
    const openai = new OpenAI({
        apiKey: process.env.GROQ_API_KEY,
        baseURL: 'https://api.groq.com/openai/v1',
    });

    const exotelApiKey = process.env.EXOTEL_API_KEY;
    const exotelApiToken = process.env.EXOTEL_API_TOKEN;

    const urls = [
        "https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744617.3352439_0.mp3",
        "https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744464.2727329_0.mp3"
    ];

    const headers = {};
    if (exotelApiKey && exotelApiToken) {
        const credentials = Buffer.from(`${exotelApiKey}:${exotelApiToken}`).toString('base64');
        headers['Authorization'] = `Basic ${credentials}`;
    }

    for (let i = 0; i < urls.length; i++) {
        console.log(`\n\n=== Processing Audio ${i + 1} ===`);
        console.log(`URL: ${urls[i]}`);

        const tempFilePath = path.join(__dirname, `temp_audio_${i}.mp3`);

        try {
            console.log('Downloading audio to disk...');
            await downloadFile(urls[i], tempFilePath, headers);

            console.log('Sending to Whisper...');
            const audioFile = fs.createReadStream(tempFilePath);

            const transcription = await openai.audio.transcriptions.create({
                file: audioFile,
                model: 'whisper-large-v3',
            });

            console.log('\n--- Transcription Result ---');
            console.log(transcription.text);
            console.log('----------------------------\n');
        } catch (e) {
            console.error('Error processing:', e.message);
        } finally {
            if (fs.existsSync(tempFilePath)) {
                fs.unlinkSync(tempFilePath);
            }
        }
    }
}

main();
