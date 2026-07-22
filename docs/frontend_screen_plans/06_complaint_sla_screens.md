# Screen Plan 06: Grievance & SLA Management System

> **Backend Phase:** Phase 3 (SLA Engine), Phase 0C (Master Data), Phase 0H (Notifications), Phase 0M (Event Bus)  
> **Target Audience:** Citizens, Ward Officers, Panchayat Secretaries, Municipal Engineers, SLA Officers

---

## 1. Public Citizen Grievance Registration Screen (`/complaints/new`)

### Purpose
Public-facing grievance submission screen optimized for citizens with voice recording, map pin location picker, and Tamil language support.

### UI Layout & Components
- **Language & Accessibility Header:** Tamil/English toggle, Voice Assistance mode button.
- **Step 1: Complaint Category Picker:**
  - Visual card grid displaying category icons and titles in English and Tamil (e.g., Electrical Fault / மின் பழுது, Road Pothole / சாலை பழுது, Drainage Block / கழிவுநீர் அடைப்பு).
- **Step 2: Grievance Description & Audio Recorder Widget:**
  - Textarea input for written description.
  - In-App Voice Recording Widget: Tap to record voice memo in Tamil/English, audio waveform display, playback preview player.
- **Step 3: Geotagged Location Picker:**
  - Interactive map pin selector auto-detecting current GPS location, ward number, and street address.
  - Linked Asset Selector (Optional): Select specific nearby street light or pump asset code.
- **Step 4: Photo/Video Attachment:** Multi-file uploader for damage photos or video clips.
- **Dynamic SLA Target Banner:** Real-time badge previewing guaranteed resolution timeframe (e.g., "Guaranteed resolution by Friday 11:30 AM as per Municipal SLA").

---

## 2. Employee Grievance Inbox & Kanban Screen (`/complaints/inbox`)

### Purpose
Central workbench for municipal staff to monitor, process, reassign, and resolve filed grievances.

### UI Layout & Components
- **Control Bar:** Toggle View Modes (**Kanban Board** vs. **Data Table**), Filter by Category, Ward, Priority, SLA Status (`On Track`, `Warning`, `Breached`).
- **Kanban Board Columns:**
  - Columns: `New Registered`, `Assigned`, `In Progress`, `Pending Verification`, `Resolved`, `Closed`.
  - Drag-and-Drop Card Cards displaying Complaint No (`CMP-2026-000042`), Category Icon, Address, Citizen Name, Assigned Officer, and Live SLA Clock.
- **Live SLA Countdown Clock Widget:**
  - Dynamic visual timer calculating business hours (excluding non-working hours and holidays).
  - Color-coded badges: Green ($> 50\%$ SLA time remaining), Orange (Warning threshold reached), Red (SLA Breached).

---

## 3. Complaint Details & Resolution Screen (`/complaints/:id`)

### Purpose
Deep view of a single complaint showing activity history, communication logs, SLA escalation status, and resolution submission form.

### UI Layout & Components
- **Complaint Header:** Complaint ID, Citizen Name & Phone, Current Status Badge, Category, Ward Number.
- **SLA Tracker Card (`SlaTracker`):** SLA Started Time, Business Target Date/Time, Warning Target Date/Time, Escalation Target, Paused/Resumed Hours Summary, Current Status (`on_track`, `warning`, `escalated`, `breached`).
- **Activity & Conversation Timeline:**
  - Chronological feed of status updates, assignment changes, voice memo playback player, citizen comments, and sent notifications (SMS, WhatsApp, Push).
- **Action Modal Controls:**
  - **Reassign Action:** Select new officer, set reassignment reason.
  - **Pause SLA Action:** Pause timer for external dependency (e.g., waiting for TANGEDCO power shutoff) with mandatory documentation link.
  - **Resolve Complaint Modal:** Mandatory completion photo uploader, resolution notes, contractor work order linkage, push notification dispatch toggle.

---

## 4. SLA Policy & Rule Configurator Screen (`/admin/sla-policies`)

### Purpose
Allows administrators to define SLA resolution hours, warning thresholds, auto-escalation pathways, and 24x7 emergency overrides.

### UI Layout & Components
- **SLA Policy Matrix Data Table (`SlaPolicy`):**
  - Columns: Entity Type (`complaint`), Category, Urgency Level (`Critical`, `High`, `Medium`, `Low`), Target Hours (Business Hours), Warning Hours, Escalation Hours, Escalation Role, 24x7 Override, Active Status.
- **Create / Edit SLA Policy Modal:**
  - Category & Urgency level dropdowns.
  - Target Business Hours input (uses `WorkingCalendar` for target date calculation).
  - Warning Threshold Hours & Escalation Threshold Hours.
  - Escalation Role Selector (e.g., Auto-escalate to *Executive Engineer* if unresolved after 24 hours).
  - **24x7 Emergency Hour Override Checkbox:** Ignores non-working calendar hours for urgent infrastructure emergencies.

---

## 5. SLA Performance Analytics Dashboard (`/analytics/sla`)

### Purpose
Executive dashboard tracking municipal SLA compliance rates, department resolution speed, and breach root causes.

### UI Layout & Components
- **KPI Summary Cards:** Overall SLA Compliance Rate ($\%$), Total Resolved Complaints, Average Resolution Time (Hours), Active Breached Complaints.
- **Analytical Chart Grid:**
  - **SLA Compliance by Department (Bar Chart):** Engineering vs. Health vs. Sanitation compliance percentages.
  - **Ward-Wise SLA Heatmap (GIS Map):** Identifies geographical zones with highest SLA breaches.
  - **Breach Rationale Breakdown (Donut Chart):** Distribution of delay reasons (Material shortage, Staff absence, External agency delay).
