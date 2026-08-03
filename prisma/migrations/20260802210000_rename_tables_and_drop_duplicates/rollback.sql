-- ============================================================================
--  Rollback for 20260802210000_rename_tables_and_drop_duplicates
-- ============================================================================
--
--  Reverses every rename. The two dropped tables are handled as follows:
--
--   • tender_audit_logs — fully recoverable. Its rows were copied into
--     audit_logs before the drop and are identified by
--     entity_type = 'tender', so they are copied back here.
--
--   • admin_jurisdictions — NOT recoverable from this script. It had zero
--     rows referenced anywhere, but if it held data you need, restore it from
--     your backup rather than from here. The table is recreated empty so the
--     foreign key can be restored.
--
--  Run against the same database, in a transaction.
-- ============================================================================

BEGIN;

-- ── 1. Reverse the renames ─────────────────────────────────────────────────

ALTER TABLE "tender_document_jobs"        RENAME TO "tender_documents";
ALTER TABLE "field_verification_photos"   RENAME TO "field_verification_uploads";
ALTER TABLE "ivr_calls"                   RENAME TO "calls_master";
ALTER TABLE "ivr_call_states"             RENAME TO "call_state";
ALTER TABLE "ivr_poll_inputs"             RENAME TO "ivr_poll_input";
ALTER TABLE "ivr_service_selections"      RENAME TO "ivr_service_selection";
ALTER TABLE "tax_properties"              RENAME TO "properties";
ALTER TABLE "asset_field_captures"        RENAME TO "captured_assets";

-- ── 2. Restore the tender audit table and its rows ─────────────────────────

CREATE TABLE "tender_audit_logs" (
  "id"            SERIAL PRIMARY KEY,
  "tender_id"     INTEGER NOT NULL,
  "actor_user_id" INTEGER,
  "event"         TEXT NOT NULL,
  "payload"       JSONB,
  "created_at"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "tender_audit_logs_tender_id_idx" ON "tender_audit_logs"("tender_id");

ALTER TABLE "tender_audit_logs"
  ADD CONSTRAINT "tender_audit_logs_tender_id_fkey"
  FOREIGN KEY ("tender_id") REFERENCES "tenders"("id") ON DELETE CASCADE;

ALTER TABLE "tender_audit_logs"
  ADD CONSTRAINT "tender_audit_logs_actor_user_id_fkey"
  FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE SET NULL;

INSERT INTO "tender_audit_logs" (tender_id, actor_user_id, event, payload, created_at)
SELECT
  al.entity_id::integer,
  al.user_id,
  al.action,
  al.after_value,
  al.created_at
FROM "audit_logs" al
WHERE al.entity_type = 'tender'
  AND al.module = 'tenders';

-- Remove the copies from the platform trail so the rollback does not leave
-- both populated.
DELETE FROM "audit_logs"
WHERE entity_type = 'tender' AND module = 'tenders';

-- ── 3. Recreate the jurisdiction lookup (empty) and its FK ─────────────────

CREATE TABLE "admin_jurisdictions" (
  "id"            SERIAL PRIMARY KEY,
  "type"          TEXT NOT NULL,
  "name"          TEXT NOT NULL,
  "district"      TEXT,
  "parent_id"     INTEGER,
  "contact_name"  TEXT,
  "contact_phone" TEXT,
  "contact_email" TEXT,
  "is_active"     BOOLEAN NOT NULL DEFAULT true,
  "created_at"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "admin_jurisdictions_district_type_idx" ON "admin_jurisdictions"("district", "type");
CREATE INDEX "admin_jurisdictions_parent_id_idx"     ON "admin_jurisdictions"("parent_id");

ALTER TABLE "admin_jurisdictions"
  ADD CONSTRAINT "admin_jurisdictions_parent_id_fkey"
  FOREIGN KEY ("parent_id") REFERENCES "admin_jurisdictions"("id");

CREATE INDEX "org_units_escalation_jurisdiction_id_idx"
  ON "org_units"("escalation_jurisdiction_id");

ALTER TABLE "org_units"
  ADD CONSTRAINT "org_units_escalation_jurisdiction_id_fkey"
  FOREIGN KEY ("escalation_jurisdiction_id")
  REFERENCES "admin_jurisdictions"("id");

COMMIT;
