-- Panchayat-level overrides for tender document template layout
ALTER TABLE "panchayats" ADD COLUMN IF NOT EXISTS "document_template_settings" JSONB;
