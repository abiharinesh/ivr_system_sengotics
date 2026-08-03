-- Add missing columns for password reset flags on public.users
ALTER TABLE "users" 
ADD COLUMN IF NOT EXISTS "must_change_password" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS "password_changed_at" TIMESTAMP(3);
