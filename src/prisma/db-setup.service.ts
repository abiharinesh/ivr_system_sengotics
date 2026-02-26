import { Injectable } from '@nestjs/common'
import { PrismaService } from './prisma.service'

@Injectable()
export class DbSetupService {
    constructor(private prisma: PrismaService) { }

    async bootstrapDb() {
        console.log('🔍 Checking database status...')

        try {
            // 1. Ensure PostGIS extension exists
            await this.prisma.$executeRawUnsafe('CREATE EXTENSION IF NOT EXISTS postgis;')
            console.log('✅ PostGIS extension checked/enabled.')

            // 2. Ensure all schema columns exist (safe to re-run, uses IF NOT EXISTS)
            await this.ensureSchema()

            // 3. Check if we need to seed
            const panchayatCount = await this.prisma.panchayat.count()

            if (panchayatCount === 0) {
                console.log('🌱 Database is empty. Starting auto-seed...')
                await this.seed()
                console.log('🎉 Database auto-seeded successfully!')
            } else {
                console.log(`ℹ️ Database already contains ${panchayatCount} panchayats. Skipping auto-seed.`)
            }
        } catch (error) {
            console.error('❌ Database bootstrapping failed:', error.message)
        }
    }

    /**
     * Safely adds any columns that may be missing from the production DB
     * (added after the initial migration). Safe to run repeatedly.
     */
    private async ensureSchema() {
        try {
            await this.prisma.$executeRawUnsafe(`
                ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS keypad_id TEXT;
            `)
            await this.prisma.$executeRawUnsafe(`
                ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS landmarks TEXT[] DEFAULT '{}';
            `)
            // Unique constraint on (panchayat_id, keypad_id) — idempotent
            await this.prisma.$executeRawUnsafe(`
                DO $$ BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_constraint
                        WHERE conname = 'electric_poles_panchayat_id_keypad_id_key'
                    ) THEN
                        ALTER TABLE electric_poles
                            ADD CONSTRAINT electric_poles_panchayat_id_keypad_id_key
                            UNIQUE (panchayat_id, keypad_id);
                    END IF;
                END $$;
            `)
            console.log('✅ Schema columns verified/added.')
        } catch (err) {
            console.warn('⚠️ Schema migration step failed (non-fatal):', err.message)
        }
    }

    private async seed() {
        // ── Panchayat ──────────────────────────────────────────────────────
        // ivr_number MUST match the actual Exotel IVR number (from Vercel logs: 04440115043)
        const panchayat1 = await this.prisma.panchayat.create({
            data: {
                name: 'Thayanur',
                center_lat: 11.0168,
                center_lng: 76.9558,
                ivr_number: '04440115043'
            }
        })

        // ── Electric Poles with keypad IDs and landmarks ───────────────────
        await this.prisma.$executeRaw`
          INSERT INTO electric_poles (pole_number, keypad_id, latitude, longitude, location, panchayat_id, landmarks)
          VALUES
            ('POLE-TY-001', '1', 11.0170, 76.9560, ST_SetSRID(ST_MakePoint(76.9560, 11.0170), 4326), ${panchayat1.id}, ARRAY['ITC office', 'opposite ITC factory', 'ITC gate']),
            ('POLE-TY-002', '2', 11.0165, 76.9555, ST_SetSRID(ST_MakePoint(76.9555, 11.0165), 4326), ${panchayat1.id}, ARRAY['bus stop', 'bus stand', 'government bus stop']),
            ('POLE-TY-003', '3', 11.0172, 76.9562, ST_SetSRID(ST_MakePoint(76.9562, 11.0172), 4326), ${panchayat1.id}, ARRAY['temple', 'kovil', 'murugan kovil', 'near temple'])
        `
        console.log('✅ Seeded Thayanur with 3 poles and landmarks')
    }
}
