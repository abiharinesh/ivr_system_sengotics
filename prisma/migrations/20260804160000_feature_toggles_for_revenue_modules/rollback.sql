ALTER TABLE "branch_feature_configs"
  DROP COLUMN IF EXISTS "property_tax",
  DROP COLUMN IF EXISTS "trade_licence";
ALTER TABLE "tenant_feature_configs"
  DROP COLUMN IF EXISTS "property_tax",
  DROP COLUMN IF EXISTS "trade_licence";
