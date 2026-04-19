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
        const execSafe = async (sql: string) => {
            try {
                await this.prisma.$executeRawUnsafe(sql)
            } catch (err) {
                console.warn('⚠️ Schema step failed (non-fatal):', err?.message ?? err)
            }
        }

        // Users/auth compatibility
        await execSafe(`
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                email TEXT UNIQUE,
                password_hash TEXT,
                role TEXT NOT NULL DEFAULT 'panchayat_admin',
                panchayat_id INTEGER NULL,
                phone_e164 TEXT NULL,
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `)
        await execSafe(`ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;`)
        await execSafe(`ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;`)
        await execSafe(`ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'panchayat_admin';`)
        await execSafe(`ALTER TABLE users ADD COLUMN IF NOT EXISTS panchayat_id INTEGER;`)
        await execSafe(`ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_e164 TEXT;`)
        await execSafe(`ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;`)
        await execSafe(`CREATE UNIQUE INDEX IF NOT EXISTS users_email_key ON users(email);`)
        await execSafe(`
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint WHERE conname = 'users_panchayat_id_fkey'
                ) THEN
                    ALTER TABLE users
                        ADD CONSTRAINT users_panchayat_id_fkey
                        FOREIGN KEY (panchayat_id) REFERENCES panchayats(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
            END $$;
        `)

        // Voice pipeline compatibility
        await execSafe(`ALTER TABLE voice_calls ADD COLUMN IF NOT EXISTS transcript_english TEXT;`)
        await execSafe(`ALTER TABLE voice_calls ADD COLUMN IF NOT EXISTS attempt_number INTEGER NOT NULL DEFAULT 1;`)
        await execSafe(`
            CREATE UNIQUE INDEX IF NOT EXISTS voice_calls_call_sid_audio_url_key
            ON voice_calls(call_sid, audio_url);
        `)
        await execSafe(`
            CREATE INDEX IF NOT EXISTS voice_calls_call_sid_attempt_number_idx
            ON voice_calls(call_sid, attempt_number);
        `)

        // Poles compatibility
        await execSafe(`ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS keypad_id TEXT;`)
        await execSafe(`ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS landmarks TEXT[] DEFAULT '{}';`)
        await execSafe(`ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_url TEXT;`)
        await execSafe(`ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_latitude DOUBLE PRECISION;`)
        await execSafe(`ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_longitude DOUBLE PRECISION;`)
        await execSafe(`ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_captured_at TIMESTAMP(3);`)
        await execSafe(`ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_uploaded_at TIMESTAMP(3);`)
        await execSafe(`ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_uploaded_by INTEGER;`)
        await execSafe(`
            CREATE UNIQUE INDEX IF NOT EXISTS electric_poles_panchayat_id_keypad_id_key
            ON electric_poles(panchayat_id, keypad_id);
        `)
        await execSafe(`
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint WHERE conname = 'electric_poles_image_uploaded_by_fkey'
                ) THEN
                    ALTER TABLE electric_poles
                        ADD CONSTRAINT electric_poles_image_uploaded_by_fkey
                        FOREIGN KEY (image_uploaded_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
            END $$;
        `)

        // Complaints compatibility
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS caller_language TEXT;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS caller_emotion TEXT;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS urgency_level TEXT;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS audio_url TEXT;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS category TEXT;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS whatsapp_done_ack_at TIMESTAMP(3);`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS assigned_electrician_id INTEGER;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP(3);`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP(3);`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_image_url TEXT;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_note TEXT;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_image_latitude DOUBLE PRECISION;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_image_longitude DOUBLE PRECISION;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_image_captured_at TIMESTAMP(3);`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_distance_meters DOUBLE PRECISION;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_location_valid BOOLEAN;`)
        await execSafe(`ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_submitted_key TEXT;`)
        await execSafe(`
            CREATE UNIQUE INDEX IF NOT EXISTS complaints_resolution_submitted_key_key
            ON complaints(resolution_submitted_key);
        `)
        await execSafe(`
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint WHERE conname = 'complaints_assigned_electrician_id_fkey'
                ) THEN
                    ALTER TABLE complaints
                        ADD CONSTRAINT complaints_assigned_electrician_id_fkey
                        FOREIGN KEY (assigned_electrician_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
            END $$;
        `)

        // Call-state table used by admin state API
        await execSafe(`
            CREATE TABLE IF NOT EXISTS call_state (
                id SERIAL PRIMARY KEY,
                call_sid TEXT UNIQUE NOT NULL,
                phase1_status TEXT NOT NULL DEFAULT 'pending',
                phase2_status TEXT NOT NULL DEFAULT 'pending',
                complaint_created BOOLEAN NOT NULL DEFAULT FALSE,
                complaint_id INTEGER NULL,
                phase1_voice_call_id INTEGER NULL,
                phase2_voice_call_id INTEGER NULL,
                finalized_at TIMESTAMP NULL,
                last_error TEXT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMP NOT NULL DEFAULT NOW()
            );
        `)
        await execSafe(`CREATE INDEX IF NOT EXISTS call_state_call_sid_idx ON call_state(call_sid);`)

        // Settings/exports tables used by dashboard flows
        await execSafe(`
            CREATE TABLE IF NOT EXISTS system_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `)
        await execSafe(`
            CREATE TABLE IF NOT EXISTS export_jobs (
                id SERIAL PRIMARY KEY,
                created_by_user_id INTEGER NOT NULL,
                panchayat_id INTEGER NULL,
                electrician_user_id INTEGER NOT NULL,
                range_from TIMESTAMP(3) NOT NULL,
                range_to TIMESTAMP(3) NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                result_relative_path TEXT NULL,
                error_message TEXT NULL,
                row_count INTEGER NULL,
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
                completed_at TIMESTAMP(3) NULL
            );
        `)
        await execSafe(`CREATE INDEX IF NOT EXISTS export_jobs_electrician_user_id_idx ON export_jobs(electrician_user_id);`)
        await execSafe(`CREATE INDEX IF NOT EXISTS export_jobs_status_idx ON export_jobs(status);`)
        await execSafe(`
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'export_jobs_created_by_user_id_fkey') THEN
                    ALTER TABLE export_jobs
                        ADD CONSTRAINT export_jobs_created_by_user_id_fkey
                        FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'export_jobs_electrician_user_id_fkey') THEN
                    ALTER TABLE export_jobs
                        ADD CONSTRAINT export_jobs_electrician_user_id_fkey
                        FOREIGN KEY (electrician_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'export_jobs_panchayat_id_fkey') THEN
                    ALTER TABLE export_jobs
                        ADD CONSTRAINT export_jobs_panchayat_id_fkey
                        FOREIGN KEY (panchayat_id) REFERENCES panchayats(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
            END $$;
        `)

        console.log('✅ Schema columns verified/added.')
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
