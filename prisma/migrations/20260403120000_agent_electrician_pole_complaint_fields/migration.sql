-- Pole geotagged reference images (agent portal)
ALTER TABLE "electric_poles" ADD COLUMN IF NOT EXISTS "image_url" TEXT;
ALTER TABLE "electric_poles" ADD COLUMN IF NOT EXISTS "image_latitude" DOUBLE PRECISION;
ALTER TABLE "electric_poles" ADD COLUMN IF NOT EXISTS "image_longitude" DOUBLE PRECISION;
ALTER TABLE "electric_poles" ADD COLUMN IF NOT EXISTS "image_captured_at" TIMESTAMP(3);
ALTER TABLE "electric_poles" ADD COLUMN IF NOT EXISTS "image_uploaded_at" TIMESTAMP(3);
ALTER TABLE "electric_poles" ADD COLUMN IF NOT EXISTS "image_uploaded_by" INTEGER;

-- Complaint assignment + resolution proof (electrician portal)
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "assigned_electrician_id" INTEGER;
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "assigned_at" TIMESTAMP(3);
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolved_at" TIMESTAMP(3);
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolution_image_url" TEXT;
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolution_note" TEXT;
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolution_image_latitude" DOUBLE PRECISION;
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolution_image_longitude" DOUBLE PRECISION;
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolution_image_captured_at" TIMESTAMP(3);
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolution_distance_meters" DOUBLE PRECISION;
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolution_location_valid" BOOLEAN;
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "resolution_submitted_key" TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'electric_poles_image_uploaded_by_fkey'
  ) THEN
    ALTER TABLE "electric_poles"
      ADD CONSTRAINT "electric_poles_image_uploaded_by_fkey"
      FOREIGN KEY ("image_uploaded_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'complaints_assigned_electrician_id_fkey'
  ) THEN
    ALTER TABLE "complaints"
      ADD CONSTRAINT "complaints_assigned_electrician_id_fkey"
      FOREIGN KEY ("assigned_electrician_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS "complaints_resolution_submitted_key_key" ON "complaints"("resolution_submitted_key");
