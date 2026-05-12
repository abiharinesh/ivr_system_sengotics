-- ============================================================================
--  Tender workflow (Phase 1) — vendors, tenders, quotations, documents,
--  field verification sessions/uploads, checklist, audit log.
--  Idempotent (IF NOT EXISTS) to align with the bootstrap pattern in
--  src/prisma/db-setup.service.ts ensureSchema().
-- ============================================================================

-- ── vendors ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "vendors" (
    "id"           SERIAL NOT NULL,
    "panchayat_id" INTEGER NOT NULL,
    "name"         TEXT NOT NULL,
    "phone_e164"   TEXT NOT NULL,
    "place"        TEXT,
    "notes"        TEXT,
    "active"       BOOLEAN NOT NULL DEFAULT TRUE,
    "created_at"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "vendors_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "vendors_panchayat_id_phone_e164_key" ON "vendors"("panchayat_id", "phone_e164");
CREATE INDEX IF NOT EXISTS "vendors_panchayat_id_idx" ON "vendors"("panchayat_id");

-- ── tenders ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "tenders" (
    "id"                              SERIAL NOT NULL,
    "panchayat_id"                    INTEGER NOT NULL,
    "status"                          TEXT NOT NULL DEFAULT 'draft',
    "title_ta"                        TEXT,
    "title_en"                        TEXT,
    "narrative_ta"                    TEXT,
    "narrative_en"                    TEXT,
    "anchor_date"                     TIMESTAMP(3),
    "milestone_rules"                 JSONB,
    "quotation_access_mode"           TEXT NOT NULL DEFAULT 'invited_only',
    "auto_resolve_linked_complaints"  BOOLEAN NOT NULL DEFAULT FALSE,
    "officer_self_inspection"         BOOLEAN NOT NULL DEFAULT FALSE,
    "public_token"                    TEXT,
    "awarded_quotation_id"            INTEGER,
    "work_order_date"                 TIMESTAMP(3),
    "work_completed_at"               TIMESTAMP(3),
    "inspection_done_at"              TIMESTAMP(3),
    "inspection_notes"                TEXT,
    "payment_meta"                    JSONB,
    "created_by_user_id"              INTEGER NOT NULL,
    "created_at"                      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"                      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "tenders_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "tenders_public_token_key" ON "tenders"("public_token");
CREATE UNIQUE INDEX IF NOT EXISTS "tenders_awarded_quotation_id_key" ON "tenders"("awarded_quotation_id");
CREATE INDEX IF NOT EXISTS "tenders_panchayat_id_status_idx" ON "tenders"("panchayat_id", "status");

-- ── tender line items ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "tender_line_items" (
    "id"             SERIAL NOT NULL,
    "tender_id"      INTEGER NOT NULL,
    "seq"            INTEGER NOT NULL DEFAULT 1,
    "description_ta" TEXT,
    "description_en" TEXT,
    "quantity"       DECIMAL(12,3),
    "unit"           TEXT,
    "pole_id"        INTEGER,
    "complaint_id"   INTEGER,
    CONSTRAINT "tender_line_items_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "tender_line_items_tender_id_idx" ON "tender_line_items"("tender_id");

-- ── tender vendor invites ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "tender_vendor_invites" (
    "id"         SERIAL NOT NULL,
    "tender_id"  INTEGER NOT NULL,
    "vendor_id"  INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "tender_vendor_invites_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "tender_vendor_invites_tender_id_vendor_id_key" ON "tender_vendor_invites"("tender_id", "vendor_id");

-- ── tender quotations ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "tender_quotations" (
    "id"                   SERIAL NOT NULL,
    "tender_id"            INTEGER NOT NULL,
    "vendor_id"            INTEGER,
    "submitter_name"       TEXT NOT NULL,
    "submitter_phone_e164" TEXT NOT NULL,
    "amount"               DECIMAL(12,2) NOT NULL,
    "remarks"              TEXT,
    "attachment_url"       TEXT,
    "source"               TEXT NOT NULL DEFAULT 'officer_entry',
    "screening_outcome"    TEXT NOT NULL DEFAULT 'pending',
    "superseded_by_id"     INTEGER,
    "submitted_ip_hash"    TEXT,
    "submitted_at"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "tender_quotations_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "tender_quotations_tender_id_idx" ON "tender_quotations"("tender_id");

-- ── tender documents (PDF artifacts) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS "tender_documents" (
    "id"                   SERIAL NOT NULL,
    "tender_id"            INTEGER NOT NULL,
    "template_id"          TEXT NOT NULL,
    "vendor_id"            INTEGER,
    "version"              INTEGER NOT NULL DEFAULT 1,
    "field_overrides"      JSONB,
    "storage_path"         TEXT,
    "generated_at"         TIMESTAMP(3),
    "generated_by_user_id" INTEGER,
    "status"               TEXT NOT NULL DEFAULT 'pending',
    "error_message"        TEXT,
    "created_at"           TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "tender_documents_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "tender_documents_tender_id_template_id_idx" ON "tender_documents"("tender_id", "template_id");

-- ── field verification sessions ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "field_verification_sessions" (
    "id"                 SERIAL NOT NULL,
    "tender_id"          INTEGER NOT NULL,
    "token"              TEXT NOT NULL,
    "expires_at"         TIMESTAMP(3),
    "pole_subset_ids"    INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],
    "created_by_user_id" INTEGER NOT NULL,
    "confirmed_at"       TIMESTAMP(3),
    "created_at"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "field_verification_sessions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "field_verification_sessions_token_key" ON "field_verification_sessions"("token");
CREATE INDEX IF NOT EXISTS "field_verification_sessions_tender_id_idx" ON "field_verification_sessions"("tender_id");

-- ── field verification uploads ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "field_verification_uploads" (
    "id"               SERIAL NOT NULL,
    "session_id"       INTEGER NOT NULL,
    "image_url"        TEXT NOT NULL,
    "exif_lat"         DOUBLE PRECISION,
    "exif_lng"         DOUBLE PRECISION,
    "captured_at"      TIMESTAMP(3),
    "matched_pole_id"  INTEGER,
    "manual_pole_id"   INTEGER,
    "distance_meters"  DOUBLE PRECISION,
    "match_confidence" TEXT NOT NULL DEFAULT 'unmatched',
    "notes"            TEXT,
    "uploaded_at"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "field_verification_uploads_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "field_verification_uploads_session_id_idx" ON "field_verification_uploads"("session_id");

-- ── tender field checklist items ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "tender_field_checklist_items" (
    "id"                 SERIAL NOT NULL,
    "tender_id"          INTEGER NOT NULL,
    "pole_id"            INTEGER,
    "line_item_id"       INTEGER,
    "is_done"            BOOLEAN NOT NULL DEFAULT FALSE,
    "verified_upload_id" INTEGER,
    "notes"              TEXT,
    "created_at"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "tender_field_checklist_items_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "tender_field_checklist_items_tender_id_idx" ON "tender_field_checklist_items"("tender_id");

-- ── tender audit logs ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "tender_audit_logs" (
    "id"            SERIAL NOT NULL,
    "tender_id"     INTEGER NOT NULL,
    "actor_user_id" INTEGER,
    "event"         TEXT NOT NULL,
    "payload"       JSONB,
    "created_at"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "tender_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "tender_audit_logs_tender_id_idx" ON "tender_audit_logs"("tender_id");

-- ── foreign keys (idempotent) ──────────────────────────────────────────────
DO $$
BEGIN
    -- vendors
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vendors_panchayat_id_fkey') THEN
        ALTER TABLE "vendors" ADD CONSTRAINT "vendors_panchayat_id_fkey"
            FOREIGN KEY ("panchayat_id") REFERENCES "panchayats"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;

    -- tenders
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenders_panchayat_id_fkey') THEN
        ALTER TABLE "tenders" ADD CONSTRAINT "tenders_panchayat_id_fkey"
            FOREIGN KEY ("panchayat_id") REFERENCES "panchayats"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenders_created_by_user_id_fkey') THEN
        ALTER TABLE "tenders" ADD CONSTRAINT "tenders_created_by_user_id_fkey"
            FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenders_awarded_quotation_id_fkey') THEN
        ALTER TABLE "tenders" ADD CONSTRAINT "tenders_awarded_quotation_id_fkey"
            FOREIGN KEY ("awarded_quotation_id") REFERENCES "tender_quotations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;

    -- tender_line_items
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_line_items_tender_id_fkey') THEN
        ALTER TABLE "tender_line_items" ADD CONSTRAINT "tender_line_items_tender_id_fkey"
            FOREIGN KEY ("tender_id") REFERENCES "tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_line_items_pole_id_fkey') THEN
        ALTER TABLE "tender_line_items" ADD CONSTRAINT "tender_line_items_pole_id_fkey"
            FOREIGN KEY ("pole_id") REFERENCES "electric_poles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_line_items_complaint_id_fkey') THEN
        ALTER TABLE "tender_line_items" ADD CONSTRAINT "tender_line_items_complaint_id_fkey"
            FOREIGN KEY ("complaint_id") REFERENCES "complaints"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;

    -- tender_vendor_invites
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_vendor_invites_tender_id_fkey') THEN
        ALTER TABLE "tender_vendor_invites" ADD CONSTRAINT "tender_vendor_invites_tender_id_fkey"
            FOREIGN KEY ("tender_id") REFERENCES "tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_vendor_invites_vendor_id_fkey') THEN
        ALTER TABLE "tender_vendor_invites" ADD CONSTRAINT "tender_vendor_invites_vendor_id_fkey"
            FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;

    -- tender_quotations
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_quotations_tender_id_fkey') THEN
        ALTER TABLE "tender_quotations" ADD CONSTRAINT "tender_quotations_tender_id_fkey"
            FOREIGN KEY ("tender_id") REFERENCES "tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_quotations_vendor_id_fkey') THEN
        ALTER TABLE "tender_quotations" ADD CONSTRAINT "tender_quotations_vendor_id_fkey"
            FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_quotations_superseded_by_id_fkey') THEN
        ALTER TABLE "tender_quotations" ADD CONSTRAINT "tender_quotations_superseded_by_id_fkey"
            FOREIGN KEY ("superseded_by_id") REFERENCES "tender_quotations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;

    -- tender_documents
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_documents_tender_id_fkey') THEN
        ALTER TABLE "tender_documents" ADD CONSTRAINT "tender_documents_tender_id_fkey"
            FOREIGN KEY ("tender_id") REFERENCES "tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_documents_vendor_id_fkey') THEN
        ALTER TABLE "tender_documents" ADD CONSTRAINT "tender_documents_vendor_id_fkey"
            FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_documents_generated_by_user_id_fkey') THEN
        ALTER TABLE "tender_documents" ADD CONSTRAINT "tender_documents_generated_by_user_id_fkey"
            FOREIGN KEY ("generated_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;

    -- field_verification_sessions
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_sessions_tender_id_fkey') THEN
        ALTER TABLE "field_verification_sessions" ADD CONSTRAINT "field_verification_sessions_tender_id_fkey"
            FOREIGN KEY ("tender_id") REFERENCES "tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_sessions_created_by_user_id_fkey') THEN
        ALTER TABLE "field_verification_sessions" ADD CONSTRAINT "field_verification_sessions_created_by_user_id_fkey"
            FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;

    -- field_verification_uploads
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_uploads_session_id_fkey') THEN
        ALTER TABLE "field_verification_uploads" ADD CONSTRAINT "field_verification_uploads_session_id_fkey"
            FOREIGN KEY ("session_id") REFERENCES "field_verification_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_uploads_matched_pole_id_fkey') THEN
        ALTER TABLE "field_verification_uploads" ADD CONSTRAINT "field_verification_uploads_matched_pole_id_fkey"
            FOREIGN KEY ("matched_pole_id") REFERENCES "electric_poles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'field_verification_uploads_manual_pole_id_fkey') THEN
        ALTER TABLE "field_verification_uploads" ADD CONSTRAINT "field_verification_uploads_manual_pole_id_fkey"
            FOREIGN KEY ("manual_pole_id") REFERENCES "electric_poles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;

    -- tender_field_checklist_items
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_field_checklist_items_tender_id_fkey') THEN
        ALTER TABLE "tender_field_checklist_items" ADD CONSTRAINT "tender_field_checklist_items_tender_id_fkey"
            FOREIGN KEY ("tender_id") REFERENCES "tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_field_checklist_items_pole_id_fkey') THEN
        ALTER TABLE "tender_field_checklist_items" ADD CONSTRAINT "tender_field_checklist_items_pole_id_fkey"
            FOREIGN KEY ("pole_id") REFERENCES "electric_poles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_field_checklist_items_line_item_id_fkey') THEN
        ALTER TABLE "tender_field_checklist_items" ADD CONSTRAINT "tender_field_checklist_items_line_item_id_fkey"
            FOREIGN KEY ("line_item_id") REFERENCES "tender_line_items"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_field_checklist_items_verified_upload_id_fkey') THEN
        ALTER TABLE "tender_field_checklist_items" ADD CONSTRAINT "tender_field_checklist_items_verified_upload_id_fkey"
            FOREIGN KEY ("verified_upload_id") REFERENCES "field_verification_uploads"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;

    -- tender_audit_logs
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_audit_logs_tender_id_fkey') THEN
        ALTER TABLE "tender_audit_logs" ADD CONSTRAINT "tender_audit_logs_tender_id_fkey"
            FOREIGN KEY ("tender_id") REFERENCES "tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tender_audit_logs_actor_user_id_fkey') THEN
        ALTER TABLE "tender_audit_logs" ADD CONSTRAINT "tender_audit_logs_actor_user_id_fkey"
            FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
END $$;
