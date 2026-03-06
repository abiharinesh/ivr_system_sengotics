const axios = require('axios');

async function testRapidAPI() {
    console.log('Testing RapidAPI Speech-to-Text...');
    try {
        const response = await axios.request({
            method: 'POST',
            url: 'https://speech-to-text-ai.p.rapidapi.com/transcribe',
            params: {
                url: 'https://cdn.openai.com/whisper/draft-20220913a/micro-machines.wav',
                lang: 'en',
                task: 'transcribe'
            },
            headers: {
                'x-rapidapi-host': 'speech-to-text-ai.p.rapidapi.com',
                'x-rapidapi-key': '0b05af13f3msh93eb0af75f27324p125ecfjsn27867461b99b'
            }
        });

        console.log('Success!');
        console.log(JSON.stringify(response.data, null, 2));
    } catch (error) {
        console.error('Error:', error.response ? error.response.data : error.message);
    }
}

testRapidAPI();
