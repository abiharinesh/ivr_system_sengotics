# Screen Plan 01: Auth, Identity & Session Management

> **Backend Phase:** Phase 0B (Multi-Tenancy, Identity, Employee & RBAC)  
> **Target Audience:** All Users (Citizens, Employees, Admins, Contractors)

---

## 1. Login & Authentication Screen (`/login`)

### Purpose
Serves as the primary entry point for all users across web, mobile, and desktop. Dynamically detects tenant context and adapts UI input modes (Citizen OTP vs. Employee Credentials).

### UI Layout & Components
- **Header:**
  - Tenant Branding Logo (`Tenant.logo_url` or default Tamil Nadu State Emblem).
  - Language Switcher Pill Button (`EN` / `தமிழ்`).
- **Domain & Tenant Selector Card:**
  - Auto-resolves tenant from URL host (e.g., `madurai.platform.gov.in` $\rightarrow$ Madurai Corporation).
  - Manual Tenant Search Dropdown for staging/demo environments.
- **Tabbed Auth Controller:**
  - **Tab 1: Citizen Login (Phone & OTP)**
    - 10-digit Indian Mobile Number input with `+91` prefix.
    - Captcha verification challenge box (triggers after 3 failed attempts).
    - "Get OTP via SMS" & "Get OTP via WhatsApp" buttons.
  - **Tab 2: Employee Login (Email/Phone + Password)**
    - Email or Mobile Number input.
    - Password input with toggle show/hide eye icon.
    - "Forgot Password?" recovery workflow link.
- **Footer:**
  - Links to Citizen Registration, Privacy Policy, Terms of Service, and Helpdesk Helpline.

---

## 2. Multi-Factor & OTP Verification Screen (`/verify-otp`)

### Purpose
Verifies phone number or 2FA challenge for login, registration, and sensitive administrative actions.

### UI Layout & Components
- **6-Digit Pin Input Field:** Auto-focuses on the first box; supports OTP auto-fill on mobile devices.
- **Resend Countdown Timer:** Visual radial progress timer (60s countdown). Enables "Resend OTP" button upon expiration.
- **Device Trust Checkbox:** "Remember this device for 30 days" (sets trusted device cookie/JWT flag).
- **Verification Button:** Submits OTP payload `{ phone, otp, tenant_id }`.

---

## 3. Role & Branch Context Selector Screen (`/select-context`)

### Purpose
Mandatory intermediate screen for employees assigned to multiple roles or posted across multiple branches (e.g., a BDO managing multiple panchayats or an Engineer covering multiple zones).

### UI Layout & Components
- **User Profile Summary Banner:** Displays Employee Name, Code, and primary cadre.
- **Active Postings Grid (Card List):**
  - **Card Header:** Branch Name (e.g., *Usilampatti Panchayat Union*) & Branch Type Tag (*PANCHAYAT_UNION*).
  - **Role & Designation Tag:** *Block Development Officer (BDO)*.
  - **Department Tag:** *General Admin*.
  - **Access Scope Badge:** `own_branch`, `child_branches`, or `all_branches`.
- **Selection Action:** Clicking a card issues an updated JWT containing `X-Branch-ID`, `X-Role-ID`, and `access_scope` headers, redirecting to the tailored dashboard.

---

## 4. Employee Service Book & Profile Screen (`/profile/employee`)

### Purpose
Comprehensive view of government employee service records, posting history, and granted RBAC permissions.

### UI Layout & Components
- **Profile Header Card:**
  - Official Photo Avatar with upload photo modal.
  - Full Name, Employee Code (`EMP-00042`), Service Book No, Cadre (`TNCS`), Pay Level.
  - Active Status Chip (`Active`, `On Leave`, `Transferred`, `Retired`, `Suspended`).
- **Tabbed Profile Sections:**
  - **Tab 1: Current Posting & Personal Info:** Department, Designation, Hierarchy Level (1–10), Primary Branch, Date of Joining, Retirement Countdown Card.
  - **Tab 2: Designation & Transfer History (`DesignationHistory`):** Interactive vertical timeline showing historical postings, past designations, transfer dates, and attached Government Order reference numbers (`G.O. Ms. No.`).
  - **Tab 3: Subordinates & Reporting Hierarchy:** Organizational chart displaying direct supervisor (`reporting_to_id`) and reporting team members.
  - **Tab 4: Granted Permissions Matrix:** Table listing active permission codes (`complaints.approve`, `assets.create`) inherited from active role groups.
