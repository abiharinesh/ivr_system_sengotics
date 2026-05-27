-- Add per-vendor invite token lifecycle metadata for tender sharing.
ALTER TABLE "tender_vendor_invites"
    ADD COLUMN IF NOT EXISTS "invite_token" TEXT,
    ADD COLUMN IF NOT EXISTS "invite_expires_at" TIMESTAMP(3),
    ADD COLUMN IF NOT EXISTS "invite_revoked_at" TIMESTAMP(3),
    ADD COLUMN IF NOT EXISTS "invite_opened_at" TIMESTAMP(3),
    ADD COLUMN IF NOT EXISTS "invite_submitted_at" TIMESTAMP(3);

CREATE UNIQUE INDEX IF NOT EXISTS "tender_vendor_invites_invite_token_key"
    ON "tender_vendor_invites"("invite_token");

CREATE INDEX IF NOT EXISTS "tender_vendor_invites_invite_token_invite_revoked_at_idx"
    ON "tender_vendor_invites"("invite_token", "invite_revoked_at");
