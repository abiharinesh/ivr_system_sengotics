-- AlterTable
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "ward_id" INTEGER;

-- AlterTable
ALTER TABLE "electric_poles" ADD COLUMN IF NOT EXISTS "ward_id" INTEGER;

-- AlterTable
ALTER TABLE "ivr_call_states" ADD COLUMN IF NOT EXISTS "complaint_method" TEXT,
ADD COLUMN IF NOT EXISTS "ward_id" INTEGER,
ADD COLUMN IF NOT EXISTS "ward_status" TEXT NOT NULL DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS "ward_voice_call_id" INTEGER;

-- CreateTable
CREATE TABLE IF NOT EXISTS "wards" (
    "id" SERIAL NOT NULL,
    "org_unit_id" INTEGER NOT NULL,
    "ward_number" INTEGER NOT NULL,
    "name_en" TEXT NOT NULL,
    "name_ta" TEXT,
    "aliases" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "wards_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "wards_org_unit_id_idx" ON "wards"("org_unit_id");

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "wards_org_unit_id_ward_number_key" ON "wards"("org_unit_id", "ward_number");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "complaints_ward_id_idx" ON "complaints"("ward_id");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "electric_poles_ward_id_idx" ON "electric_poles"("ward_id");

-- AddForeignKey
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'electric_poles_ward_id_fkey'
    ) THEN
        ALTER TABLE "electric_poles" ADD CONSTRAINT "electric_poles_ward_id_fkey" FOREIGN KEY ("ward_id") REFERENCES "wards"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
END $$;

-- AddForeignKey
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'complaints_ward_id_fkey'
    ) THEN
        ALTER TABLE "complaints" ADD CONSTRAINT "complaints_ward_id_fkey" FOREIGN KEY ("ward_id") REFERENCES "wards"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
END $$;

-- AddForeignKey
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ivr_call_states_ward_id_fkey'
    ) THEN
        ALTER TABLE "ivr_call_states" ADD CONSTRAINT "ivr_call_states_ward_id_fkey" FOREIGN KEY ("ward_id") REFERENCES "wards"("id") ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;
END $$;

-- AddForeignKey
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'wards_org_unit_id_fkey'
    ) THEN
        ALTER TABLE "wards" ADD CONSTRAINT "wards_org_unit_id_fkey" FOREIGN KEY ("org_unit_id") REFERENCES "org_units"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
END $$;
