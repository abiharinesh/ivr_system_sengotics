import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Injectable()
export class DbSetupService {
    constructor(private prisma: PrismaService) { }

    async bootstrapDb() {
        console.log('🔍 Checking database status...');

        try {
            // 1. Ensure PostGIS extension exists
            await this.prisma.$executeRawUnsafe('CREATE EXTENSION IF NOT EXISTS postgis;');
            console.log('✅ PostGIS extension checked/enabled.');

            // 2. Check if we need to seed (look for panchayats)
            const panchayatCount = await this.prisma.panchayat.count();

            if (panchayatCount === 0) {
                console.log('🌱 Database is empty. Starting auto-seed...');
                await this.seed();
                console.log('🎉 Database auto-seeded successfully!');
            } else {
                console.log(`ℹ️ Database already contains ${panchayatCount} panchayats. Skipping auto-seed.`);
            }
        } catch (error) {
            console.error('❌ Database bootstrapping failed:', error.message);
            // We don't want to crash the app if seeding fails (e.g. migration hasn't run yet)
            // Vercel will retry the setup on next request
        }
    }

    private async seed() {
        // Refactored from prisma/seed.ts
        const panchayat1 = await this.prisma.panchayat.create({
            data: {
                name: 'Thayanur',
                center_lat: 11.0168,
                center_lng: 76.9558,
                ivr_number: '04442123456'
            }
        });

        const panchayat2 = await this.prisma.panchayat.create({
            data: {
                name: 'Vadavalli',
                center_lat: 11.0234,
                center_lng: 76.9012,
                ivr_number: '04442123457'
            }
        });

        const panchayat3 = await this.prisma.panchayat.create({
            data: {
                name: 'Kurichi',
                center_lat: 11.0089,
                center_lng: 76.9345,
                ivr_number: '04442123458'
            }
        });

        await this.prisma.$executeRaw`
      INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id)
      VALUES 
        ('POLE-TY-001', 11.0170, 76.9560, ST_SetSRID(ST_MakePoint(76.9560, 11.0170), 4326), ${panchayat1.id}),
        ('POLE-TY-002', 11.0165, 76.9555, ST_SetSRID(ST_MakePoint(76.9555, 11.0165), 4326), ${panchayat1.id}),
        ('POLE-TY-003', 11.0172, 76.9562, ST_SetSRID(ST_MakePoint(76.9562, 11.0172), 4326), ${panchayat1.id}),
        ('POLE-VD-001', 11.0236, 76.9015, ST_SetSRID(ST_MakePoint(76.9015, 11.0236), 4326), ${panchayat2.id}),
        ('POLE-VD-002', 11.0232, 76.9010, ST_SetSRID(ST_MakePoint(76.9010, 11.0232), 4326), ${panchayat2.id}),
        ('POLE-KR-001', 11.0091, 76.9348, ST_SetSRID(ST_MakePoint(76.9348, 11.0091), 4326), ${panchayat3.id}),
        ('POLE-KR-002', 11.0087, 76.9342, ST_SetSRID(ST_MakePoint(76.9342, 11.0087), 4326), ${panchayat3.id})
    `;

        const voiceCall1 = await this.prisma.voiceCall.create({
            data: {
                call_sid: 'VOICE-001-BOOTSTRAP',
                audio_url: 'https://example.com/audio/sample1.mp3',
                transcript: 'Inside Thayanur opposite ITC office the light pole is not working',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'ITC office',
                    direction: 'opposite',
                    complaint_type: 'light pole not working',
                    confidence_score: 0.92
                },
                processing_status: 'completed',
                confidence_score: 0.92
            }
        });

        const allPoles = await this.prisma.electricPole.findMany();

        await this.prisma.complaint.createMany({
            data: [
                {
                    voice_call_id: voiceCall1.id,
                    pole_id: allPoles[0].id,
                    panchayat_id: panchayat1.id,
                    complaint_type: 'light pole not working',
                    description: 'Inside Thayanur opposite ITC office the light pole is not working',
                    status: 'pending'
                }
            ]
        });
    }
}
