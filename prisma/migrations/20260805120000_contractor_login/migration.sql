-- A contractor's login, so the portal can know whose tenders to show.
--
-- `contractors` and `users` were unrelated tables. A person with the
-- `contractor` role could sign in, but nothing connected them to any of the
-- registered businesses — so the portal they landed on could not list "your
-- invited tenders" and was a set of static mockup pages behind an iframe.
--
-- Nullable, because most contractors are records an officer keyed in and who
-- never log in; unique, because one login is one business. Mirrors
-- `employees.user_id`, which solves the same problem for staff.
--
-- ON DELETE SET NULL rather than CASCADE: removing somebody's login must not
-- delete the business, its tender history or its work orders.

-- AlterTable
ALTER TABLE "contractors" ADD COLUMN     "user_id" INTEGER;

-- CreateIndex
CREATE UNIQUE INDEX "contractors_user_id_key" ON "contractors"("user_id");

-- AddForeignKey
ALTER TABLE "contractors" ADD CONSTRAINT "contractors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
