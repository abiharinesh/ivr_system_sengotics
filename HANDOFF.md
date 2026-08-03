# Handoff — Ooraatchi / ivr_system_sengotics

Paste this whole file into a new chat. It is the full state of an extended
session: what was built, why it was built that way, what is unverified, and
what is next.

---

## 1. The project

Multi-tenant e-governance platform for Tamil Nadu local bodies.

- **Backend:** NestJS + Prisma + PostgreSQL (Supabase). `src/`
- **Frontend:** Flutter (web-first, also mobile/desktop). `ivr_frontend/`
- **Specs:** `docs/frontend_screen_plans/` — 16 numbered screen-plan docs
- **Shell:** Git Bash on Windows. PowerShell also available.

**Verify with:**
```bash
npx tsc -p tsconfig.build.json --noEmit    # backend typecheck
npx jest                                    # 317 tests / 28 suites, all passing
npx nest build
cd ivr_frontend && flutter analyze lib      # clean
cd ivr_frontend && flutter test             # 115 tests, all passing
```

---

## 2. ⚠ NOTHING HAS RUN AGAINST THE DATABASE

**This is the most important thing to know.** All schema work is in
`prisma/schema.prisma` and generates a valid client, but the live Supabase
database has *none* of it. Three things are pending, **in this order**:

```bash
# 1. Rename/dedup migration. TAKE A BACKUP FIRST.
#    Uses ALTER TABLE (data-preserving). rollback.sql sits beside it.
psql "$DATABASE_URL" -f prisma/migrations/20260802210000_rename_tables_and_drop_duplicates/migration.sql

# 2. Push the new tables (4 modules + RBAC)
npx prisma db push

# 3. Seed roles, screens, permissions, users
node prisma/seed-rbac.js
```

**Do not use `prisma db push` for the renames** — it implements a rename as
DROP + CREATE and would destroy the data. That is why hand-written SQL exists.

Consequence: **no real login has ever been exercised.** All verification so far
is static typecheck + unit tests. End-to-end auth is unverified.

---

## 3. What was built

### Four municipality modules (complete: schema → service → controller → tests → Flutter UI → routes → sidebar)

| Module | Backend | Frontend | Spec |
|---|---|---|---|
| Building Permits | `src/building-permit/` | `ivr_frontend/lib/features/modules/building_permits/` | doc 14 §6 |
| Birth & Death Register | `src/vital-events/` | `.../vital_events/` | doc 14 §7 |
| Solid Waste | `src/solid-waste/` | `.../solid_waste/` | doc 14 §1 |
| Trade Licences | `src/trade-licence/` | `.../trade_licences/` | doc 16 (I wrote it) |

**The established pattern** — follow it for modules 5+:
1. Typed Prisma models (snake_case cols, `@@map` to plural snake_case table, `tenant_id` + `org_unit_id` scoping)
2. A **pure helper file** for domain arithmetic, unit-tested without a DB
   (`building-permit.fees.ts`, `registration-delay.ts`, `bin-fill.ts`, `licence-year.ts`)
3. DTOs with `class-validator`
4. Service wired to the `@Global()` platform services: `NumberGenService`,
   `WorkflowService`, `SlaService`, `AuditService`, `DocumentService`
5. Controller with `JwtAuthGuard, RolesGuard, FeatureGuard` + `@RequiresFeature(...)`
6. `.spec.ts` — mock Prisma, test guards/blockers/transitions, not just happy paths
7. Flutter: `data/models/`, `data/*_repository.dart`, `presentation/screens|widgets/`
8. Routes in `app_router.dart` (+ `_getTitle` case), entry in the nav catalogue

**Domain decisions worth preserving:**
- Building permits: approval blocked unless all mandatory NOCs granted + fee paid + compliant inspection. `readiness` object returned so UI shows blockers.
- Vital events: licence/registration year logic; s.13 late bands (21d / 30d / 1yr / magistrate). Corrections cancel already-issued certificates.
- Solid waste: fill band derived **server-side** from percentage, never trusted from client. Deliberately **not** wired to the workflow engine (collection is operational, not transactional — noted in its module file).
- Trade licences: licence year = financial year (1 Apr–31 Mar) regardless of grant date; first year pro-rated by quarter. Beyond 90 days late, renewal is *refused* — fresh application required.

### Platform bugs found and fixed

1. **DMS discarded every file.** `LocalStorageAdapter` logged the filename and dropped the bytes. Replaced with `src/core/document/platform-storage.adapter.ts` backed by the real `DocumentStorageService`.
2. **`NumberGenService` never reset.** `last_reset_at` was null at creation and `needsReset` returns false on null — so sequences ran across years forever. Also added per-entity reset cycles (vital registers are calendar-year, not financial-year).
3. **`WorkflowService.getEntityContext`** had no cases for new entities, so conditional routing rules couldn't read their fields. Added `building_permit`, `vital_event`, `trade_licence`.
4. **Municipality feature flags were dead code.** `MunicipalityService.checkFeatureEnabled` existed but nothing called it. Now enforced via `@RequiresFeature` + `FeatureGuard` (`src/municipality/guards/`). Defaults for built modules flipped to `true` so enforcement didn't disable working features.

