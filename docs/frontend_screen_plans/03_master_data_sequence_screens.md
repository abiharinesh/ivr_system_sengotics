# Screen Plan 03: Master Data & System Configurations

> **Backend Phase:** Phase 0C (Master Data), Phase 0D (Number Gen), Phase 0E (Financial Year), Phase 0F (Calendar/Holidays), Phase 0K (Localization), Phase 0T (AppConfig)  
> **Target Audience:** System Admins, Branch Admins, Operations Managers

---

## 1. Master Data Configurator Screen (`/admin/master-data`)

### Purpose
Eliminates hardcoded enums by providing a dynamic CRUD interface for all system lookup values, complaint categories, asset types, priorities, and departments.

### UI Layout & Components
- **Master Category List Sidebar:**
  - Searchable list of categories (`complaint_category`, `asset_category`, `department`, `priority`, `status`, `holiday_type`).
  - "Add System Category" button (Admin only).
- **Master Values Data Table:**
  - Columns: Code (`electrical_fault`), English Value (`Electrical Fault`), Tamil Value (`மின் பழுது`), Parent Value, Display Order, System Protected Badge, Active Toggle.
- **Hierarchical Value Creator Modal:**
  - Parent Value Selector (for nested structures: State $\rightarrow$ District $\rightarrow$ Taluk).
  - Code & English Name inputs.
  - Tamil Translation Input (`value_ta`).
  - Display Order number spinner.
  - Custom Metadata JSON Form (e.g., Default SLA hours, SVG Icon Name).

---

## 2. Number Generation Sequence Builder (`/admin/sequence-configs`)

### Purpose
Configures automated number generation formats for complaints, work orders, tenders, permits, and assets.

### UI Layout & Components
- **Sequence Rules Table (`SequenceConfig`):**
  - Entity Type (`complaint`, `work_order`, `tender`, `asset`).
  - Prefix (`CMP`, `WO`, `TEN`).
  - Format Pattern (`{prefix}-{fy}-{seq:6}` $\rightarrow$ `CMP-2026-000042`).
  - Current Sequence Counter value display.
  - Reset Cycle Selector (`financial_year`, `calendar_year`, `never`).
- **Interactive Sequence Pattern Tester:** Live preview field demonstrating how generated numbers look in real time.

---

## 3. Financial Year Management Screen (`/admin/financial-years`)

### Purpose
Manages financial year periods, current active FY tagging, and historical FY locking.

### UI Layout & Components
- **FY Status Cards:** Highlighting Current FY (`2025-26`), Start Date (`01-Apr-2025`), End Date (`31-Mar-2026`), and Locked Status.
- **Create FY Modal:** Input FY Code (`2026-27`), Label, Start Date, End Date.
- **FY Lock Toggle:** One-click lock action preventing retroactive edits or financial modifications to closed financial years.

---

## 4. Holiday & Working Calendar Manager Screen (`/admin/calendars`)

### Purpose
Defines government working hours and holiday lists used by the SLA engine for business-hour calculations.

### UI Layout & Components
- **Working Hours Configurator Form (`WorkingCalendar`):**
  - Working Days Selector Checkboxes (Mon–Sat active, Sun off).
  - Operating Hours Time Pickers: Start Time (`09:30 AM`), End Time (`05:45 PM`).
  - Half-Day Hours Configurator (e.g., Saturday `09:30 AM` – `01:00 PM`).
- **Holiday List Calendar View (`Holiday`):**
  - Interactive Month/Year Calendar View showing marked holidays.
  - Add Holiday Modal: Date Picker, English Name (`Republic Day`), Tamil Name (`குடியரசு தினம்`), Type (`national`, `state`, `local`, `restricted`, `half_day`).

---

## 5. Localization Dictionary Manager Screen (`/admin/localization`)

### Purpose
Manages real-time translation keys and language packs for English (`EN`) and Tamil (`TA`).

### UI Layout & Components
- **Translation Search & Filter Bar:** Filter by Namespace (`labels`, `status`, `notification`, `error`), Search by key name.
- **Translation Editor Table:**
  - Key (`complaint.status.pending`).
  - English Text (`Pending`).
  - Tamil Text Input (`நிலுவையில் உள்ளது`).
- **Untranslated Keys Quick Filter:** Shows all keys missing Tamil translations.
- **Import / Export Buttons:** Export JSON language files for translation agencies or import updated files.

---

## 6. System AppConfig Dynamic Settings Screen (`/admin/app-configs`)

### Purpose
Key-value runtime configuration editor for global application behavior without redeploying code.

### UI Layout & Components
- **Config Key-Value Grid:**
  - Config Key (`storage.provider`, `sms.gateway_url`, `max_upload_size_mb`).
  - Config Value JSON Editor / Toggle Switcher.
  - Branch Scope Selector (`Tenant-Wide` vs. Specific Branch override).
