-- Enterprise tenant entitlement configuration and audit ownership.
-- The role-template table is intentionally separate from tenant role copies:
-- it is the platform-level switch that limits which templates a tenant may use.

CREATE TABLE IF NOT EXISTS "tenant_role_templates" (
  "id" SERIAL NOT NULL,
  "tenant_id" TEXT NOT NULL,
  "role_template_id" INTEGER NOT NULL,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "tenant_role_templates_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "tenant_role_templates_tenant_id_role_template_id_key"
  ON "tenant_role_templates"("tenant_id", "role_template_id");
CREATE INDEX IF NOT EXISTS "tenant_role_templates_tenant_id_idx"
  ON "tenant_role_templates"("tenant_id");

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenant_role_templates_tenant_id_fkey') THEN
    ALTER TABLE "tenant_role_templates" ADD CONSTRAINT "tenant_role_templates_tenant_id_fkey"
      FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenant_role_templates_role_template_id_fkey') THEN
    ALTER TABLE "tenant_role_templates" ADD CONSTRAINT "tenant_role_templates_role_template_id_fkey"
      FOREIGN KEY ("role_template_id") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS "tenant_settings" (
  "id" SERIAL NOT NULL,
  "tenant_id" TEXT NOT NULL,
  "sms_config" JSONB,
  "email_config" JSONB,
  "whatsapp_config" JSONB,
  "ai_config" JSONB,
  "storage_config" JSONB,
  "theme_config" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "tenant_settings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "tenant_settings_tenant_id_key"
  ON "tenant_settings"("tenant_id");
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenant_settings_tenant_id_fkey') THEN
    ALTER TABLE "tenant_settings" ADD CONSTRAINT "tenant_settings_tenant_id_fkey"
      FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- Audit records become referentially owned without weakening their immutability.
-- Historical imports can contain audit-only tenant IDs whose tenant row was
-- removed later. Preserve those records under an explicit inactive legacy
-- tenant instead of silently deleting or rewriting audit history.
INSERT INTO "tenants" ("id", "slug", "name", "is_active", "created_at", "updated_at")
SELECT DISTINCT
  a."tenant_id",
  'legacy-audit-' || substring(md5(a."tenant_id") from 1 for 16),
  'Legacy audit tenant: ' || a."tenant_id",
  false,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM "audit_logs" a
LEFT JOIN "tenants" t ON t."id" = a."tenant_id"
WHERE t."id" IS NULL;

-- Actor and branch references are optional audit metadata. If a historical
-- user or org unit was purged before this migration, retain the event and
-- clear only that dangling reference (the same behaviour future deletions use).
UPDATE "audit_logs" a
SET "user_id" = NULL
WHERE "user_id" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "users" u WHERE u."id" = a."user_id");

UPDATE "audit_logs" a
SET "org_unit_id" = NULL
WHERE "org_unit_id" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "org_units" o WHERE o."id" = a."org_unit_id");

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'audit_logs_tenant_id_fkey') THEN
    ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_tenant_id_fkey"
      FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'audit_logs_org_unit_id_fkey') THEN
    ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_org_unit_id_fkey"
      FOREIGN KEY ("org_unit_id") REFERENCES "org_units"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'audit_logs_user_id_fkey') THEN
    ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_user_id_fkey"
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