### Database rename / dedup — **written, not run**

`prisma/migrations/20260802210000_rename_tables_and_drop_duplicates/`
(`migration.sql` + `rollback.sql`)

Renames (data-preserving `ALTER TABLE`):
- `tender_documents` → `tender_document_jobs` *(never held documents — holds PDF generation jobs; sitting next to real `documents` table it was actively misleading)*
- `field_verification_uploads` → `field_verification_photos` *(holds OCR/GPS match verdicts, not uploads)*
- `calls_master` → `ivr_calls`, `call_state` → `ivr_call_states`,
  `ivr_poll_input`/`ivr_service_selection` → plural
- `properties` → `tax_properties`, `captured_assets` → `asset_field_captures`

Dropped:
- `tender_audit_logs` — duplicated `audit_logs`. Rows **copied across**, not
  discarded. `TenderAuditService` rewritten to use the platform trail with
  unchanged method signatures and row shape.
- `admin_jurisdictions` — zero readers anywhere.

⚠ Rollback recreates `admin_jurisdictions` **empty**. If it holds data you care
about, restore from backup.

### Sidebar restructure

`ivr_frontend/lib/core/navigation/role_navigation_config.dart` rebuilt as a
**single catalogue** — every destination declared once, a role is a *set of ids*.
Duplicates became structurally impossible rather than fixed.

| Role | Before | After |
|---|---|---|
| super_admin | 44 | 19 |
| panchayat_admin | 37 | 26 |
| registrar | 11 | 5 |

Five **hubs** replaced sixteen entries (`ivr_frontend/lib/features/hubs/`, shell
in `core/widgets/module_hub_scaffold.dart`): Field workforce, Water supply,
Voice & IVR, Reports & analytics, Settings. Old routes still resolve.

Real bugs this found: "Trade Licences" appeared **twice** for two roles;
"My Work Orders" sent contractors to `/work-orders/new`, a creation form they
have no permission to use; `/assets/new` likewise.

**Principle enforced by test:** sidebar entries are *destinations, not actions*.
No `/new` routes, no query-param pre-filters.

### RBAC redevelopment

**The core defect fixed:** API guards read RBAC from the DB while the sidebar
read a hardcoded map of role-name strings in Dart — so the super admin console
changed nothing on screen.

New schema:
- **`AppScreen`** — screen registry (route, label EN/TA, icon, group, module, permission_code). The tickable catalogue.
- **`RoleScreenAccess`** — role × screen × `can_view`. What the console writes. Absence = no access.
- **`RolePermission`** — replaces reading grants from `PermissionGroup.permissions` JSON. A group is *shared*, so editing one role silently changed every role on it. `PermissionGroup` survives as a **preset**; rows are truth.
- **`Role.applicable_branch_types`** — a village panchayat has no Municipal Commissioner.
- **`User.must_change_password`**

New code:
- `src/core/rbac/rbac.service.ts` — one walk of the role graph answers "what can they do" AND "what may they see". Transitive inheritance, cycle-protected, super admin short-circuits.
- `src/core/rbac/rbac-admin.service.ts` + `rbac.controller.ts` — `/api/rbac/*`. Screen/permission catalogues, role CRUD, `PUT /roles/:id/screens` (the toggle), clone-system-role, member assignment, `/me/entitlements`. All mutations audited.
- Client: `screens` rides the JWT → `UserModel.canSeeScreen()` → `sectionsFor(role, entitledScreens:, isSuperAdmin:)`.

**Design point to preserve:** an **empty** entitlement list means "server didn't
say", not "deny all". An old token or unmigrated DB would otherwise lock a
legitimate user out entirely. Once the server sends anything, it's authoritative.

### Seed — `prisma/seed-rbac.js` (**not run**)

35 screens, ~160 permissions, **25 roles across all six TN body types**:
- Corporation/Municipality: commissioner, deputy commissioner, municipal/assistant/junior engineer, health officer, sanitary inspector, revenue officer/inspector, town planning officer, registrar, licensing clerk, accounts officer
- Town Panchayat: executive officer
- Village Panchayat: president, secretary, bill collector
- Panchayat Union: BDO — District Panchayat: DPO
- Cross-cutting: super_admin, panchayat_admin, i3c_staff, contractor, electrician, plumber, agent

**Credentials:** random per account, `must_change_password = true`, written to
`prisma/.seeded-credentials.txt` — **gitignored, verified with `git check-ignore`**.
Re-running never resets an existing user's password.

