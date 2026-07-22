# Screen Plan 12: DMS, Audit Trail & Integration Monitors

> **Backend Phase:** Phase 0G (Audit Trail), Phase 0I (DMS), Phase 0J (File Storage), Phase 0L (Integrations)  
> **Target Audience:** System Admins, Security Auditors, Records Managers, Integration Specialists

---

## 1. Document Management System (DMS) Explorer (`/documents`)

### Purpose
Central repository for uploading, organizing, tagging, versioning, and verifying official government documents and certificates.

### UI Layout & Components
- **Folder Navigation Tree (`DocumentFolder`):**
  - Directory tree (`Engineering` $\rightarrow$ `Tenders 2026`, `Revenue` $\rightarrow$ `Land Maps`).
  - Create Folder modal & Folder permissions config.
- **Document Grid / Table (`Document`):**
  - Title, File Name, File Size, Mime Type (`PDF`, `Image`), Tags, Linked Module (`Work Order #42`), Version Number (`v1`, `v2`), Uploaded By.
- **Storage Provider Indicator Badge:** Displays storage provider abstraction status (`Local S3-Compatible`, `AWS S3`, `Azure Blob`, `GCS`).
- **Digital Signature Certificate Card:**
  - Displays e-Sign certification details, Signer Name, Signing Timestamp, and SHA-256 Document Hash.

---

## 2. Immutable Audit Log Inspector Screen (`/admin/audit-logs`)

### Purpose
Provides security administrators with a search and inspection tool for exploring immutable audit logs across all system mutations.

### UI Layout & Components
- **Audit Log Search & Filter Bar:**
  - Filter by Module (`complaints`, `assets`, `users`, `tenders`), Action (`CREATE`, `UPDATE`, `DELETE`, `APPROVE`), User ID, Date Range.
- **Audit Log Data Table (`AuditLog`):**
  - Columns: Timestamp, User, Module, Entity Type, Entity ID, Action, IP Address, Device/Browser Info, Actions.
- **Side-by-Side JSON Diff Viewer Modal:**
  - Visual color-coded code view highlighting exact JSON differences between `before_value` (Red) and `after_value` (Green).

---

## 3. Integration & Webhook Monitor Screen (`/admin/integrations`)

### Purpose
Monitors third-party API integrations (TANGEDCO, TWAD, DigiLocker, Payment Gateways) and webhook dispatches.

### UI Layout & Components
- **Integration Cards Grid (`IntegrationConfig`):**
  - Integration Title, Type (`rest_api`, `webhook`, `soap`), Auth Type, Connection Status Indicator (Active Green / Error Red).
- **Integration Sync Job Scheduler (`IntegrationSyncJob`):**
  - Cron schedule expression display (`0 2 * * *`), Last Sync Time, Last Sync Status (`Success`, `Partial`, `Failed`).
- **Integration & Webhook Log Inspector (`IntegrationLog`):**
  - HTTP Method, Request URL, Response Status Code (`200 OK`, `500 Internal Error`), Execution Duration ($ms$).
  - Raw Request & Response Payload JSON Inspector with manual "Retry Webhook Dispatch" button.
