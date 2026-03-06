const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');
const path = require('path');
require('dotenv').config();

const urls = [
    'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744464.2727329_0.mp3',
    'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744617.3352439_0.mp3'
];

const apiKey = '0b05af13f3msh93eb0af75f27324p125ecfjsn27867461b99b';

async function downloadAndTranslate(url, index) {
    const filename = `exotel_${index}.mp3`;
    const filePath = path.join(__dirname, filename);

    console.log(`\nProcessing: ${url}`);

    try {
        // Step 1: Download
        console.log(`Downloading to ${filePath}...`);
        const response = await axios({
            method: 'GET',
            url: url,
            responseType: 'stream',
            auth: {
                username: process.env.EXOTEL_API_KEY,
                password: process.env.EXOTEL_API_TOKEN
            }
        });

        const writer = fs.createWriteStream(filePath);
        response.data.pipe(writer);

        await new Promise((resolve, reject) => {
            writer.on('finish', resolve);
            writer.on('error', reject);
        });

        console.log('Download complete. File size:', fs.statSync(filePath).size, 'bytes');

        // Step 2: Upload to RapidAPI
        console.log('Sending to RapidAPI for translation...');
        const form = new FormData();
        form.append('file', fs.createReadStream(filePath));

        const apiResponse = await axios.post('https://speech-to-text-ai.p.rapidapi.com/transcribe', form, {
            headers: {
                ...form.getHeaders(),
                'x-rapidapi-host': 'speech-to-text-ai.p.rapidapi.com',
                'x-rapidapi-key': apiKey
            }
        });

        console.log('Translation Result:\n', JSON.stringify(apiResponse.data, null, 2));

    } catch (error) {
        console.error('Error processing audio:', error.message);
        if (error.response) {
            console.error('API Error Response:', JSON.stringify(error.response.data, null, 2));
        }
    } finally {
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }
    }
}

async function run() {
    for (let i = 0; i < urls.length; i++) {
        await downloadAndTranslate(urls[i], i);
    }
}

run();
