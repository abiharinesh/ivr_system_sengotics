# Screen Plan 05: Generic Asset Management

> **Backend Phase:** Phase 2 (Generic Asset Management) & Phase 0P (GIS Engine)  
> **Target Audience:** Municipal Engineers, Assistant Engineers, Field Inspectors, Asset Officers

---

## 1. Asset Inventory & Map GIS View Screen (`/assets`)

### Purpose
Provides dual-mode spatial map and tabular management of all local government physical assets (street lights, water pumps, parks, dumpsters, public buildings).

### UI Layout & Components
- **Top Control & Filter Bar:**
  - View Toggle Buttons: **GIS Map View** vs. **Data Table View**.
  - Asset Type Selector (Refers to `MasterValue` asset codes: `electric_pole`, `water_pump`, `park`, `dumpster`).
  - Operational Status Filter (`Operational`, `Maintenance Needed`, `Decommissioned`).
  - Condition Rating Filter (1 to 5 Star Rating).
- **GIS Map View Mode:**
  - Mapbox / Leaflet map rendered with PostGIS spatial clusters.
  - Custom Color-Coded Pins by asset type & status.
  - Pin Click Action: Opens Slide-Over Asset Sheet displaying Asset Photo, Code (`SL-MDU-Z3-042`), Location Address, Condition Rating, and "Inspect Now" / "Report Fault" action buttons.
- **Data Table View Mode:**
  - Columns: Asset Code, Asset Name, Type, Branch/Ward, Installation Date, Condition Rating, Operational Status, Actions.

---

## 2. Dynamic Asset Registration Screen (`/assets/new`)

### Purpose
Registers new assets with automatic dynamic form generation based on the selected asset type.

### UI Layout & Components
- **Step 1: Asset Type & General Information:**
  - Asset Category & Sub-type dropdowns (fetches `MasterCategory` & `MasterValue`).
  - Asset Code (Auto-generated or Manual), Asset Name.
- **Step 2: Dynamic Category Fields Component:**
  - Dynamically renders custom fields defined in `Asset.custom_data` based on type (e.g., Wattage & Pole Height for Streetlights; Pipe Diameter & Pressure Rating for Water Mains).
- **Step 3: Geolocation Capture:**
  - "Fetch Current GPS Location" button displaying latitude, longitude, and accuracy radius ($meters$).
  - Interactive map pin placer for fine-tuning location.
- **Step 4: Image & Warranty Upload:**
  - Multi-photo uploader with automatic EXIF metadata extraction.
  - Warranty provider name, start date, expiration date, terms, and warranty certificate document uploader.

---

## 3. Asset Details & Full History Screen (`/assets/:id`)

### Purpose
Comprehensive 360-degree view of a single asset including photos, maintenance logs, inspection history, and warranty info.

### UI Layout & Components
- **Asset Header Card:** Asset Code, Name, Type Chip, Operational Status Badge, Condition Rating Stars, Installed Date.
- **Tabbed Asset Modules:**
  - **Tab 1: GIS Map & Specifications:** Embedded map pin, address, custom parameters JSON key-value grid.
  - **Tab 2: Image Gallery (`AssetImage`):** Image grid with type tags (`installation`, `current`, `damage`, `repair`), resolution metadata, GPS coordinates, captured device model, EXIF data drawer.
  - **Tab 3: Maintenance Logs (`AssetMaintenanceLog`):** Timeline of repairs, cost summary, contractor name, parts replaced, and side-by-side Before/After repair photos.
  - **Tab 4: Inspection Reports (`AssetInspection`):** Inspection scores, inspector name, GPS lock status, checklist results, inspector signature image.
  - **Tab 5: Warranty Info (`AssetWarranty`):** Active warranty status, provider contact info, expiry countdown, document downloader.

---

## 4. Asset Inspection Execution Screen (`/assets/:id/inspect`)

### Purpose
Mobile-optimized inspection interface for field officers conducting physical asset audits.

### UI Layout & Components
- **Geofence Verification Banner:**
  - Live distance calculator comparing current inspector GPS with target asset coordinates.
  - Prevents inspection submission if distance exceeds maximum allowed threshold ($e.g., > 50\text{ meters}$).
- **Checklist Form Component:**
  - Dynamic checklist items (Pass/Fail/Not Applicable toggles).
  - Condition Rating Slider (1 to 5 Stars).
  - Mandatory Photo Uploader for any failed checklist item.
- **Remarks & Inspector Sign-Off:**
  - Text remarks box.
  - In-App Touch Signature Pad for inspector signature.

---

## 5. Asset Maintenance Log Entry Screen (`/assets/:id/maintenance/new`)

### Purpose
Records corrective or scheduled maintenance actions, parts replaced, and costs incurred.

### UI Layout & Components
- **Maintenance Type Dropdown:** `preventive`, `corrective`, `emergency`.
- **Contractor & Work Order Selector:** Optional link to external contractor or active Work Order ID.
- **Cost & Parts Replaced:** Total repair cost ($INR$), Parts Replaced input tag list.
- **Before & After Photo Uploader:** Dual photo upload boxes forcing upload of "Before Repair" damage photo and "After Repair" fixed photo.
