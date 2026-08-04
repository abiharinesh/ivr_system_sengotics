DROP INDEX IF EXISTS "complaints_org_unit_id_status_idx";
ALTER TABLE "complaints"
  DROP COLUMN IF EXISTS "latitude",
  DROP COLUMN IF EXISTS "longitude",
  DROP COLUMN IF EXISTS "ward_number";
