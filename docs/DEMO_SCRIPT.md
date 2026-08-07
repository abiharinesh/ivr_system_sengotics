# End-to-End Demo Script — Ooraatchi / ivr_system_sengotics

> **Purpose:** Walk someone through the live system in 15–20 minutes.
> Run the setup steps **once**; then follow the numbered walkthrough.

---

## 0. Pre-flight (one-time setup)

### 0.1 Database

```bash
# Backup first!
pg_dump "$DATABASE_URL" > backup-$(date +%Y%m%d).sql

# 1. Rename tables (data-preserving ALTER TABLE, not DROP+CREATE)
psql "$DATABASE_URL" -f prisma/migrations/20260802210000_rename_tables_and_drop_duplicates/migration.sql

# 2. Push new tables (4 municipality modules + RBAC)
npx prisma db push

# 3. Seed roles, screens, permissions, users
node prisma/seed-rbac.js
```

> **Credentials** are written to `prisma/.seeded-credentials.txt` (gitignored).
> Pick **two** accounts for the demo:
> - `super_admin` — platform-wide control
> - `commissioner` or `executive_officer` — a branch-scoped officer

### 0.2 Start services

```bash
# Backend (NestJS)
npm run start:dev          # http://localhost:3000

# Frontend (Flutter web)
cd ivr_frontend
flutter run -d chrome      # http://localhost:PORT
```

### 0.3 Sanity check

```bash
# Backend compiles
npx tsc -p tsconfig.build.json --noEmit

# Tests pass
npx jest                   # 317+ backend tests
cd ivr_frontend && flutter test   # 142+ frontend tests
```

---

## 1. Login — Staff sign-in

| Step | Action | What to show |
|------|--------|--------------|
| 1.1 | Open the app in Chrome | Login screen appears — split-pane on desktop, single card on mobile |
| 1.2 | Enter the **super_admin** email and temp password from `.seeded-credentials.txt` | Fields validate as you type |
| 1.3 | Submit | Redirected to **Change Password** screen (because `must_change_password = true`) |
| 1.4 | Set a new password and confirm | Redirected to the **Dashboard** |

> **Talking point:** Every seeded account forces a password change on first use.
> Forgotten passwords are not self-serve — the branch admin resets them from
> the role console. This matches TN government IT policy.

---

## 2. Dashboard — Role-based landing

| Step | Action | What to show |
|------|--------|--------------|
| 2.1 | Observe the dashboard panels | Each role lands on widgets chosen for it via `role_dashboards` |
| 2.2 | Point out the sidebar | Built from `app_screens` × `role_screen_access` — the admin can change it |
| 2.3 | Click **Settings → Appearance** | Theme (Light / Dark / System) and Language (English / தமிழ்) |
| 2.4 | Toggle to **Dark mode** | Whole app responds instantly |
| 2.5 | Switch language to **தமிழ்** | Preference is persisted locally |
| 2.6 | Switch back to **Light / English** | Reset to continue the demo in English |

---

## 3. Role Management Console — `/superadmin/roles`

This is the centrepiece of the RBAC rebuild. One screen, seven tabs.

| Step | Action | What to show |
|------|--------|--------------|
| 3.1 | Open **Roles & access** in the sidebar | Console loads with analytics cards |
| 3.2 | **Overview tab** | KPI cards: total roles, screens, unassigned screens, users |
| 3.3 | **Matrix tab** | Role × Screen heatmap — find which screens nobody can reach |
| 3.4 | **Geography tab** | Map of branches by body type with role counts |
| 3.5 | **Branch modules tab** | Toggle modules on/off per branch. "This is gate 1" |
| 3.6 | **Roles & access tab** | Pick a role (e.g. `commissioner`). Toggle screen access. Save bar appears with diff count |
| 3.7 | **People tab** | See who holds the role. Assign/remove members |
| 3.8 | **Accounts tab** | User list. Point out the per-user shortcut that opens People → By person |

> **Talking point:** "Why can't this person see X?" is answered by reading
> these four gates in order: branch module → role grant → person assignment →
> account active. All four now live on one screen.

---

## 4. Municipality Modules — The four new modules

### 4.1 Building Permits

| Step | Action | What to show |
|------|--------|--------------|
| 4.1a | Navigate to **Building Permits** | List screen with KPI cards |
| 4.1b | Create a new permit | Form with applicant details, plot info, floor area |
| 4.1c | View the detail screen | NOC checklist, fee calculation, inspection status |
| 4.1d | Show the **readiness object** | Approval is blocked unless NOCs granted + fee paid + compliant inspection |

### 4.2 Birth & Death Registry

