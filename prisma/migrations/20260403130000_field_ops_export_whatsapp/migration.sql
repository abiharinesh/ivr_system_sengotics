ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "phone_e164" TEXT;

ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "category" TEXT;
ALTER TABLE "complaints" ADD COLUMN IF NOT EXISTS "whatsapp_done_ack_at" TIMESTAMP(3);

CREATE TABLE IF NOT EXISTS "export_jobs" (
    "id" SERIAL NOT NULL,
    "created_by_user_id" INTEGER NOT NULL,
    "panchayat_id" INTEGER,
    "electrician_user_id" INTEGER NOT NULL,
    "range_from" TIMESTAMP(3) NOT NULL,
    "range_to" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "result_relative_path" TEXT,
    "error_message" TEXT,
    "row_count" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "export_jobs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "export_jobs_electrician_user_id_idx" ON "export_jobs"("electrician_user_id");
CREATE INDEX IF NOT EXISTS "export_jobs_status_idx" ON "export_jobs"("status");

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'export_jobs_created_by_user_id_fkey') THEN
    ALTER TABLE "export_jobs" ADD CONSTRAINT "export_jobs_created_by_user_id_fkey"
      FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'export_jobs_electrician_user_id_fkey') THEN
    ALTER TABLE "export_jobs" ADD CONSTRAINT "export_jobs_electrician_user_id_fkey"
      FOREIGN KEY ("electrician_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'export_jobs_panchayat_id_fkey') THEN
    ALTER TABLE "export_jobs" ADD CONSTRAINT "export_jobs_panchayat_id_fkey"
      FOREIGN KEY ("panchayat_id") REFERENCES "panchayats"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
