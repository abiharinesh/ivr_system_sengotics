-- Tenant isolation for role assignments.
--
-- `user_roles` carried no tenant of its own: it was reachable only through the
-- role and the branch. That meant every authorization query had to join two
-- tables to establish the boundary, and nothing in the schema stopped a role
-- from one tenant being assigned at another tenant's branch.
--
-- The column is denormalised and kept honest by a trigger, so the invariant is
-- the database's job rather than something every caller has to remember.

ALTER TABLE "user_roles"
  ADD COLUMN IF NOT EXISTS "tenant_id" TEXT;

-- Backfill from the branch, which is the authoritative owner of the posting.
UPDATE "user_roles" ur
   SET "tenant_id" = o."tenant_id"
  FROM "org_units" o
 WHERE o."id" = ur."org_unit_id"
   AND ur."tenant_id" IS NULL;

-- Anything still unset has no resolvable branch; fall back to the operating
-- tenant rather than leaving a null that the NOT NULL below would reject.
UPDATE "user_roles" SET "tenant_id" = 'default' WHERE "tenant_id" IS NULL;

ALTER TABLE "user_roles"
  ALTER COLUMN "tenant_id" SET NOT NULL,
  ALTER COLUMN "tenant_id" SET DEFAULT 'default';

CREATE INDEX IF NOT EXISTS "user_roles_tenant_id_user_id_idx"
  ON "user_roles" ("tenant_id", "user_id");

-- Keep the assignment, the person and the branch in the same tenant.
--
-- A trigger rather than a CHECK because the invariant spans tables, and rather
-- than composite foreign keys because a role may legitimately live in the
-- `__system__` template tenant while being assigned inside a real one — that
-- is the shared-template pattern, not a leak.
CREATE OR REPLACE FUNCTION "user_roles_tenant_guard"() RETURNS TRIGGER AS $$
DECLARE
  branch_tenant TEXT;
  user_tenant   TEXT;
BEGIN
  SELECT "tenant_id" INTO branch_tenant FROM "org_units" WHERE "id" = NEW."org_unit_id";
  SELECT "tenant_id" INTO user_tenant   FROM "users"     WHERE "id" = NEW."user_id";

  IF branch_tenant IS NOT NULL AND NEW."tenant_id" IS DISTINCT FROM branch_tenant THEN
    RAISE EXCEPTION
      'user_roles.tenant_id (%) does not match the branch tenant (%) for org_unit_id %',
      NEW."tenant_id", branch_tenant, NEW."org_unit_id";
  END IF;

  IF user_tenant IS NOT NULL AND user_tenant IS DISTINCT FROM branch_tenant THEN
    RAISE EXCEPTION
      'user % belongs to tenant % but org_unit % belongs to tenant %',
      NEW."user_id", user_tenant, NEW."org_unit_id", branch_tenant;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS "user_roles_tenant_guard_trg" ON "user_roles";
CREATE TRIGGER "user_roles_tenant_guard_trg"
  BEFORE INSERT OR UPDATE ON "user_roles"
  FOR EACH ROW EXECUTE FUNCTION "user_roles_tenant_guard"();
