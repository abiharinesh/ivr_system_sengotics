# Screen Plan 02: Core Platform & Branch Administration

> **Backend Phase:** Phase 0A (Multi-Tenancy) & Phase 1 (Branch Architecture & Lifecycle)  
> **Target Audience:** Super Admin, State Level Admins, District Admins

---

## 1. Tenant Management & Overview Screen (`/admin/tenants`)

### Purpose
Allows Super Admins to manage state-level tenants, subscription plans, maximum branch limits, and global tenant configurations.

### UI Layout & Components
- **Tenant Overview Cards:** Metrics showing Total Tenants, Active Deployments, Total Managed Branches, and Total Active Users.
- **Tenant Data Table:**
  - Columns: Tenant ID (`tn_govt`), Name, Domain (`tn.platform.gov.in`), Subscription (`enterprise`), Max Branches, Status (`Active`/`Inactive`), Actions.
  - Quick Search & Filter bar.
- **Create / Edit Tenant Modal:**
  - Form fields: Tenant ID, Display Name, Custom Domain, Logo URL uploader, Max Branches limit slider, Tenant Config JSON editor.

---

## 2. Branch Hierarchy & Tree Viewer Screen (`/admin/branches/tree`)

### Purpose
Interactive organizational tree visualizer representing the multi-level administrative hierarchy of local bodies in Tamil Nadu.

### UI Layout & Components
- **Administrative Hierarchy Tree Node Component:**
  - **Level 1:** State Administration (`Tamil Nadu`)
  - **Level 2:** District Panchayats (`Madurai District Panchayat`)
  - **Level 3:** Panchayat Unions / Municipal Corporations (`Usilampatti Block`, `Madurai Corporation`)
  - **Level 4:** Village Panchayats / Town Panchayats / Wards (`Thirumangalam Village`, `Ward 14`)
- **Node Action Bar:** Expand/Collapse All nodes, Filter by Branch Type (`VILLAGE_PANCHAYAT`, `MUNICIPALITY`, etc.), Click node to view details or add child branch.

---

## 3. Branch Lifecycle & Status Management Screen (`/admin/branches/:id/lifecycle`)

### Purpose
Manages administrative state changes of local body branches (mergers, upgrades from Village Panchayat to Municipality, closure).

### UI Layout & Components
- **Branch Header Card:** Branch Code, Current Type, Current Status (`DRAFT`, `ACTIVE`, `INACTIVE`, `MERGED`, `UPGRADED`, `CLOSED`).
- **Status Transition Action Dialog:**
  - Status Target Dropdown (`MERGED`, `UPGRADED`, `CLOSED`).
  - Target Merged/Upgraded Branch Selector (e.g., Select new Municipality absorbing the Village Panchayat).
  - Effective Date Picker.
  - Status Change Rationale & Government Order Document Attachment (`G.O. Reference`).
- **Lifecycle Event Log Table (`BranchLifecycleEvent`):**
  - Timeline of state changes showing Event Type, From Status, To Status, Effective Date, Performed By User.

---

## 4. Branch GIS Boundary & Geofence Drawer Screen (`/admin/branches/:id/gis`)

### Purpose
Allows administrators to map and draw spatial boundaries, ward containment polygons, and central GIS coordinates for local bodies.

### UI Layout & Components
- **Full-Screen Interactive Map Canvas (Mapbox / Leaflet):**
  - Satellite, Street, and Topographic layer toggles.
  - GeoJSON Polygon Drawing Tools: Draw Polygon, Edit Vertices, Delete Polygon, Import GeoJSON File.
- **Geography Attribute Sidebar:**
  - District, Taluk, Block, Village, Ward Count.
  - Auto-calculated Area ($sq\ km$).
  - Center Latitude & Center Longitude inputs with auto-calculate center button.
  - Survey Numbers list tag editor (e.g., `["104/1A", "104/1B", "105/2"]`).

---

## 5. Branch Feature Config Matrix Screen (`/admin/branches/:id/features`)

### Purpose
Granular feature-gating dashboard allowing Super Admins to enable or disable 20+ specific application modules per branch.

### UI Layout & Components
- **Module Toggle Grid (Card Switchers):**
  - **Core Modules:** Grievance System, Generic Asset Management, SLA Engine, Dynamic Workflows.
  - **Specialized Municipality Modules:** Solid Waste Management, Road & Pothole Monitor, Drainage & Flood Control, Parks & Open Spaces, Public Health & Sanitation, Building Permits, Birth & Death Registration, Vehicle Fleet & Fuel Tracking, Encroachment Removal, Cemetery Management.
- **Switch Action:** Toggle switch instantly updates branch config; includes "Apply to all child branches" bulk toggle option.
