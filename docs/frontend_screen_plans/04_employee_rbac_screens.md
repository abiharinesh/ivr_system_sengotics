# Screen Plan 04: Employee & RBAC Management

> **Backend Phase:** Phase 0B (Identity, Employee & RBAC)  
> **Target Audience:** HR Officers, System Admins, Branch Admins

---

## 1. Employee Directory & Search Screen (`/employees`)

### Purpose
Central directory for searching, filtering, and managing government employees across departments and branches.

### UI Layout & Components
- **Search & Filter Header Bar:**
  - Search by Name, Employee Code (`EMP-00042`), Phone, or Service Book Number.
  - Department Dropdown (`Engineering`, `Health`, `Town Planning`, `Revenue`, `General Admin`).
  - Branch Selector & Status Filter (`Active`, `On Leave`, `Transferred`, `Retired`).
- **Employee Data Table / Card View:**
  - Photo Thumbnail, Full Name, Designation, Department, Branch, Cadre, Phone Number, Status Badge.
  - Quick Action Buttons: View Profile, Edit Details, Transfer Employee, Manage Roles.

---

## 2. Employee Onboarding & Registration Form Screen (`/employees/new`)

### Purpose
Registers a new government employee, creates their user login identity, and sets up their initial posting.

### UI Layout & Components
- **Step 1: User Login Identity:**
  - Phone Number, Email, Password / Initial OTP generation trigger, User Type (`employee`).
- **Step 2: Official Service Details:**
  - Employee Code (Auto-generated or Manual), Service Book Number, Cadre (`TNCS`, `TNMS`, `TNES`), Pay Level, Qualification.
- **Step 3: Posting & Designation:**
  - Department, Designation title, Hierarchy Level (1–10 slider), Access Scope (`own_branch`, `child_branches`, `all_branches`), Primary Branch Posting, Date of Joining, Direct Supervisor (`reporting_to_id`).
- **Step 4: Photo & Document Upload:**
  - Photo attachment, ID proof uploader, Appointment Order attachment.

---

## 3. Designation & Transfer History Screen (`/employees/:id/transfers`)

### Purpose
Tracks employee transfers between branches and promotions/designation changes over time.

### UI Layout & Components
- **Current Posting Card:** Branch, Designation, Department, Posted Since Date.
- **Transfer / Promotion Modal:**
  - Target Branch Selector.
  - New Designation & Department.
  - Effective Date Picker.
  - Government Order Reference (`G.O. Ms. No.`) & Attached Order PDF.
- **Historical Postings Timeline (`DesignationHistory`):**
  - Timeline cards displaying previous designations, branches, start/end dates, G.O. numbers, and official transfer remarks.

---

## 4. Role & Permission Matrix Manager Screen (`/admin/rbac/roles`)

### Purpose
Configures permission groups, role definitions, and granular permission assignment across all modules.

### UI Layout & Components
- **Role List Sidebar:** List of system and custom roles (`municipal_engineer`, `panchayat_secretary`, `bdo`, `sanitary_inspector`).
- **Role Configurator Pane:**
  - Role Name, Display Name English, Display Name Tamil (`நகராட்சி பொறியாளர்`), Hierarchy Level, Department association.
  - Approval Authority Toggle (`can_approve`).
  - Role Inheritance Dropdown (`inherits_from_role_id`).
- **Granular Permission Checkbox Matrix:**
  - Grouped by Module (`Complaints`, `Assets`, `Tenders`, `Work Orders`, `Users`).
  - Actions: `Read`, `Write`, `Approve`, `Delete`, `Export`.

---

## 5. User Role Assignment Manager Screen (`/admin/rbac/assignments`)

### Purpose
Assigns roles to users for specific branch scopes with optional expiration dates for temporary acting duties.

### UI Layout & Components
- **User Search & Current Roles Card:** Select user to view assigned roles.
- **Assign New Role Modal:**
  - Role Dropdown Selector.
  - Target Branch Scope Selector (e.g., Assign role specifically within *Ward 14* or *Entire Panchayat Union*).
  - Temporary Role Toggle (`is_temporary`).
  - Valid From Date & Valid Until Expiry Date Picker (for acting assignments during leave).
  - Granted By Audit Stamp.
