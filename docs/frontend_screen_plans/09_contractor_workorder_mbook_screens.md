# Screen Plan 09: Contractor & Work Order Management

> **Backend Phase:** Phase 6 (Contractor Management)  
> **Target Audience:** Contractors, Municipal Engineers, Assistant Executive Engineers, Accounts Officers

---

## 1. Contractor Directory & Registration Screen (`/contractors`)

### Purpose
Manages empanelled civil and maintenance contractors, license classes, performance ratings, and active projects.

### UI Layout & Components
- **Search & Class Filter Bar:**
  - Search by Name, License No, GSTIN.
  - License Class Filter (`Class I`, `Class II`, `Class III`, `Class IV`).
- **Contractor Profile Card / Table:**
  - Company/Contractor Name, License Class, GSTIN, PAN, Phone, Email, Active Status Badge, Blacklist Status Badge.
  - 5-Star Performance Rating Widget (calculated from completed work order evaluations).
  - Quick Link to Active Work Orders.
- **Onboard Contractor Modal:** Form for recording license class, bank account details, PAN, GSTIN, and uploading registration certificates.

---

## 2. Work Order Creation & Assignment Screen (`/work-orders/new`)

### Purpose
Issues sanctioned work orders to empanelled contractors, setting budget codes, financial years, and payment milestones.

### UI Layout & Components
- **General Work Order Info:**
  - Work Order Code (Auto-generated), Tender Reference ID, Title, Financial Year (`FY 2025-26`), Budget Head Code.
  - Contractor Dropdown Selector.
- **Financial & Schedule Parameters:**
  - Sanctioned Amount ($INR$), Security Deposit Amount, Start Date, Target Completion Date.
- **Milestone Breakdown Builder Table:**
  - Milestone Name (`Foundation Complete`, `Structure Complete`, `Final Handover`).
  - Milestone Percentage ($\%$) & Financial Release Amount.
  - Target Completion Date per milestone.

---

## 3. Digital Measurement Book (M-Book) Entry Screen (`/work-orders/:id/mbook`)

### Purpose
Digital replacement for government paper Measurement Books (M-Book), allowing engineers to record physical site measurements and progress.

### UI Layout & Components
- **Work Order Summary Header:** Work Order No, Contractor Name, Total Sanctioned Amount, Total Paid to Date.
- **M-Book Entry Table:**
  - Item Code / Schedule of Rates Ref (`DSR Item 4.1.2`).
  - Item Description (`Concreting M20 Grade`).
  - Measurements Input Columns: Number ($N$), Length ($L$), Breadth ($B$), Depth ($D$), Calculated Total Quantity.
  - Unit Rate ($INR$) & Calculated Total Amount.
- **Geotagged Photo Proof Attachment:**
  - Mandatory site photos attached to specific measurement line items.
- **M-Book Verification & Sign-Off Chain:**
  - Entry by Junior Engineer $\rightarrow$ Verification by Assistant Executive Engineer $\rightarrow$ Accounts Officer bill release.
