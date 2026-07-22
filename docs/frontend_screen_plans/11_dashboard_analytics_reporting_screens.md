# Screen Plan 11: Dashboard, Analytics & Reporting Engine

> **Backend Phase:** Phase 8 (Dashboard & Reporting Engine)  
> **Target Audience:** Executive Officers, Commissioners, Collectors, Department Heads, Public Auditors

---

## 1. Customizable Executive Dashboard Screen (`/dashboard`)

### Purpose
High-level analytical dashboard providing real-time operational metrics, GIS heatmaps, SLA compliance status, and budget utilization charts tailored to the user's role.

### UI Layout & Components
- **Dashboard Control Bar:**
  - Role View Selector (Switches widgets for *Executive*, *Engineer*, *Finance*, or *Health Officer*).
  - Time Range Picker (`Today`, `This Week`, `This Month`, `FY 2025-26`, `Custom`).
  - "Customize Dashboard Grid" button (Drag-and-drop widget layout editor).
- **Available Executive Widgets Grid (`DashboardWidget`):**
  - **Widget 1: Grievance Resolution SLA Gauge:** Radial gauge displaying % of complaints resolved within SLA.
  - **Widget 2: Spatial GIS Heatmap:** Map displaying hot zones for recurring infrastructure faults or grievances.
  - **Widget 3: Asset Operational Health Donut Chart:** % Operational vs. Maintenance Required vs. Decommissioned.
  - **Widget 4: Budget Sanction vs. Expenditure Bar Chart:** Budget utilization across schemes and wards.
  - **Widget 5: Active Work Order Pipeline:** Status breakdown of ongoing civil work orders.

---

## 2. Dynamic Report Builder & Scheduled Export Screen (`/reports/builder`)

### Purpose
Allows users to construct custom tabular and visual reports with multi-format export (PDF, Excel) and automated email/WhatsApp scheduling.

### UI Layout & Components
- **Report Configuration Pane (`SavedReport`):**
  - Data Source Selector (`Complaints`, `Assets`, `Work Orders`, `Tenders`, `Contractors`, `Audit Logs`).
  - Column Picker Checkboxes (Select specific fields to include).
  - Filter & Aggregation Rule Builder (e.g., `Group by Ward`, `Filter by Status = Resolved`, `SUM(cost)`).
- **Live Report Data Preview Grid:**
  - Interactive table showing sample report results.
- **Export & Schedule Action Bar:**
  - One-Click Instant Export: **Download PDF** (formatted in English & Tamil with government header), **Download Excel (`.xlsx`)**, **Download CSV**.
  - **Scheduled Delivery Modal:** Schedule automated report execution (e.g., Daily at 8:00 AM) dispatched via Email or WhatsApp to designated recipient lists.
