-- A complaint has a location of its own, not only the location of an asset it
-- happens to reference. Without this, only complaints tied to a pole could be
-- placed on a map — which excluded potholes, garbage and stray-animal reports,
-- the bulk of the volume.
ALTER TABLE "complaints"
  ADD COLUMN IF NOT EXISTS "latitude"    DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "longitude"   DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "ward_number" TEXT;

-- Ward-density queries filter on open complaints within a branch.
CREATE INDEX IF NOT EXISTS "complaints_org_unit_id_status_idx"
  ON "complaints" ("org_unit_id", "status");
