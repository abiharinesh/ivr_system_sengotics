import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Injectable()
export class DbSetupService {
  constructor(private prisma: PrismaService) {}

  /**
   * Lightweight check for serverless (Vercel). Skips heavy ensureSchema() which can
   * exceed function timeouts on cold starts. Run full bootstrap locally or via CI/migrate.
   */
  async bootstrapDbLite() {
    console.log('🔍 Checking database status (lite)...');
    try {
      await this.prisma.$executeRawUnsafe(
        'CREATE EXTENSION IF NOT EXISTS postgis;',
      );
      await this.prisma.$queryRaw`SELECT 1`;
      console.log('✅ Database reachable (lite bootstrap).');
    } catch (error) {
      console.error('❌ Lite database check failed:', error.message);
      throw error;
    }
  }

  async bootstrapDb() {
    console.log('🔍 Checking database status...');

    try {
      // 1. Ensure PostGIS extension exists
      await this.prisma.$executeRawUnsafe(
        'CREATE EXTENSION IF NOT EXISTS postgis;',
      );
      console.log('✅ PostGIS extension checked/enabled.');

      // 2. Ensure all schema columns exist (safe to re-run, uses IF NOT EXISTS)
      await this.ensureSchema();

      // 3. Check if we need to seed
      const panchayatCount = await this.prisma.orgUnit.count();

      if (panchayatCount === 0) {
        console.log('🌱 Database is empty. Starting auto-seed...');
        await this.seed();
        console.log('🎉 Database auto-seeded successfully!');
      } else {
        console.log(
          `ℹ️ Database already contains ${panchayatCount} panchayats. Skipping auto-seed.`,
        );
      }
    } catch (error) {
      console.error('❌ Database bootstrapping failed:', error.message);
    }
  }

  /**
   * Safely adds any columns that may be missing from the production DB
   * (added after the initial migration). Safe to run repeatedly.
   */
  private async ensureSchema() {
    const execSafe = async (sql: string) => {
      try {
        await this.prisma.$executeRawUnsafe(sql);
      } catch (err) {
        console.warn('⚠️ Schema step failed (non-fatal):', err?.message ?? err);
      }
    };

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
        `);
    await execSafe(`ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;`);
    await execSafe(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;`,
    );
    await execSafe(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'panchayat_admin';`,
    );
    await execSafe(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS panchayat_id INTEGER;`,
    );
    await execSafe(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_e164 TEXT;`,
    );
    await execSafe(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;`,
    );
    await execSafe(
      `CREATE UNIQUE INDEX IF NOT EXISTS users_email_key ON users(email);`,
    );
    await execSafe(`
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint WHERE conname = 'users_panchayat_id_fkey'
                ) THEN
                    ALTER TABLE users
                        ADD CONSTRAINT users_panchayat_id_fkey
                        FOREIGN KEY (panchayat_id) REFERENCES org_units(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
            END $$;
        `);

    // Voice pipeline compatibility
    await execSafe(
      `ALTER TABLE voice_calls ADD COLUMN IF NOT EXISTS transcript_english TEXT;`,
    );
    await execSafe(
      `ALTER TABLE voice_calls ADD COLUMN IF NOT EXISTS attempt_number INTEGER NOT NULL DEFAULT 1;`,
    );
    await execSafe(`
            CREATE UNIQUE INDEX IF NOT EXISTS voice_calls_call_sid_audio_url_key
            ON voice_calls(call_sid, audio_url);
        `);
    await execSafe(`
            CREATE INDEX IF NOT EXISTS voice_calls_call_sid_attempt_number_idx
            ON voice_calls(call_sid, attempt_number);
        `);

