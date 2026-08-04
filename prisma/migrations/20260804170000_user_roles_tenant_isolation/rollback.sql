DROP TRIGGER IF EXISTS "user_roles_tenant_guard_trg" ON "user_roles";
DROP FUNCTION IF EXISTS "user_roles_tenant_guard"();
DROP INDEX IF EXISTS "user_roles_tenant_id_user_id_idx";
ALTER TABLE "user_roles" DROP COLUMN IF EXISTS "tenant_id";
