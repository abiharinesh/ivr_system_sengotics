-- Role templates: provenance for a tenant's copy of a shipped role.
--
-- Until now every tenant's roles were unrelated rows that merely happened to
-- share a name. Improving the shipped roster meant repeating the same edit in
-- every client by hand, and nothing recorded which roles a council had
-- deliberately changed — so there was no safe way to push an improvement
-- without trampling local decisions.
--
-- `template_id` records the `__system__` role a copy was provisioned from.
-- `customised_at` is stamped the first time that council edits the copy's
-- grants; a sync applies template changes only where it is still null.
--
-- Both are nullable and default to null, so every existing row keeps its
-- current behaviour: a role with no template is simply never synced.

-- AlterTable
ALTER TABLE "roles" ADD COLUMN     "customised_at" TIMESTAMP(3),
ADD COLUMN     "template_id" INTEGER;

-- CreateIndex
CREATE INDEX "roles_template_id_idx" ON "roles"("template_id");

-- AddForeignKey
-- RESTRICT, not CASCADE: deleting a template that councils are provisioned
-- from must fail loudly rather than quietly orphan their copies.
ALTER TABLE "roles" ADD CONSTRAINT "roles_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
