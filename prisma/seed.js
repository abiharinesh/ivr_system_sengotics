"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const client_1 = require("@prisma/client");
const adapter_pg_1 = require("@prisma/adapter-pg");
const pg_1 = require("pg");
const pool = new pg_1.Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new adapter_pg_1.PrismaPg(pool);
const prisma = new client_1.PrismaClient({ adapter });
async function main() {
    console.log('🌱 Starting database seed...');
    console.log('Clearing existing data...');
    await prisma.complaint.deleteMany();
    await prisma.electricPole.deleteMany();
    await prisma.voiceCall.deleteMany();
    await prisma.ivrPollInput.deleteMany();
    await prisma.ivrServiceSelection.deleteMany();
    await prisma.callsMaster.deleteMany();
    await prisma.panchayat.deleteMany();
    console.log('Creating panchayats...');
    const panchayat1 = await prisma.panchayat.create({
        data: {
            name: 'Thayanur',
            center_lat: 11.0168,
            center_lng: 76.9558,
            ivr_number: '04440115043'
        }
    });
    const panchayat2 = await prisma.panchayat.create({
        data: {
            name: 'Vadavalli',
            center_lat: 11.0234,
            center_lng: 76.9012,
            ivr_number: '04440115434'
        }
    });
    const panchayat3 = await prisma.panchayat.create({
        data: {
            name: 'Kurichi',
            center_lat: 11.0089,
            center_lng: 76.9345,
            ivr_number: '04442123458'
        }
    });
    console.log(`✅ Created 3 panchayats`);
    console.log('Creating electric poles...');
    await prisma.$executeRaw`
    INSERT INTO electric_poles (pole_number, keypad_id, latitude, longitude, location, panchayat_id)
    VALUES 
      ('POLE-TY-001', '1', 11.0170, 76.9560, ST_SetSRID(ST_MakePoint(76.9560, 11.0170), 4326), ${panchayat1.id}),
      ('POLE-TY-002', '2', 11.0165, 76.9555, ST_SetSRID(ST_MakePoint(76.9555, 11.0165), 4326), ${panchayat1.id}),
      ('POLE-TY-003', '3', 11.0172, 76.9562, ST_SetSRID(ST_MakePoint(76.9562, 11.0172), 4326), ${panchayat1.id}),
      ('POLE-VD-001', '1', 11.0236, 76.9015, ST_SetSRID(ST_MakePoint(76.9015, 11.0236), 4326), ${panchayat2.id}),
      ('POLE-VD-002', '2', 11.0232, 76.9010, ST_SetSRID(ST_MakePoint(76.9010, 11.0232), 4326), ${panchayat2.id}),
      ('POLE-KR-001', '1', 11.0091, 76.9348, ST_SetSRID(ST_MakePoint(76.9348, 11.0091), 4326), ${panchayat3.id}),
      ('POLE-KR-002', '2', 11.0087, 76.9342, ST_SetSRID(ST_MakePoint(76.9342, 11.0087), 4326), ${panchayat3.id})
  `;
    const allPoles = await prisma.electricPole.findMany();
    console.log(`✅ Created ${allPoles.length} electric poles`);
    console.log('Creating sample I VR calls...');
    const call1 = await prisma.callsMaster.create({
        data: {
            call_sid: 'CALL-001-SAMPLE',
            caller_number: '9876543210',
            call_to: '04442123456',
            flow_id: 'flow-001',
            tenant_id: 'tenant-001',
            call_start_time: new Date('2026-02-13T10:00:00Z'),
            call_end_time: new Date('2026-02-13T10:02:30Z'),
            service_selected: true,
            poll_entered: true,
            final_call_status: 'SUCCESS'
        }
    });
    await prisma.ivrServiceSelection.create({
        data: {
            call_sid: call1.call_sid,
            caller_number: '9876543210',
            service_option: '1',
            raw_payload: { test: 'sample data' }
        }
    });
    await prisma.ivrPollInput.create({
        data: {
            call_sid: call1.call_sid,
            caller_number: '9876543210',
            poll_id: '8686',
            raw_payload: { test: 'sample data' }
        }
    });
    console.log(`✅ Created 1 sample IVR call`);
    console.log('Creating sample voice complaints...');
    const voiceCall1 = await prisma.voiceCall.create({
        data: {
            call_sid: 'VOICE-001-SAMPLE',
            audio_url: 'https://example.com/audio/sample1.mp3',
            transcript: 'Thayanur la Mariamman kovil pakathula light pole eraiyala',
            transcript_english: 'The light pole near Mariamman temple in Thayanur is not working',
            ai_extracted_json: {
                village: 'Thayanur',
                landmark: 'Mariamman kovil pakathula',
                landmark_english: 'near Mariamman temple',
                direction: 'beside',
                complaint_type: 'light pole not working',
                confidence_score: 0.92,
                transcript_english: 'The light pole near Mariamman temple in Thayanur is not working'
            },
            processing_status: 'completed',
            confidence_score: 0.92,
            attempt_number: 1
        }
    });
    const voiceCall2 = await prisma.voiceCall.create({
        data: {
            call_sid: 'VOICE-002-SAMPLE',
            audio_url: 'https://example.com/audio/sample2.mp3',
            transcript: 'Vadavalli bus stand pakkathula current poguthu',
            transcript_english: 'There is a power cut near bus stand in Vadavalli',
            ai_extracted_json: {
                village: 'Vadavalli',
                landmark: 'bus stand pakkathula',
                landmark_english: 'near bus stand',
                direction: 'near',
                complaint_type: 'power cut',
                confidence_score: 0.85,
                transcript_english: 'There is a power cut near bus stand in Vadavalli'
            },
            processing_status: 'completed',
            confidence_score: 0.85,
            attempt_number: 1
        }
    });
    console.log(`✅ Created 2 voice calls`);
    console.log('Creating complaints...');
    await prisma.complaint.createMany({
        data: [
            {
                voice_call_id: voiceCall1.id,
                pole_id: allPoles[0].id,
                panchayat_id: panchayat1.id,
                complaint_type: 'light pole not working',
                description: 'The light pole near Mariamman temple in Thayanur is not working',
                audio_url: 'https://example.com/audio/sample1.mp3',
                status: 'pending'
            },
            {
                voice_call_id: voiceCall2.id,
                pole_id: allPoles[3].id,
                panchayat_id: panchayat2.id,
                complaint_type: 'power cut',
                description: 'There is a power cut near bus stand in Vadavalli',
                audio_url: 'https://example.com/audio/sample2.mp3',
                status: 'in_progress'
            },
            {
                pole_id: allPoles[1].id,
                panchayat_id: panchayat1.id,
                complaint_type: 'wire damage',
                description: 'Manual complaint - wire damage near school',
                status: 'resolved'
            }
        ]
    });
    console.log(`✅ Created 3 complaints`);
    console.log('\n🎉 Database seeded successfully!');
    console.log('\nSummary:');
    console.log(`- Panchayats: 3`);
    console.log(`- Electric Poles: ${allPoles.length}`);
    console.log(`- IVR Calls: 1`);
    console.log(`- Voice Complaints: 2`);
    console.log(`- Total Complaints: 3`);
}
main()
    .catch((e) => {
        console.error('❌ Error seeding database:', e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
//# sourceMappingURL=seed.js.map