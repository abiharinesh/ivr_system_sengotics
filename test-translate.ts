import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
dotenv.config();

const prisma = new PrismaClient({
    datasourceUrl: process.env.DATABASE_URL,
});

async function testTranslation() {
    let googleKey = process.env.GOOGLE_SPEECH_API_KEY;
    if (!googleKey) {
        try {
            const setting = await prisma.systemSettings.findUnique({ where: { key: 'google_speech_api_key' } });
            googleKey = setting?.value ?? undefined;
        } catch { }
    }

    console.log(`Using Key: ${googleKey ? googleKey.substring(0, 8) + '***' : 'NONE'}`);

    if (!googleKey) {
        console.log("No key found");
        return;
    }

    const text = 'மாரியம்மன் கோவில் கிட்ட';
    const url = `https://translation.googleapis.com/language/translate/v2?key=${googleKey}`;

    console.log(`Sending: ${text}`);

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ q: text, target: 'en' }),
        });

        console.log(`HTTP Status: ${response.status}`);

        const data = await response.json();
        console.log(`Response JSON:`, JSON.stringify(data, null, 2));

        if (data?.data?.translations?.[0]?.translatedText) {
            const translated = data.data.translations[0].translatedText.replace(/&#(\d+);/g, (match: string, dec: number) => {
                return String.fromCharCode(dec)
            }).replace(/&quot;/g, '"').replace(/&amp;/g, '&');
            console.log(`\nFinal translated text: -> ${translated} <-`);
        } else {
            console.log("Translation key not found in response.");
        }
    } catch (e) {
        console.error("Fetch threw error:", e);
    }
}

testTranslation().catch(console.error).finally(() => prisma.$disconnect());