### Role management console — **built, statically verified only**

One screen, `/superadmin/roles`, replacing four:
`ivr_frontend/lib/features/roles/super_admin/presentation/screens/role_management_console.dart`
with three panes under `presentation/widgets/`.

Four tabs, ordered the way you debug "why can't this person see X":
**Branch modules** (branch has it on) → **Roles & access** (role is granted it)
→ **People** (person holds that role there) → **Accounts** (account is active).

- Data layer: `data/models/rbac_models.dart`, `data/rbac_repository.dart`
  (all 14 `/api/rbac/*` endpoints), `data/rbac_grants.dart` (pure).
- `GrantSelection` holds saved-vs-selected so the save bar reports a real diff
  and Discard means something. 27 unit tests in `test/rbac_grants_test.dart`.
- Client mirrors two server rules so they fail as a disabled control with a
  reason instead of a rejected save: platform-only screens aren't offered to
  non-super-admin roles, and a role restricted by body type isn't offered at a
  branch of another type.
- `__system__` roles are read-only with a Clone-to-edit path, matching the API.
- **Kept** `user_management.dart` — `AgentManagement` reuses it and it is still
  routed at `/users`; it is embedded as the Accounts tab rather than copied.
- **Deleted** `role_permission_screen.dart` (wrote to `/api/superadmin/roles`,
  which the guards never read), `user_role_assignment_screen.dart` (pure mock —
  hardcoded rows, dead buttons), `branch_feature_toggle_screen.dart` (became
  `BranchModulesPane`, mounted in both the console and the settings hub).
- Old routes redirect rather than 404. `/superadmin/roles?user_id=` still works
  and opens People → By person, so the per-user shortcut did not regress.
- Sidebar: `role_assignments` merged away, leaving `roles`. Removed from
  `seed-rbac.js` too, so the catalogue and the seed still agree (36 → 35).

Not exercised against a running server — see section 2. `flutter analyze`
clean, 142 tests pass, `tsc` clean.

---

## 4. PENDING WORK

### Immediate
1. **Run the three DB commands above.** Everything else is blocked on this.
2. **Verify auth end-to-end for real** — never done. Only static analysis + unit tests.

### Requested, not started
4. **Login screen redesign** — user says it's "not properly designed and not
   properly worked". Must handle: multi-role, multi-branch, the
   `must_change_password` gate, Tamil/English.
5. **Data-driven dashboards** — `DashboardWidget` and `RoleDashboard` tables
   **exist and are completely unused**. User chose: super admin picks which
   cards/charts each role's dashboard shows. There are ~8 role-specific
   dashboards today (commissioner, engineer, revenue officer, health officer,
   i3c, contractor, assistant/junior engineer).
6. **Citizen portal customization** from the super admin panel.

### Known gaps (flagged to user, accepted)
- **Uploads are images only** — `file_picker` is not in `pubspec.yaml`, so PDFs
  can't be picked. Backend accepts them; viewer renders them.
- **No PDF generation** for certificates/licences. `document_id` columns exist
  and wait for a template.
- **Fee rates are placeholders** in `building-permit.fees.ts` and
  `licence-year.ts` — marked with ⚠ comments. Must be replaced with each
  council's gazetted schedule; ideally moved to master data.
- **Trade licences has no `BranchFeatureConfig` column**, so its controller has
  no `@RequiresFeature` gate. Adding one is a schema change — user's call.
- **`/certificates/verify/:qrToken`** (old certificate module) is still behind
  `JwtAuthGuard` — a citizen scanning a QR can't verify. New modules use proper
  public controllers under `/public/`.
- **`CertificateRequest`** still carries loose `application_data` for birth/death
  instead of resolving against a registered `VitalEvent`.
- No asset-register or work-order **list** screens exist (only `/new` forms),
  which is why those sidebar entries were removed.

---

## 5. Conventions to follow

- **Comments explain *why*, never narrate the diff.** No "changed X to Y".
- **Match surrounding code style** — the repo has real doc-comments on models
  and services; keep that density.
- **Public routes must live under `/public/`** — that's the prefix
  `app_router.dart`'s auth redirect exempts.
- **Tests are behavioural**, named as sentences, with comments explaining what
  real failure they prevent. Test guards and blockers, not just happy paths.
- **Never `db push` a rename.** Write `ALTER TABLE` SQL + rollback.
- **Don't invent statutory facts.** Placeholder rates get a ⚠ comment saying
  they must be replaced.
- Recent schema work goes through `db push`; the rename is the exception.

---

## 6. Suggested first message for the new chat

> Read HANDOFF.md at the repo root — it's the full context from a previous
> session. The role management console is done. Next is item 4, the login
> screen redesign. Note nothing has been run against the database yet — see
> section 2; no login has ever been exercised for real, so that redesign
> should probably wait until it has.
