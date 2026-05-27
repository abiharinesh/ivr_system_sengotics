-- Field verification batches: section labels + overlay OCR columns

ALTER TABLE "field_verification_sessions" ADD COLUMN IF NOT EXISTS "label" TEXT;

ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_lat" DOUBLE PRECISION;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_lng" DOUBLE PRECISION;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_address" TEXT;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_raw_text" TEXT;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_captured_at" TIMESTAMP(3);
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_pole_number" TEXT;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_keypad_id" TEXT;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_matched_pole_id" INTEGER;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "ocr_match_confidence" TEXT NOT NULL DEFAULT 'skipped';
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "coord_source" TEXT;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "matched_lat" DOUBLE PRECISION;
ALTER TABLE "field_verification_uploads" ADD COLUMN IF NOT EXISTS "matched_lng" DOUBLE PRECISION;
