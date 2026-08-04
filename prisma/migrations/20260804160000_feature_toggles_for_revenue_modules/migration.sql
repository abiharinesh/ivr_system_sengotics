-- Property tax and trade licensing shipped without a provisioning toggle, so
-- their screens could not be switched off for a branch that does not levy
-- them. `app_screens.module` already carries both names, which is the key the
-- entitlement resolver joins on.
--
-- Default true: every branch already using these modules must keep them when
-- the gate starts being enforced. A super admin turns off what a client has
-- not licensed, rather than turning on what they have.
ALTER TABLE "branch_feature_configs"
  ADD COLUMN IF NOT EXISTS "property_tax"  BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS "trade_licence" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "tenant_feature_configs"
  ADD COLUMN IF NOT EXISTS "property_tax"  BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS "trade_licence" BOOLEAN NOT NULL DEFAULT true;
