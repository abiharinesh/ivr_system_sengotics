-- ============================================================================
--  Table naming rectification + duplicate removal
-- ============================================================================
--
--  RUN ORDER MATTERS. Take a database backup before running this.
--
--  Why ALTER TABLE ... RENAME rather than `prisma db push`:
--  `db push` implements a rename as DROP + CREATE, which silently destroys
--  every row in the table. Every rename below is done with ALTER TABLE so the
--  data survives, indexes and constraints follow the table automatically, and
--  the whole thing is reversible (see rollback.sql alongside this file).
--
--  Wrapped in a transaction: on any failure nothing is applied.
-- ============================================================================

BEGIN;

-- ── 1. Renames: tables whose names did not describe their contents ─────────

-- `tender_documents` never held documents. It holds PDF *generation jobs*:
-- a template id, a status, an error message and a generated_at timestamp.
-- Sitting next to the real DMS table `documents`, the name was actively
-- misleading about where a tender's files live.
ALTER TABLE "tender_documents" RENAME TO "tender_document_jobs";

-- `field_verification_uploads` is not an upload record either. It holds the
-- OCR and GPS match analysis of a field photo — ocr_lat, matched_pole_id,
-- match_confidence. The bytes live in storage; this is the verdict about them.
ALTER TABLE "field_verification_uploads" RENAME TO "field_verification_photos";

-- ── 2. Renames: naming consistency ─────────────────────────────────────────
--
-- 98 tables were plural; these six were not, and the IVR cluster used three
-- different conventions for one subsystem (calls_master / call_state /
-- ivr_poll_input). The "_master" suffix carried no meaning.

ALTER TABLE "calls_master"           RENAME TO "ivr_calls";
ALTER TABLE "call_state"             RENAME TO "ivr_call_states";
ALTER TABLE "ivr_poll_input"         RENAME TO "ivr_poll_inputs";
ALTER TABLE "ivr_service_selection"  RENAME TO "ivr_service_selections";

-- `properties` is ambiguous in a codebase where "property" also means a field
-- on an object. These are taxable land parcels.
ALTER TABLE "properties" RENAME TO "tax_properties";

-- `captured_assets` reads like a variant of `assets`. It is not: it is a field
-- agent's submission awaiting approval, which is a workflow stage.
ALTER TABLE "captured_assets" RENAME TO "asset_field_captures";

-- ── 3. Fold the duplicate audit trail into the platform one ────────────────
--
-- `tender_audit_logs` and `audit_logs` stored the same thing — actor, event,
-- JSON payload, timestamp, against one entity. Two audit trails means a
-- dispute is investigated in two places and one of them gets forgotten.
-- `audit_logs` already models this via entity_type/entity_id, and unlike the
-- old table it is tenant-scoped.
--
-- Rows are copied, not discarded. tenant_id and org_unit_id are recovered by
-- joining through the tender to its org unit.

INSERT INTO "audit_logs" (
  tenant_id, org_unit_id, user_id, module,
  entity_type, entity_id, action, after_value, changed_fields, created_at
)
SELECT
  COALESCE(ou.tenant_id, 'default'),
  t.org_unit_id,
  tal.actor_user_id,
  'tenders',
  'tender',
  tal.tender_id::text,
  tal.event,
  tal.payload,
  ARRAY[]::text[],
  tal.created_at
FROM "tender_audit_logs" tal
JOIN "tenders"   t  ON t.id = tal.tender_id
LEFT JOIN "org_units" ou ON ou.id = t.org_unit_id;

DROP TABLE "tender_audit_logs";

-- ── 4. Drop the dead lookup table ──────────────────────────────────────────
--
-- `admin_jurisdictions` has zero readers in the backend and zero in the
-- frontend. The only thing pointing at it was a nullable FK on org_units that
-- nothing ever populated or read.

ALTER TABLE "org_units" DROP CONSTRAINT IF EXISTS "org_units_escalation_jurisdiction_id_fkey";
DROP INDEX IF EXISTS "org_units_escalation_jurisdiction_id_idx";
DROP TABLE IF EXISTS "admin_jurisdictions";

-- `escalation_jurisdiction_id` is kept as a plain integer column: it costs
-- nothing, and dropping a column is the one step here that cannot be undone
-- without the original values.

COMMIT;
