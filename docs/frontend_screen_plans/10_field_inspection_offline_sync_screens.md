# Screen Plan 10: Field Inspection & Mobile Offline Sync

> **Backend Phase:** Phase 7 (Field Inspection) & Phase 10 (Offline Sync Flutter)  
> **Target Audience:** Field Inspectors, Electricians, Plumbers, Sanitary Inspectors, Mobile App Users

---

## 1. Inspector Mobile Route & Task Dashboard Screen (`/mobile/dashboard`)

### Purpose
Mobile-first dashboard for field officers displaying assigned inspection tasks, daily route maps, and urgent site visits.

### UI Layout & Components
- **Top Status & Sync Bar:**
  - Online / Offline Connectivity Indicator Pill (Green = Online, Orange = Offline/SQLite Mode).
  - Sync Queue Counter Badge (`3 Pending Sync`).
- **Today's Task List Cards:**
  - Target Site / Asset Code, Location Address, Priority Tag (`Urgent`, `Routine`), Distance in KM from current position.
  - "Navigate via Map" button & "Start Inspection" button.
- **Route Map View:**
  - Embedded map showing optimized route connecting all today's assigned inspection sites.

---

## 2. Geofenced Offline Field Inspection Execution Screen (`/mobile/inspection/execute`)

### Purpose
Executes field inspection audits offline with strict location verification, watermarked camera capture, and digital signatures.

### UI Layout & Components
- **Geofence Verification Lock Banner:**
  - Live GPS distance indicator checking physical presence at the site.
  - Submissions remain disabled until inspector is physically within the geofenced site boundary ($e.g., \le 50\text{ meters}$).
- **Inspection Checklist Form Component:**
  - Touch-friendly pass/fail buttons, score sliders (0–100), and text remarks.
- **Watermarked Camera Capture Widget:**
  - Custom camera overlay capturing photo and stamping timestamp, GPS coordinates (`lat`, `lng`), accuracy radius, and Inspector ID onto the image binary.
- **Digital Touch Signature Pad:**
  - Touchscreen signature drawing box for inspector or site supervisor sign-off.

---

## 3. Offline Sync Queue & Conflict Resolution Center (`/mobile/sync-center`)

### Purpose
Manages background SQLite sync queue, data upload status, and resolution of server-vs-local conflict situations.

### UI Layout & Components
- **Sync Status Summary Card:** Total Synced Records, Pending Local Uploads, Failed Records.
- **Pending Queue Items List:**
  - Lists offline-created records (Inspections, Complaints, Asset updates) with local timestamp.
  - Manual "Sync All Now" trigger button.
- **Conflict Resolution Screen Modal (`Server vs. Local`):**
  - Displays side-by-side comparison when a record was edited on the server while the officer was offline.
  - Options: `Keep Local Version`, `Keep Server Version`, `Merge Fields`.