    // Poles compatibility
    await execSafe(
      `ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS keypad_id TEXT;`,
    );
    await execSafe(
      `ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS landmarks TEXT[] DEFAULT '{}';`,
    );
    await execSafe(
      `ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_url TEXT;`,
    );
    await execSafe(
      `ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_latitude DOUBLE PRECISION;`,
    );
    await execSafe(
      `ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_longitude DOUBLE PRECISION;`,
    );
    await execSafe(
      `ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_captured_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_uploaded_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE electric_poles ADD COLUMN IF NOT EXISTS image_uploaded_by INTEGER;`,
    );
    await execSafe(`
            CREATE UNIQUE INDEX IF NOT EXISTS electric_poles_panchayat_id_keypad_id_key
            ON electric_poles(panchayat_id, keypad_id);
        `);
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
        `);

    // Complaints compatibility
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS caller_language TEXT;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS caller_emotion TEXT;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS urgency_level TEXT;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS audio_url TEXT;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS category TEXT;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS whatsapp_done_ack_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS assigned_electrician_id INTEGER;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_image_url TEXT;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_note TEXT;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_image_latitude DOUBLE PRECISION;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_image_longitude DOUBLE PRECISION;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_image_captured_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_distance_meters DOUBLE PRECISION;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_location_valid BOOLEAN;`,
    );
    await execSafe(
      `ALTER TABLE complaints ADD COLUMN IF NOT EXISTS resolution_submitted_key TEXT;`,
    );
    await execSafe(`
            CREATE UNIQUE INDEX IF NOT EXISTS complaints_resolution_submitted_key_key
            ON complaints(resolution_submitted_key);
        `);
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
        `);

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
        `);
    await execSafe(
      `CREATE INDEX IF NOT EXISTS call_state_call_sid_idx ON call_state(call_sid);`,
    );

    // Settings/exports tables used by dashboard flows
    await execSafe(`
            CREATE TABLE IF NOT EXISTS system_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
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
        `);
    await execSafe(
      `CREATE INDEX IF NOT EXISTS export_jobs_electrician_user_id_idx ON export_jobs(electrician_user_id);`,
    );
    await execSafe(
      `CREATE INDEX IF NOT EXISTS export_jobs_status_idx ON export_jobs(status);`,
    );
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
                        FOREIGN KEY (panchayat_id) REFERENCES org_units(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
            END $$;
        `);

    // ── Tender workflow tables (Phase 1) ─────────────────────────────
    await this.ensureTenderSchema(execSafe);

    console.log('✅ Schema columns verified/added.');
  }

  /** Idempotent CREATE TABLE / ADD CONSTRAINT statements for the tender workflow. */
  private async ensureTenderSchema(execSafe: (sql: string) => Promise<void>) {
    await execSafe(`
            CREATE TABLE IF NOT EXISTS vendors (
                id SERIAL PRIMARY KEY,
                panchayat_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                phone_e164 TEXT NOT NULL,
                place TEXT,
                notes TEXT,
                active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE UNIQUE INDEX IF NOT EXISTS vendors_panchayat_id_phone_e164_key ON vendors(panchayat_id, phone_e164);`,
    );
    await execSafe(
      `CREATE INDEX IF NOT EXISTS vendors_panchayat_id_idx ON vendors(panchayat_id);`,
    );

    await execSafe(`
            CREATE TABLE IF NOT EXISTS tenders (
                id SERIAL PRIMARY KEY,
                panchayat_id INTEGER NOT NULL,
                status TEXT NOT NULL DEFAULT 'draft',
                title_ta TEXT,
                title_en TEXT,
                narrative_ta TEXT,
                narrative_en TEXT,
                anchor_date TIMESTAMP(3),
                milestone_rules JSONB,
                quotation_access_mode TEXT NOT NULL DEFAULT 'invited_only',
                auto_resolve_linked_complaints BOOLEAN NOT NULL DEFAULT FALSE,
                officer_self_inspection BOOLEAN NOT NULL DEFAULT FALSE,
                public_token TEXT,
                awarded_quotation_id INTEGER,
                work_order_date TIMESTAMP(3),
                work_completed_at TIMESTAMP(3),
                inspection_done_at TIMESTAMP(3),
                inspection_notes TEXT,
                payment_meta JSONB,
                created_by_user_id INTEGER NOT NULL,
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE UNIQUE INDEX IF NOT EXISTS tenders_public_token_key ON tenders(public_token);`,
    );
    await execSafe(
      `CREATE UNIQUE INDEX IF NOT EXISTS tenders_awarded_quotation_id_key ON tenders(awarded_quotation_id);`,
    );
    await execSafe(
      `CREATE INDEX IF NOT EXISTS tenders_panchayat_id_status_idx ON tenders(panchayat_id, status);`,
    );

    await execSafe(`
            CREATE TABLE IF NOT EXISTS tender_line_items (
                id SERIAL PRIMARY KEY,
                tender_id INTEGER NOT NULL,
                seq INTEGER NOT NULL DEFAULT 1,
                description_ta TEXT,
                description_en TEXT,
                quantity DECIMAL(12,3),
                unit TEXT,
                pole_id INTEGER,
                complaint_id INTEGER
            );
        `);
    await execSafe(
      `CREATE INDEX IF NOT EXISTS tender_line_items_tender_id_idx ON tender_line_items(tender_id);`,
    );

    await execSafe(`
            CREATE TABLE IF NOT EXISTS tender_vendor_invites (
                id SERIAL PRIMARY KEY,
                tender_id INTEGER NOT NULL,
                vendor_id INTEGER NOT NULL,
                invite_token TEXT,
                invite_expires_at TIMESTAMP(3),
                invite_revoked_at TIMESTAMP(3),
                invite_opened_at TIMESTAMP(3),
                invite_submitted_at TIMESTAMP(3),
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE UNIQUE INDEX IF NOT EXISTS tender_vendor_invites_tender_id_vendor_id_key ON tender_vendor_invites(tender_id, vendor_id);`,
    );
    await execSafe(
      `ALTER TABLE tender_vendor_invites ADD COLUMN IF NOT EXISTS invite_token TEXT;`,
    );
    await execSafe(
      `ALTER TABLE tender_vendor_invites ADD COLUMN IF NOT EXISTS invite_expires_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE tender_vendor_invites ADD COLUMN IF NOT EXISTS invite_revoked_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE tender_vendor_invites ADD COLUMN IF NOT EXISTS invite_opened_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE tender_vendor_invites ADD COLUMN IF NOT EXISTS invite_submitted_at TIMESTAMP(3);`,
    );
    await execSafe(
      `CREATE UNIQUE INDEX IF NOT EXISTS tender_vendor_invites_invite_token_key ON tender_vendor_invites(invite_token);`,
    );
    await execSafe(
      `CREATE INDEX IF NOT EXISTS tender_vendor_invites_invite_token_invite_revoked_at_idx ON tender_vendor_invites(invite_token, invite_revoked_at);`,
    );
    await execSafe(`CREATE EXTENSION IF NOT EXISTS pgcrypto;`);
    await execSafe(`
            UPDATE tender_vendor_invites
            SET invite_token = encode(gen_random_bytes(24), 'hex')
            WHERE invite_token IS NULL;
        `);

    await execSafe(`
            CREATE TABLE IF NOT EXISTS tender_quotations (
                id SERIAL PRIMARY KEY,
                tender_id INTEGER NOT NULL,
                vendor_id INTEGER,
                submitter_name TEXT NOT NULL,
                submitter_phone_e164 TEXT NOT NULL,
                amount DECIMAL(12,2) NOT NULL,
                remarks TEXT,
                attachment_url TEXT,
                source TEXT NOT NULL DEFAULT 'officer_entry',
                screening_outcome TEXT NOT NULL DEFAULT 'pending',
                superseded_by_id INTEGER,
                submitted_ip_hash TEXT,
                submitted_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE INDEX IF NOT EXISTS tender_quotations_tender_id_idx ON tender_quotations(tender_id);`,
    );

    await execSafe(`
            CREATE TABLE IF NOT EXISTS tender_documents (
                id SERIAL PRIMARY KEY,
                tender_id INTEGER NOT NULL,
                template_id TEXT NOT NULL,
                vendor_id INTEGER,
                version INTEGER NOT NULL DEFAULT 1,
                field_overrides JSONB,
                storage_path TEXT,
                generated_at TIMESTAMP(3),
                generated_by_user_id INTEGER,
                status TEXT NOT NULL DEFAULT 'pending',
                error_message TEXT,
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE INDEX IF NOT EXISTS tender_documents_tender_id_template_id_idx ON tender_documents(tender_id, template_id);`,
    );

    await execSafe(`
            CREATE TABLE IF NOT EXISTS field_verification_sessions (
                id SERIAL PRIMARY KEY,
                tender_id INTEGER NOT NULL,
                token TEXT NOT NULL,
                expires_at TIMESTAMP(3),
                pole_subset_ids INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],
                created_by_user_id INTEGER NOT NULL,
                confirmed_at TIMESTAMP(3),
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE UNIQUE INDEX IF NOT EXISTS field_verification_sessions_token_key ON field_verification_sessions(token);`,
    );
    await execSafe(
      `CREATE INDEX IF NOT EXISTS field_verification_sessions_tender_id_idx ON field_verification_sessions(tender_id);`,
    );

    await execSafe(`
            CREATE TABLE IF NOT EXISTS field_verification_uploads (
                id SERIAL PRIMARY KEY,
                session_id INTEGER NOT NULL,
                image_url TEXT NOT NULL,
                exif_lat DOUBLE PRECISION,
                exif_lng DOUBLE PRECISION,
                captured_at TIMESTAMP(3),
                matched_pole_id INTEGER,
                manual_pole_id INTEGER,
                distance_meters DOUBLE PRECISION,
                match_confidence TEXT NOT NULL DEFAULT 'unmatched',
                notes TEXT,
                uploaded_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE INDEX IF NOT EXISTS field_verification_uploads_session_id_idx ON field_verification_uploads(session_id);`,
    );

    await execSafe(
      `ALTER TABLE field_verification_sessions ADD COLUMN IF NOT EXISTS label TEXT;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_lat DOUBLE PRECISION;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_lng DOUBLE PRECISION;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_address TEXT;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_raw_text TEXT;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_captured_at TIMESTAMP(3);`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_pole_number TEXT;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_keypad_id TEXT;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_matched_pole_id INTEGER;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS ocr_match_confidence TEXT NOT NULL DEFAULT 'skipped';`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS coord_source TEXT;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS matched_lat DOUBLE PRECISION;`,
    );
    await execSafe(
      `ALTER TABLE field_verification_uploads ADD COLUMN IF NOT EXISTS matched_lng DOUBLE PRECISION;`,
    );

    await execSafe(`
            CREATE TABLE IF NOT EXISTS tender_field_checklist_items (
                id SERIAL PRIMARY KEY,
                tender_id INTEGER NOT NULL,
                pole_id INTEGER,
                line_item_id INTEGER,
                is_done BOOLEAN NOT NULL DEFAULT FALSE,
                verified_upload_id INTEGER,
                notes TEXT,
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE INDEX IF NOT EXISTS tender_field_checklist_items_tender_id_idx ON tender_field_checklist_items(tender_id);`,
    );

    await execSafe(`
            CREATE TABLE IF NOT EXISTS tender_audit_logs (
                id SERIAL PRIMARY KEY,
                tender_id INTEGER NOT NULL,
                actor_user_id INTEGER,
                event TEXT NOT NULL,
                payload JSONB,
                created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await execSafe(
      `CREATE INDEX IF NOT EXISTS tender_audit_logs_tender_id_idx ON tender_audit_logs(tender_id);`,
    );

    await execSafe(
      `ALTER TABLE org_units ADD COLUMN IF NOT EXISTS document_template_settings JSONB;`,
    );

    // Foreign keys
    await execSafe(`
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vendors_panchayat_id_fkey') THEN
                    ALTER TABLE vendors ADD CONSTRAINT vendors_panchayat_id_fkey
                        FOREIGN KEY (panchayat_id) REFERENCES org_units(id) ON DELETE RESTRICT ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenders_panchayat_id_fkey') THEN
                    ALTER TABLE tenders ADD CONSTRAINT tenders_panchayat_id_fkey
                        FOREIGN KEY (panchayat_id) REFERENCES org_units(id) ON DELETE RESTRICT ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenders_created_by_user_id_fkey') THEN
                    ALTER TABLE tenders ADD CONSTRAINT tenders_created_by_user_id_fkey
                        FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenders_awarded_quotation_id_fkey') THEN
                    ALTER TABLE tenders ADD CONSTRAINT tenders_awarded_quotation_id_fkey
                        FOREIGN KEY (awarded_quotation_id) REFERENCES tender_quotations(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_line_items_tender_id_fkey') THEN
                    ALTER TABLE tender_line_items ADD CONSTRAINT tender_line_items_tender_id_fkey
                        FOREIGN KEY (tender_id) REFERENCES tenders(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_line_items_pole_id_fkey') THEN
                    ALTER TABLE tender_line_items ADD CONSTRAINT tender_line_items_pole_id_fkey
                        FOREIGN KEY (pole_id) REFERENCES electric_poles(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_line_items_complaint_id_fkey') THEN
                    ALTER TABLE tender_line_items ADD CONSTRAINT tender_line_items_complaint_id_fkey
                        FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_vendor_invites_tender_id_fkey') THEN
                    ALTER TABLE tender_vendor_invites ADD CONSTRAINT tender_vendor_invites_tender_id_fkey
                        FOREIGN KEY (tender_id) REFERENCES tenders(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_vendor_invites_vendor_id_fkey') THEN
                    ALTER TABLE tender_vendor_invites ADD CONSTRAINT tender_vendor_invites_vendor_id_fkey
                        FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_quotations_tender_id_fkey') THEN
                    ALTER TABLE tender_quotations ADD CONSTRAINT tender_quotations_tender_id_fkey
                        FOREIGN KEY (tender_id) REFERENCES tenders(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_quotations_vendor_id_fkey') THEN
                    ALTER TABLE tender_quotations ADD CONSTRAINT tender_quotations_vendor_id_fkey
                        FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_quotations_superseded_by_id_fkey') THEN
                    ALTER TABLE tender_quotations ADD CONSTRAINT tender_quotations_superseded_by_id_fkey
                        FOREIGN KEY (superseded_by_id) REFERENCES tender_quotations(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_documents_tender_id_fkey') THEN
                    ALTER TABLE tender_documents ADD CONSTRAINT tender_documents_tender_id_fkey
                        FOREIGN KEY (tender_id) REFERENCES tenders(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_documents_vendor_id_fkey') THEN
                    ALTER TABLE tender_documents ADD CONSTRAINT tender_documents_vendor_id_fkey
                        FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_documents_generated_by_user_id_fkey') THEN
                    ALTER TABLE tender_documents ADD CONSTRAINT tender_documents_generated_by_user_id_fkey
                        FOREIGN KEY (generated_by_user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_sessions_tender_id_fkey') THEN
                    ALTER TABLE field_verification_sessions ADD CONSTRAINT field_verification_sessions_tender_id_fkey
                        FOREIGN KEY (tender_id) REFERENCES tenders(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_sessions_created_by_user_id_fkey') THEN
                    ALTER TABLE field_verification_sessions ADD CONSTRAINT field_verification_sessions_created_by_user_id_fkey
                        FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_uploads_session_id_fkey') THEN
                    ALTER TABLE field_verification_uploads ADD CONSTRAINT field_verification_uploads_session_id_fkey
                        FOREIGN KEY (session_id) REFERENCES field_verification_sessions(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_uploads_matched_pole_id_fkey') THEN
                    ALTER TABLE field_verification_uploads ADD CONSTRAINT field_verification_uploads_matched_pole_id_fkey
                        FOREIGN KEY (matched_pole_id) REFERENCES electric_poles(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_uploads_manual_pole_id_fkey') THEN
                    ALTER TABLE field_verification_uploads ADD CONSTRAINT field_verification_uploads_manual_pole_id_fkey
                        FOREIGN KEY (manual_pole_id) REFERENCES electric_poles(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_field_checklist_items_tender_id_fkey') THEN
                    ALTER TABLE tender_field_checklist_items ADD CONSTRAINT tender_field_checklist_items_tender_id_fkey
                        FOREIGN KEY (tender_id) REFERENCES tenders(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_field_checklist_items_pole_id_fkey') THEN
                    ALTER TABLE tender_field_checklist_items ADD CONSTRAINT tender_field_checklist_items_pole_id_fkey
                        FOREIGN KEY (pole_id) REFERENCES electric_poles(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_field_checklist_items_line_item_id_fkey') THEN
                    ALTER TABLE tender_field_checklist_items ADD CONSTRAINT tender_field_checklist_items_line_item_id_fkey
                        FOREIGN KEY (line_item_id) REFERENCES tender_line_items(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_field_checklist_items_verified_upload_id_fkey') THEN
                    ALTER TABLE tender_field_checklist_items ADD CONSTRAINT tender_field_checklist_items_verified_upload_id_fkey
                        FOREIGN KEY (verified_upload_id) REFERENCES field_verification_uploads(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;

                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_audit_logs_tender_id_fkey') THEN
                    ALTER TABLE tender_audit_logs ADD CONSTRAINT tender_audit_logs_tender_id_fkey
                        FOREIGN KEY (tender_id) REFERENCES tenders(id) ON DELETE CASCADE ON UPDATE CASCADE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_audit_logs_actor_user_id_fkey') THEN
                    ALTER TABLE tender_audit_logs ADD CONSTRAINT tender_audit_logs_actor_user_id_fkey
                        FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE;
                END IF;
            END $$;
        `);
  }

  private async seed() {
    // ── NOTE: Use `npx prisma db seed` for proper seeding ────────────
    // The full seed data is in prisma/seed.ts with 20 poles and
    // multilingual landmarks (Tamil + Tanglish + English).
    // This inline seed is only a minimal fallback for fresh deployments.
    console.log(
      '⚠️  Running minimal auto-seed. For full data, run: npx prisma db seed',
    );

    await this.prisma.orgUnit.create({
      data: {
        name: 'Thayanur',
        center_lat: 11.0168,
        center_lng: 76.9558,
        ivr_number: '04440115043',
      },
    });

    await this.prisma.orgUnit.create({
      data: {
        name: 'Tholampalay',
        center_lat: 11.242,
        center_lng: 76.952,
        ivr_number: '04440115044',
      },
    });
    console.log(
      '✅ Created 2 panchayats (minimal). Run `npx prisma db seed` for full pole data.',
    );
  }
}
