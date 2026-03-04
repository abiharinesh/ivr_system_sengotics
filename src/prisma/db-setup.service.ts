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
        // ── NOTE: Use `npx prisma db seed` for proper seeding ────────────
        // The full seed data is in prisma/seed.ts with 20 poles and
        // multilingual landmarks (Tamil + Tanglish + English).
        // This inline seed is only a minimal fallback for fresh deployments.
        console.log('⚠️  Running minimal auto-seed. For full data, run: npx prisma db seed')

        await this.prisma.panchayat.create({
            data: {
                name: 'Thayanur',
                center_lat: 11.0168,
                center_lng: 76.9558,
                ivr_number: '04440115043'
            }
        })

        await this.prisma.panchayat.create({
            data: {
                name: 'Tholampalay',
                center_lat: 11.2420,
                center_lng: 76.9520,
                ivr_number: '04440115044'
            }
        })
        console.log('✅ Created 2 panchayats (minimal). Run `npx prisma db seed` for full pole data.')
    }
}
