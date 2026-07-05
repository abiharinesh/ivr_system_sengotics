"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const client_1 = require("@prisma/client");
const adapter_pg_1 = require("@prisma/adapter-pg");
const pg_1 = require("pg");
const { randomUUID } = require("crypto");

const pool = new pg_1.Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new adapter_pg_1.PrismaPg(pool);
const prisma = new client_1.PrismaClient({ adapter });

async function main() {
    console.log('🌱 Starting database seed...');

    // ── Clear existing data ──────────────────────────────────────────────
    console.log('🧹 Clearing existing data...');
    await prisma.complaint.deleteMany();
    await prisma.electricPole.deleteMany();
    await prisma.voiceCall.deleteMany();
    await prisma.ivrPollInput.deleteMany();
    await prisma.ivrServiceSelection.deleteMany();
    await prisma.callsMaster.deleteMany();
    await prisma.panchayat.deleteMany();

    // ══════════════════════════════════════════════════════════════════════
    //  PANCHAYATS
    // ══════════════════════════════════════════════════════════════════════

    console.log('🏘️  Creating panchayats...');

    const thayanur = await prisma.panchayat.create({
        data: { name: 'Thayanur', ivr_number: '04440115043', center_lat: 11.0168, center_lng: 76.9558 }
    });

    const tholampalay = await prisma.panchayat.create({
        data: { name: 'Tholampalay', ivr_number: '04440115434', center_lat: 11.2420, center_lng: 76.9520 }
    });

    console.log(`✅ Created 2 panchayats (Thayanur, Tholampalay)`);

    // ══════════════════════════════════════════════════════════════════════
    //  ELECTRIC POLES (with landmarks in Tamil + Tanglish + English)
    // ══════════════════════════════════════════════════════════════════════

    console.log('🔌 Creating electric poles with landmarks...');

    const polesData = [

        // ─── THAYANUR — 10 poles ─────────────────────────────────────────
        {
            pole_number: 'TY-001', keypad_id: '1', lat: 11.0170, lng: 76.9560, panchayat_id: thayanur.id,
            landmarks: [
                'மாரியம்மன் கோயில் பக்கத்துல',
                'மாரியம்மன் கோயில் கிட்ட',
                'Mariamman kovil pakkathula',
                'Mariamman kovil kitta',
                'Mariamman temple pakkam',
                'near Mariamman temple',
                'beside Mariamman temple',
            ]
        },
        {
            pole_number: 'TY-002', keypad_id: '2', lat: 11.0165, lng: 76.9555, panchayat_id: thayanur.id,
            landmarks: [
                'அரசு பள்ளி பக்கத்துல',
                'ஸ்கூல் கிட்ட',
                'government school pakkathula',
                'school kitta',
                'school pakkam',
                'near government school',
                'beside the school',
            ]
        },
        {
            pole_number: 'TY-003', keypad_id: '3', lat: 11.0172, lng: 76.9562, panchayat_id: thayanur.id,
            landmarks: [
                'பஸ் ஸ்டாண்ட் பக்கத்துல',
                'பஸ் ஸ்டாப் கிட்ட',
                'bus stand pakkathula',
                'bus stop kitta',
                'bus stand pakkam',
                'near bus stand',
                'near bus stop',
            ]
        },
        {
            pole_number: 'TY-004', keypad_id: '4', lat: 11.0175, lng: 76.9565, panchayat_id: thayanur.id,
            landmarks: [
                'ரேஷன் கடை பக்கத்துல',
                'ரேஷன் கடை கிட்ட',
                'ration kadai pakkathula',
                'ration kadai kitta',
                'ration shop pakkam',
                'near ration shop',
                'beside ration shop',
            ]
        },
        {
            pole_number: 'TY-005', keypad_id: '5', lat: 11.0160, lng: 76.9550, panchayat_id: thayanur.id,
            landmarks: [
                'தண்ணி டேங்க் பக்கத்துல',
                'வாட்டர் டேங்க் கிட்ட',
                'thanni tank pakkathula',
                'water tank kitta',
                'water tank pakkam',
                'near water tank',
                'beside the water tank',
            ]
        },
        {
            pole_number: 'TY-006', keypad_id: '6', lat: 11.0178, lng: 76.9568, panchayat_id: thayanur.id,
            landmarks: [
                'பெட்ரோல் பங்க் பக்கத்துல',
                'பெட்ரோல் பங்க் கிட்ட',
                'petrol bunk pakkathula',
                'petrol bunk kitta',
                'petrol pump pakkam',
                'near petrol bunk',
                'near petrol pump',
            ]
        },
        {
            pole_number: 'TY-007', keypad_id: '7', lat: 11.0162, lng: 76.9552, panchayat_id: thayanur.id,
            landmarks: [
                'ஆலமரம் கீழ',
                'பெரிய மரம் கிட்ட',
                'aalamaram keezha',
                'periya maram kitta',
                'banyan tree pakkam',
                'under the banyan tree',
                'near the big tree',
            ]
        },
        {
            pole_number: 'TY-008', keypad_id: '8', lat: 11.0168, lng: 76.9558, panchayat_id: thayanur.id,
            landmarks: [
                'பஞ்சாயத்து ஆபிஸ் பக்கத்துல',
                'பஞ்சாயத்து ஆபிஸ் கிட்ட',
                'panchayat office pakkathula',
                'panchayat office kitta',
                'panchayathu office pakkam',
                'near panchayat office',
                'beside panchayat office',
            ]
        },
        {
            pole_number: 'TY-009', keypad_id: '9', lat: 11.0182, lng: 76.9572, panchayat_id: thayanur.id,
            landmarks: [
                'ஆஸ்பத்திரி பக்கத்துல',
                'ஆஸ்பத்திரி கிட்ட',
                'hospital pakkathula',
                'aaspatri kitta',
                'hospital pakkam',
                'near hospital',
                'near the clinic',
            ]
        },
        {
            pole_number: 'TY-010', keypad_id: '10', lat: 11.0155, lng: 76.9545, panchayat_id: thayanur.id,
            landmarks: [
                'விநாயகர் கோயில் பக்கத்துல',
                'பிள்ளையார் கோயில் கிட்ட',
                'Vinayagar kovil pakkathula',
                'Pillaiyar kovil kitta',
                'Ganesh temple pakkam',
                'near Vinayagar temple',
                'near Pillaiyar temple',
            ]
        },

        // ─── THOLAMPALAY — 10 poles ──────────────────────────────────────
        {
            pole_number: 'TH-001', keypad_id: '1', lat: 11.2425, lng: 76.9525, panchayat_id: tholampalay.id,
            landmarks: [
                'மெயின் ரோடு ஜங்ஷன் பக்கத்துல',
                'மெயின் ரோடு கிட்ட',
                'main road junction pakkathula',
                'main road kitta',
                'junction pakkam',
                'near main road junction',
                'at the main road junction',
            ]
        },
        {
            pole_number: 'TH-002', keypad_id: '2', lat: 11.2418, lng: 76.9518, panchayat_id: tholampalay.id,
            landmarks: [
                'மாரியம்மன் கோயில் பக்கத்துல',
                'கோயில் கிட்ட',
                'Mariamman kovil pakkathula',
                'kovil kitta',
                'temple pakkam',
                'near Mariamman temple',
                'beside the temple',
            ]
        },
        {
            pole_number: 'TH-003', keypad_id: '3', lat: 11.2430, lng: 76.9530, panchayat_id: tholampalay.id,
            landmarks: [
                'ஆலமரம் கீழ',
                'பெரிய ஆலமரம் கிட்ட',
                'aalamaram keezha',
                'periya aalamaram kitta',
                'banyan tree keezha',
                'under the banyan tree',
                'near the big banyan tree',
            ]
        },
        {
            pole_number: 'TH-004', keypad_id: '4', lat: 11.2412, lng: 76.9512, panchayat_id: tholampalay.id,
            landmarks: [
                'குளம் பக்கத்துல',
                'குளக்கரை கிட்ட',
                'kulam pakkathula',
                'kulam kitta',
                'pond pakkam',
                'near the pond',
                'beside the village pond',
            ]
        },
        {
            pole_number: 'TH-005', keypad_id: '5', lat: 11.2435, lng: 76.9535, panchayat_id: tholampalay.id,
            landmarks: [
                'ரேஷன் கடை பக்கத்துல',
                'ரேஷன் கடை கிட்ட',
                'ration kadai pakkathula',
                'ration kadai kitta',
                'ration shop pakkam',
                'near ration shop',
                'beside ration shop',
            ]
        },
        {
            pole_number: 'TH-006', keypad_id: '6', lat: 11.2408, lng: 76.9508, panchayat_id: tholampalay.id,
            landmarks: [
                'ஸ்கூல் கேட் பக்கத்துல',
                'பள்ளி கிட்ட',
                'school gate pakkathula',
                'school kitta',
                'palli pakkam',
                'near school gate',
                'near the school',
            ]
        },
        {
            pole_number: 'TH-007', keypad_id: '7', lat: 11.2440, lng: 76.9540, panchayat_id: tholampalay.id,
            landmarks: [
                'டீ கடை பக்கத்துல',
                'டீ கடை கிட்ட',
                'tea kadai pakkathula',
                'tea kadai kitta',
                'tea shop pakkam',
                'near the tea shop',
                'beside the tea stall',
            ]
        },
        {
            pole_number: 'TH-008', keypad_id: '8', lat: 11.2402, lng: 76.9502, panchayat_id: tholampalay.id,
            landmarks: [
                'பஞ்சாயத்து ஆபிஸ் பக்கத்துல',
                'பஞ்சாயத்து ஆபிஸ் கிட்ட',
                'panchayat office pakkathula',
                'panchayathu office kitta',
                'panchayat office pakkam',
                'near panchayat office',
                'beside panchayat office',
            ]
        },
        {
            pole_number: 'TH-009', keypad_id: '9', lat: 11.2445, lng: 76.9545, panchayat_id: tholampalay.id,
            landmarks: [
                'மசூதி பக்கத்துல',
                'பள்ளிவாசல் கிட்ட',
                'masjid pakkathula',
                'pallivasal kitta',
                'mosque pakkam',
                'near the mosque',
                'beside the masjid',
            ]
        },
        {
            pole_number: 'TH-010', keypad_id: '10', lat: 11.2398, lng: 76.9498, panchayat_id: tholampalay.id,
            landmarks: [
                'சர்ச் பக்கத்துல',
                'சர்ச் கிட்ட',
                'church pakkathula',
                'church kitta',
                'church pakkam',
                'near the church',
                'beside the church',
            ]
        },
    ];

    // Insert all poles with PostGIS geometry + landmarks
    for (const p of polesData) {
        const token = randomUUID();
        await prisma.$executeRaw`
            INSERT INTO electric_poles (pole_number, keypad_id, latitude, longitude, location, panchayat_id, landmarks, public_report_token)
            VALUES (
                ${p.pole_number}, ${p.keypad_id}, ${p.lat}, ${p.lng},
                ST_SetSRID(ST_MakePoint(${p.lng}, ${p.lat}), 4326),
                ${p.panchayat_id},
                ${p.landmarks},
                ${token}
            )
        `;
    }

    const totalPoles = await prisma.electricPole.count();
    console.log(`✅ Created ${totalPoles} electric poles (${totalPoles / 2} per panchayat)`);

    // ══════════════════════════════════════════════════════════════════════
    //  SYSTEM SETTINGS
    // ══════════════════════════════════════════════════════════════════════

    await prisma.systemSettings.upsert({
        where: { key: 'ai_provider' },
        update: {},
        create: { key: 'ai_provider', value: 'gemini' }
    });
    console.log(`✅ System settings seeded (ai_provider = gemini)`);

    // ══════════════════════════════════════════════════════════════════════
    //  SUMMARY
    // ══════════════════════════════════════════════════════════════════════

    console.log('\n🎉 Database seeded successfully!');
    console.log('\nSummary:');
    console.log(`  Panchayats:      2 (Thayanur, Tholampalay)`);
    console.log(`  Electric Poles:  ${totalPoles} (10 per panchayat)`);
    console.log(`  Landmarks/pole:  7 (Tamil + Tanglish + English)`);
    console.log(`  AI Provider:     gemini`);
}

main()
    .catch((e) => {
        console.error('❌ Error seeding database:', e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });