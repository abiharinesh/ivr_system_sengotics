# Screen Plan 07: Workflow Engine & Conditional Approval Matrix

> **Backend Phase:** Phase 4 (Workflow Engine & Conditional Approval Matrix)  
> **Target Audience:** Department Heads, Executive Engineers, Municipal Commissioners, Collectors, Approval Authorities

---

## 1. Workflow Template Visual Builder Screen (`/admin/workflows/builder`)

### Purpose
Visual interface for designing sequential or parallel approval workflows for work orders, tenders, building permits, and financial sanctions.

### UI Layout & Components
- **Template Details Header:** Workflow Name, Module (`work_orders`, `tenders`, `permits`), Entity Type, Tenant/Branch Scope.
- **Visual Workflow Node Canvas:**
  - Node-based step builder: `Step 1: Junior Engineer` $\rightarrow$ `Step 2: Assistant Executive Engineer` $\rightarrow$ `Step 3: Commissioner`.
  - Add Step Node Button: Configures Step Name, Target Role (`role_id`), Allowed Actions (`Approve`, `Reject`, `Seek Info`), and Step Timeout (Hours).
- **Step Rule Inspector Drawer:**
  - Configure automatic timeout actions (e.g., Auto-forward to supervisor after 48 hours).
  - Mandatory Digital Signature requirement toggle.

---

## 2. Conditional Approval Matrix Builder Screen (`/admin/workflows/rules`)

### Purpose
Configures dynamic routing rules that modify approval steps based on transaction parameters (e.g., financial cost thresholds, urgency levels).

### UI Layout & Components
- **Conditional Rules Data Table (`WorkflowRule`):**
  - Workflow Template, Target Step, Condition Field (`estimated_cost`), Operator (`gt`), Value (`500000`), Action (`add_step`), Target Value (`Collector Approval`), Priority.
- **Rule Creator Form:**
  - Condition Field Selector: `estimated_cost`, `urgency_level`, `ward_number`, `contractor_class`.
  - Operator Selector: `gt` ($>$), `lt` ($<$), `eq` ($=$), `in`, `between`.
  - Action Selector: `skip_step` (Skip step for minor requests), `add_step` (Add mandatory higher sanction step), `route_to_role` (Re-route to specific role).
  - Priority Level Ordering slider.

---

## 3. Universal Approvals Inbox Screen (`/approvals`)

### Purpose
Single unified inbox for executive officers to review, approve, or reject pending requests across all municipal modules.

### UI Layout & Components
- **Inbox Filter & Counter Bar:** Tabs for `All Pending`, `Work Orders`, `Tenders`, `Building Permits`, `Leave Requests`, `Completed Approvals`.
- **Pending Approval Item Card:**
  - Request Type Badge, Item Reference ID (`WO-2026-000012`), Initiated By Employee, Timestamp, Financial Value ($e.g., \text{\rupee }7,50,000$).
  - Current Step Badge (`Step 2 of 3: AEE Review`).
- **Inline PDF & File Document Viewer:**
  - Embedded PDF preview pane for inspecting attached estimates, measurement books, blueprints, or tender documents.
  - Financial Summary & Budget Head Code verification widget.

---

## 4. Approval Decision & Digital Signature Modal (`/approvals/:id/decide`)

### Purpose
Modal dialog for executing approval decisions with mandatory comments and digital signature authentication.

### UI Layout & Components
- **Decision Action Buttons:** `Approve` (Green), `Reject` (Red), `Return for Clarification` (Yellow), `Delegate` (Blue).
- **Official Remarks Textarea:** Mandatory input for official approval notes or rejection rationale.
- **Digital Signature Authentication Box:**
  - Choice of Signature Mode: PIN / Passcode Input, Biometric TouchID/FaceID (Mobile), or Digital Certificate File (`.p12` / e-Sign USB token).
  - Submits signed approval payload `{ instance_id, step_id, action, remarks, digital_signature }`.