| Step | Action | What to show |
|------|--------|--------------|
| 4.2a | Navigate to **Vital Events** | Registry list, searchable |
| 4.2b | Register a birth | Form with informant, place of birth, parents |
| 4.2c | Show late registration bands | 21d free → 30d late fee → 1yr magistrate → beyond 1yr refused |
| 4.2d | Show certificate verification | Navigate to `/public/verify-certificate/:token` — works without login |

### 4.3 Trade Licences

| Step | Action | What to show |
|------|--------|--------------|
| 4.3a | Navigate to **Trade Licences** | Register with financial-year columns |
| 4.3b | Create a new licence | Business details, category, fee calculation |
| 4.3c | Show licence year logic | 1 Apr – 31 Mar; first year pro-rated by quarter |
| 4.3d | Show renewal rules | >90 days late → renewal refused → fresh application required |
| 4.3e | Public verification | `/public/verify-licence/:token` — citizen scans the QR in the shop |

### 4.4 Solid Waste Management

| Step | Action | What to show |
|------|--------|--------------|
| 4.4a | Navigate to **Solid Waste** | Ward/zone overview with collection routes |
| 4.4b | Show fill-band calculation | Percentage → band derived **server-side**, never trusted from client |
| 4.4c | Point out: deliberately not wired to workflow engine | Collection is operational, not transactional |

---

## 5. Existing Platform Features (quick fly-over)

These were already built; show them briefly to demonstrate scope.

| Area | Route | What to point out |
|------|-------|-------------------|
| **Complaints / Grievances** | `/complaints` | Full lifecycle, assignment, SLA tracking |
| **Pole Management** | `/poles` | GIS asset registry with QR codes |
| **Tenders / e-Procurement** | `/tenders` | Create → invite vendors → quotations → award |
| **Water Supply** | `/water` | Pipeline grid, tanks & borewells, flow logs |
| **Field Workforce** | `/workforce` | Agents, electricians, plumbers — hub with tabs |
| **Voice & IVR** | `/voice-ivr` | Call logs, IVR poll inputs |
| **Reports & Analytics** | `/insights` | Service analytics, report generation, SLA focus |
| **Document Templates** | Settings → Document templates | Template management per body type |

---

## 6. Context Switching — Multi-role, multi-branch

| Step | Action | What to show |
|------|--------|--------------|
| 6.1 | Navigate to **Switch Context** (`/select-context`) | Shows all role assignments from the JWT |
| 6.2 | Pick a different assignment | `POST /api/auth/switch-context` re-scopes the session |
| 6.3 | Observe the sidebar change | Screens are resolved fresh for the new role × branch |

> **Talking point:** A single person can hold multiple roles across multiple
> branches (e.g. Revenue Officer in Annur and also acting Executive Officer
> in a nearby village panchayat).

---

## 7. Citizen Journey (zero-auth)

| Step | Action | What to show |
|------|--------|--------------|
| 7.1 | Click "Report a problem as a resident" on the login screen | Opens `/register-citizen` |
| 7.2 | Submit a pole/streetlight complaint | Citizen gets a tracking token |
| 7.3 | Open `/public/track/:token` | Real-time complaint status without logging in |
| 7.4 | Show a QR code scan → `/public/report/:token` | Zero-auth pole report from the field |

---

## 8. Settings Hub — `/settings`

| Step | Action | What to show |
|------|--------|--------------|
| 8.1 | **Appearance** tab | Theme + Language (just trimmed in Phase 4) |
| 8.2 | **Document templates** tab | Per-body-type template configuration |
| 8.3 | **AI providers** tab | STT/TTS provider settings |
| 8.4 | **Module access** tab (super admin only) | Branch × module provisioning matrix |

---

## 9. Verification & Close

End with confidence:

```bash
# Backend
npx tsc -p tsconfig.build.json --noEmit    # clean
npx jest                                    # all passing

# Frontend
cd ivr_frontend && flutter analyze lib      # clean
cd ivr_frontend && flutter test             # all passing
```

> **Final talking point:** Everything you just saw — the four municipality
> modules, the RBAC rebuild, the role console, the login flow — is statically
> verified and unit-tested. What remains is running it against the live
> database (Section 0) and exercising the auth flow for real.

---

## Quick Reference: Demo Accounts

| Role | Email pattern | Notes |
|------|---------------|-------|
| `super_admin` | See `.seeded-credentials.txt` | Platform-wide access |
| `commissioner` | " | Corporation/Municipality officer |
| `executive_officer` | " | Town Panchayat head |
| `registrar` | " | Birth & Death registrar |
| `licensing_clerk` | " | Trade licence operations |
| `agent` | " | Field survey worker |
| `electrician` | " | Streetlight maintenance |

All accounts start with `must_change_password = true` and random temp passwords.
