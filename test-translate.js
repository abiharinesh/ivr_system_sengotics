require('dotenv').config();

async function testTranslation() {
    const googleKey = process.env.GOOGLE_SPEECH_API_KEY;
    if (!googleKey) {
        console.error('GOOGLE_SPEECH_API_KEY is not defined in .env');
        return;
    }

    const textToTranslate = 'வணக்கம், இது ஒரு சோதனை'; // "Hello, this is a test" in Tamil

    const url = `https://translation.googleapis.com/language/translate/v2?key=${googleKey}`;
    
    console.log(`Testing Translation API with text: "${textToTranslate}"`);

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ q: textToTranslate, target: 'en' })
        });
        
        if (!response.ok) {
            console.error(`API Error: ${response.status} ${response.statusText}`);
            const text = await response.text();
            console.error(text);
            return;
        }
        
        const data = await response.json();
        
        if (data?.data?.translations?.[0]?.translatedText) {
            let translated = data.data.translations[0].translatedText.replace(/&#(\d+);/g, (match, dec) => {
                return String.fromCharCode(dec);
            }).replace(/&quot;/g, '"').replace(/&amp;/g, '&');
            
            console.log(`Success! Translated text: "${translated}"`);
        } else {
            console.error('Unexpected API response format:', JSON.stringify(data, null, 2));
        }
    } catch (err) {
        console.error('Error during fetch:', err);
    }
}

testTranslation();
