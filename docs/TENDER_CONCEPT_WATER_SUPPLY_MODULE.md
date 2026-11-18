# GOVERNMENT OF TAMIL NADU / LOCAL ADMINISTRATION DEPARTMENT
## TENDER CONCEPT & TECHNICAL SPECIFICATION DOCUMENT
### Volume II: Water Supply Infrastructure Management, IoT Telemetry, AI Voice Grievance Redressal, BOQ & Service Level Agreement (SLA)

---

**Tender Reference:** ROC / ENGG / WTR / 2026 / T-02  
**Project Title:** Implementation of Smart GIS Municipal Drinking Water Supply Network Monitoring System with IoT Reservoir & Flow Telemetry, Conversational AI Voice Grievance Helpline, Field Asset Capture, and Geo-Verified Plumber Operations  
**Issuing Authority:** Office of the Municipal Commissioner / Executive Officer / Block Development Officer  
**Jurisdiction:** [Name of Municipality / Town Panchayat / Panchayat Union, e.g., Mettupalayam Municipality, Coimbatore District]  
**Procurement Method:** Open Competitive E-Tendering (Two-Cover System: Technical Bid & Financial Bid) under Tamil Nadu Transparency in Tenders Act, 1998 & Rules, 2000  

---

## TABLE OF CONTENTS
1. [Tender Notice & Bid Summary](#1-tender-notice--bid-summary)
2. [Project Background, Need Analysis & Statutory Mandate](#2-project-background-need-analysis--statutory-mandate)
3. [Comprehensive Scope of Work (SOW)](#3-comprehensive-scope-of-work-sow)
   - 3.1 Pillar 1: GIS Water Network Vector Mapping (Pipelines, Valves & Distribution Mains)
   - 3.2 Pillar 2: Overhead Tank (OHT), Sump & Borewell Telemetry Monitoring
   - 3.3 Pillar 3: Sluice Valve Asset Management & Flow/Pressure Logging
   - 3.4 Pillar 4: 24/7 Dual-Helpline Conversational AI Voice Grievance Redressal
   - 3.5 Pillar 5: Field Water Asset Capture Mobile Application (New Connections & Public Taps)
   - 3.6 Pillar 6: Field Plumber Workforce Mobile Application with Geo-Fencing
   - 3.7 Pillar 7: Citizen Water Service & Supply Schedule Notification Portal
   - 3.8 Pillar 8: Executive Water Balance Audit & I3C Command Dashboard
4. [Technical Specifications & IoT Hardware Standards](#4-technical-specifications--iot-hardware-standards)
5. [Service Level Agreement (SLA) & Penalty Deduction Schedule](#5-service-level-agreement-sla--penalty-deduction-schedule)
6. [Bill of Quantities (BOQ) & Financial Schedule Template](#6-bill-of-quantities-boq--financial-schedule-template)
7. [Bidder Eligibility Criteria & Technical Evaluation Matrix](#7-bidder-eligibility-criteria--technical-evaluation-matrix)
8. [Project Implementation Phasing & Milestones](#8-project-implementation-phasing--milestones)
9. [Annexures & Declarations](#9-annexures--declarations)

---

## 1. TENDER NOTICE & BID SUMMARY

| S.No. | Parameter | Tender Specification Details |
| :--- | :--- | :--- |
| 1.1 | **Name of the Work** | Turnkey Implementation, Commissioning, and 3-Year Operational Maintenance of Smart GIS Drinking Water Distribution Network Monitoring System, IoT Telemetry, AI Voice Helpline, and Geo-Fenced Plumber Workforce Management. |
| 1.2 | **Tender Inviting Authority** | The Municipal Commissioner / Executive Officer, [Local Body Name]. |
| 1.3 | **Procurement Type** | E-Tender via Tamil Nadu Government E-Procurement Portal (`https://tntenders.gov.in`) and/or GeM Portal. |
| 1.4 | **Bidding System** | Two-Cover System: **Cover 1:** Pre-Qualification & Technical Bid; **Cover 2:** Financial Bid. |
| 1.5 | **Earnest Money Deposit (EMD)** | As specified in the official E-Tender Notice (Exemption applicable for registered Tamil Nadu Micro & Small Enterprises / MSME / NSIC upon submission of valid Udyam certificate). |
| 1.6 | **Contract Period** | **Implementation Phase:** 90 Days from Work Order; **Operations & Maintenance (O&M) Phase:** 36 Months (extendable by mutual agreement up to 60 months). |
| 1.7 | **Language of Bid & System** | English & Tamil (Bilingual citizen interfaces & voice prompts mandatory). |
| 1.8 | **Performance Security** | 5% of the total accepted contract value in the form of Bank Guarantee (BG) from a Nationalized/Scheduled Commercial Bank. |
| 1.9 | **Cloud Hosting Mandate** | MeitY-empaneled Tier-III Data Center located within sovereign territory of India. |

---

## 2. PROJECT BACKGROUND, NEED ANALYSIS & STATUTORY MANDATE

### 2.1 Statutory Context
Providing safe, reliable, and equitable potable drinking water is the foremost statutory obligation of Urban and Rural Local Bodies under the Tamil Nadu District Municipalities Act, 1920, and Tamil Nadu Panchayats Act, 1994. Bulk water is sourced through Tamil Nadu Water Supply and Drainage (TWAD) Board bulk supply schemes, local river intakes (e.g., Bhavani River in Mettupalayam), municipal headworks, filtration plants, and dedicated borewells.

### 2.2 Critical Operational Bottlenecks
Despite massive capital investments, local bodies face persistent operational challenges:
1. **High Non-Revenue Water (NRW) & Water Loss:** Significant portions of treated water are lost through undetected underground pipeline bursts, aging joint leakages, and unmonitored overflow from overhead tanks.
2. **Lack of Digitized GIS Pipeline Baseline:** Underground distribution networks (pipe diameter, material, valve locations, depth, year of laying) exist only in memory of retired line staff. When bursts occur, finding isolation valves takes hours, causing massive water wastage.
3. **Inequitable Distribution & Tail-End Starvation:** Manual, unmonitored sluice valve manipulation results in elevated or influential areas receiving excess water while tail-end rural/slum wards suffer severe scarcity.
4. **Delayed Contamination & Leak Grievance Response:** Citizens facing contaminated, muddy water or sudden pressure drops must visit offices in person; manual paper registers cause 48 to 72-hour delays.
5. **Absence of Proof in Pipeline Repair Closures:** Plumbers frequently claim ticket resolution without excavating or repairing the true underground leak, leading to repeated road collapses and water contamination.
6. **Unregistered Assets & Connections:** New public taps, commercial connections, and pipeline extensions laid during ward developments remain unmapped in civic asset records.

---

## 3. COMPREHENSIVE SCOPE OF WORK (SOW)

The selected technology agency shall execute the project on a complete turnkey basis covering software, hardware integration, GIS mapping, field survey, citizen telephony, and on-site command center operations:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 SMART WATER SUPPLY SYSTEM ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│  GIS VECTOR MAP  │       │  IOT TELEMETRY   │       │  AI WATER VOICE  │
│ (GeoJSON Conduits│       │ (OHT Levels %,   │       │     HELPLINE     │
│  Valves, Sumps)  │       │ Flow LPS, Bars)  │       │ (Leaks & Supply) │
└────────┬─────────┘       └────────┬─────────┘       └────────┬─────────┘
         │                          │                          │
         └──────────────────────────┼──────────────────────────┘
                                    ▼
         ┌─────────────────────────────────────────────────────┐
         │     POSTGIS WATER ENGINE & LEAK DETECTION           │
         │ (Pressure Drop Alerts, Water Balance & Auto-Assign) │
         └──────────────────────────┬──────────────────────────┘
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         ▼                                                     ▼
┌─────────────────────────────────┐           ┌─────────────────────────────────┐
│ FIELD PLUMBER & AGENT MOBILE APP│           │ I3C WATER COMMAND CONSOLE       │
│ • Mandatory ≤ 50m Geo-Fence     │           │ • Live Ward Water Balance       │
│ • Before/After Photo of Repair  │           │ • Sluice Valve State Control    │
│ • Tap/Pipeline Asset Capture    │           │ • Tanker Tracking & E-Tender    │
└─────────────────────────────────┘           └─────────────────────────────────┘
```

### 3.1 Pillar 1: GIS Water Network Vector Mapping (Pipelines, Valves & Mains)
1. **Sub-Meter Field Vector Survey:**
   - Deploy precision GNSS mapping crews to trace and map the entire drinking water distribution network across all wards.
   - Vectorize pipeline paths as high-precision **GeoJSON LineStrings** stored in the PostGIS spatial database.
   - Record pipeline attributes: Diameter in mm ($50\text{mm}$ to $600\text{mm}$), Material (HDPE, PVC, Ductile Iron / DI, Cast Iron / CI, Mild Steel), Depth of burial, Year of laying, Feeder reservoir linkage, and Operating pressure class.
2. **Valve & Junction Mapping:**
   - Map 100% of sluice valves, air release valves, scour/washout valves, non-return valves (NRV), and pressure-reducing valves (PRV) with exact WGS-84 coordinates.
   - Assign unique alphanumeric Valve IDs (e.g., `VLV-W12-04`) with Tamil street landmarks.

---

### 3.2 Pillar 2: Overhead Tank (OHT), Sump & Borewell Telemetry Monitoring
1. **Overhead Reservoirs (OHT) & Ground Storage (GLSR):**
   - Survey and digitize all storage assets with capacity in Litres, staging height, feeder pipeline links, and command ward areas.
   - Integration with IoT Ultrasonic / Hydrostatic level transmitters to provide continuous real-time water level data ($0\text{ to }100\%$).
   - High-level overflow alarms and critical low-level warnings transmitted to the Water Works Superintendent.
2. **Borewell & Pump House Monitoring:**
   - Real-time logging of motor operational status: **RUNNING / OFF / TRIPPED / POWER FAILURE**.
   - Cumulative daily run-hour tracking to prevent dry-running and detect motor burnouts before water supply disruption occurs.

---

### 3.3 Pillar 3: Sluice Valve Asset Management & Flow/Pressure Logging
1. **Digital Sluice Valve Management:**
   - Visual dashboard interface allowing Municipal Engineers and Valve Operators to view and toggle valve operational states: **OPEN / CLOSED / MAINTENANCE / THROTTLED**.
   - Audit trail tracking which operator operated which valve and at what exact timestamp, eliminating illegal valve manipulation and ensuring equitable water distribution.
2. **Water Flow & Line Pressure Logging:**
   - Dedicated time-series telemetry table (`water_flow_logs`) recording:
     - Flow Rate in Liters Per Second (LPS).
     - Hydrostatic Pressure in Bars.
     - Timestamp and sensor health telemetry.
3. **Automated Leak Anomaly Detection:**
   - Algorithmic detection of sudden pressure drops coupled with upstream flow spikes, immediately generating an automated **"Pipeline Burst Alert"** pinned to the nearest pipeline segment on the GIS map.

---

### 3.4 Pillar 4: 24/7 Dual-Helpline Conversational AI Voice Grievance Redressal
1. **Conversational AI Voice Helpline (Natural Spoken Tamil & English):**
   - 24/7 intelligent voice assistant capable of understanding citizen colloquial Tamil dialect descriptions of water problems (e.g., *"குழாய் உடைஞ்சு தண்ணி ரோட்ல வீணாகுது"*, *"மூணு நாளா தண்ணி வரல"*, *"சாக்கடை தண்ணி கலந்து வருது"*).
   - Intelligently extracts problem category:
     - **Pipeline Burst / Major Road Leakage**
     - **No Water Supply / Low Pressure**
     - **Dirty / Turbid / Contaminated Water (Health Hazard)**
     - **Public Fountain / Tap Broken**
     - **Valve Tampering / Illegal Motor Sucking**
     - **Emergency Drinking Water Tanker Request**
   - Automatically asks for landmark and ward name, creates an instant ticket in PostgreSQL, and dispatches an automated SMS alert.
2. **Live Spoken Status Query:**
   - When a citizen calls back, the voice agent checks the live database ticket status and speaks out the current progress in Tamil: *"தங்களின் குடிநீர் கசிவு புகார் எண் 1084 சரிசெய்ய களப் பணியாளர் அனுப்பப்பட்டுள்ளார்"*.
3. **Keypad DTMF Redressal Channel:**
   - Rapid menu for citizens using 2G feature phones to register water complaints and request tanker deliveries.

---

### 3.5 Pillar 5: Field Water Asset Capture Mobile Application (New Connections & Public Taps)
To ensure the municipal GIS map remains continuously updated when new works are executed:
1. **Field Staff Asset Capture Workflow:**
   - Dedicated mobile workflow for Water Works Agents and Meter Readers to register newly laid assets directly from the field:
     - **Household Tap Connections**
     - **Public Drinking Water Fountains (Public Taps)**
     - **New Pipeline Extensions & Feeder Lines**
   - Captures: Asset Type, Pipe Material, Diameter in mm, GPS Latitude, Longitude, Altitude, Device Precision, and Geotagged Photo.
2. **Officer Review & Approval Gate:**
   - Newly captured assets appear in an "Infrastructure Approval Queue" on the Municipal Engineer's dashboard.
   - The officer reviews the photo and GIS alignment, clicking **"Approve"** (which commits the asset to the live civic master database) or **"Reject"** with mandatory remarks.

---

### 3.6 Pillar 6: Field Plumber Workforce Mobile Application with Geo-Fencing
1. **Mandatory Geo-Fencing ($\le 50\text{m}$ Radius Enforcement):**
   - Prevents plumbers and maintenance contractors from falsely marking pipeline repairs or tank cleanings as completed without visiting the site.
   - Computes distance between plumber device GPS and the mapped pipeline leak coordinates; resolution button remains locked if distance $> 50$ meters.
2. **Live Before-and-After Photo Evidence:**
   - Plumber must upload two mandatory live photographs:
     1. **Before Photo:** Exposed damaged pipeline / leak / dirty sump before work starts.
     2. **After Photo:** Repaired pipe sleeve / replaced valve / sanitized tank.
   - Live camera capture with embedded EXIF hardware timestamp, latitude, and longitude.

---

### 3.7 Pillar 7: Citizen Water Service & Supply Schedule Notification Portal
1. **Water Supply Schedule Broadcasts:**
   - Citizens receive automated WhatsApp and SMS alerts regarding scheduled drinking water release timings for their specific ward (e.g., *"நாளை காலை 6:00 மணி முதல் 9:00 மணி வரை காமராஜர் நகர் பகுதிக்கு குடிநீர் விநியோகம் செய்யப்படும்"*).
   - Advance alerts for maintenance shutdowns, pipeline interconnection works, or power outages at water headworks.
2. **Public Tap QR Scan Portal:**
   - QR tags affixed to public water fountains allow citizens to scan with any smartphone to report non-supply, valve leaks, or broken taps instantly.

---

### 3.8 Pillar 8: Executive Water Balance Audit & I3C Command Dashboard
1. **Real-Time Municipal Water Audit Console:**
   - Compares total bulk water received from TWAD/River Headworks (in MLD - Million Liters per Day) against water stored in OHTs and supplied to wards.
   - Calculates ward-level Non-Revenue Water (NRW) loss percentage, pinpointing unaccounted distribution losses.
2. **Ward Equity Index:**
   - Tracks duration of water supply and frequency across all wards, ensuring marginalized or tail-end localities receive their fair statutory quota of drinking water.
3. **Automated Procurement & Tender Linkage:**
   - Bundles chronic pipeline leaks on specific road stretches into civil tender works for pipe replacement.
   - Compiles statutory Tamil procurement packs (RFQ, Comparative Statement, Work Order, Form 19 Expenditure Voucher, and Special Officer Proceedings).

---

## 4. TECHNICAL SPECIFICATIONS & IOT HARDWARE STANDARDS

### 4.1 Ultrasonic Water Level Transmitters (For Overhead Tanks & Sumps)
| Parameter | Technical Standard Specification |
| :--- | :--- |
| **Measurement Range** | $0.3\text{ m}$ to $10.0\text{ m}$ (Non-contact ultrasonic / hydrostatic level sensor). |
| **Accuracy** | $\pm 0.25\%$ of full scale range. |
| **Enclosure Rating** | IP68 Weatherproof & Submersible enclosure; UV-resistant housing. |
| **Output / Protocol** | 4-20 mA current loop / RS485 Modbus RTU / Cellular NB-IoT / 4G telemetry. |
| **Power Supply** | 12-24V DC with internal solar backup battery unit providing 72-hour autonomy. |

### 4.2 Pipeline Pressure Transmitters (For Distribution Mains)
| Parameter | Technical Standard Specification |
| :--- | :--- |
| **Pressure Range** | 0 to 10 Bar (or 0 to 16 Bar for high-head pumping mains). |
| **Burst Pressure** | Minimum $2 \times$ rated pressure. |
| **Wetted Parts** | Stainless Steel 316L diaphragm resistant to potable chlorinated water. |
| **Operating Temperature** | $-10^\circ\text{C}$ to $+65^\circ\text{C}$. |
| **Telemetry Interval** | Configurable (Default: Every 15 minutes; Emergency burst mode: Every 1 minute upon pressure drop $>25\%$). |

---

## 5. SERVICE LEVEL AGREEMENT (SLA) & PENALTY DEDUCTION SCHEDULE

The contractor and municipal water maintenance teams shall strictly adhere to the following Turnaround Times (TAT):

| Fault Classification | Scope & Incident Type | Permissible Resolution TAT | Penalty for Breach |
| :--- | :--- | :--- | :--- |
| **Tier-1: Critical Outbreak / Burst** | Major distribution main burst, contaminated sewage ingress, hospital water cutoff. | **Within 6 Hours** from complaint | ₹1,000 per hour of delay. |
| **Tier-2: High Priority** | Sub-main distribution leak, pump motor trip affecting entire ward, overhead tank dry. | **Within 12 Hours** from complaint | ₹500 per ward per day. |
| **Tier-3: Standard Leak / Tap** | Public fountain tap broken, valve packing leak, single household connection leak. | **Within 24 Hours** from complaint | ₹150 per day of delay. |
| **Tier-4: Tanker Water Request** | Verified dry ward emergency tanker delivery request. | **Within 4 Hours** of order | ₹300 per delayed tanker trip. |
| **Telemetry Availability** | Tank level & pressure data streaming uptime ($\ge 99.0\%$). | Continuous 24x7 | ₹1,000 per offline day per sensor. |

---

## 6. BILL OF QUANTITIES (BOQ) & FINANCIAL SCHEDULE TEMPLATE

*Bidders shall quote rates strictly in the electronic financial bid cover (Cover 2):*

| Item No. | Description of Item / Scope Component | Unit | Est. Quantity | Quoted Unit Rate (₹) (Excl. GST) | Total Amount (₹) (Excl. GST) |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **2.01** | **GIS Pipeline Network Survey & Vectorization:** Door-to-door ground GNSS mapping of underground drinking water distribution lines, GeoJSON LineStrings, pipe diameter, material, depth, and valve points. | Per Km | [e.g., 120 Km] | *To be quoted* | *Calculated* |
| **2.02** | **Reservoir & Borewell Digitization:** GIS mapping, capacity modeling, and attribute creation for Overhead Tanks (OHT), GLSRs, and municipal borewells. | Per Asset | [e.g., 50 Tanks] | *To be quoted* | *Calculated* |
| **2.03** | **IoT Ultrasonic Level Telemetry Units:** Supply, installation, and commissioning of IP68 solar-backed ultrasonic level sensors on overhead tanks with 4G/NB-IoT telemetry. | Per Unit | [e.g., 25 Units] | *To be quoted* | *Calculated* |
| **2.04** | **Pipeline Pressure Transmitters:** Supply, tapping, and commissioning of SS316L pressure transmitters on main distribution conduits with burst-detection telemetry. | Per Unit | [e.g., 20 Units] | *To be quoted* | *Calculated* |
| **2.05** | **Cloud Software & Ooraatchi Water Engine:** Setup of PostGIS spatial engine, pipeline grid viewer, valve toggle management, leak detection algorithm, and tender document compiler. | Lump Sum | 1 Unit | *To be quoted* | *Calculated* |
| **2.06** | **24/7 AI Voice Water Grievance Helpline:** Conversational Tamil/English voice agent, DTMF IVR, dynamic status query, Exotel SIP trunks, and SMS/WhatsApp broadcast channel for 36 months. | Per Month | 36 Months | *To be quoted* | *Calculated* |
| **2.07** | **Field Plumber & Asset Capture Mobile Applications:** Deployment of Android mobile apps with $\le 50\text{m}$ geo-fencing, before/after photo capture, and approval queues. | Lump Sum | 1 Unit | *To be quoted* | *Calculated* |
| **2.08** | **Cloud Hosting & Cyber Security:** MeitY-empaneled Tier-III cloud hosting, automated daily database backups, SSL TLS 1.3 certificates, and data sovereignty compliance. | Per Year | 3 Years | *To be quoted* | *Calculated* |
| **2.09** | **Turnkey Operations & Water Desk Support:** Stationing of dedicated technical operator at Municipal Command Center for daily water grievance dispatch, valve tracking, and audit reports. | Per Month | 36 Months | *To be quoted* | *Calculated* |
| **TOTAL** | **Comprehensive Turnkey Contract Value (Excluding Applicable GST)** | — | — | — | **₹ [TOTAL]** |

---

## 7. BIDDER ELIGIBILITY CRITERIA & TECHNICAL EVALUATION MATRIX

### 7.1 Minimum Pre-Qualification (PQ) Criteria
1. **Legal Entity:** Registered Indian Company / LLP / MSME with valid GSTIN and PAN.
2. **Financial Standing:** Average annual financial turnover during the last 3 financial years (FY 2022-23, 2023-24, 2024-25) not less than ₹60 Lakhs (Relaxation applicable for registered Tamil Nadu MSME / DPIIT units).
3. **Domain Experience:** Prior successful execution of at least one project involving Water Supply GIS Mapping, Smart Water Telemetry/SCADA, Municipal Utility ERP, or Citizen Helpline software.
4. **GeM Registration:** Active registered seller on Government e-Marketplace (GeM).
5. **Non-Blacklisting:** Self-attested notarized affidavit certifying no debarment by any government department.

### 7.2 Technical Scoring Matrix (100 Marks Total)
*Qualifying mark: $\ge 75\text{ marks}$ to proceed to financial bid opening:*

| Evaluation Parameter | Criteria & Mark Breakdown | Max Marks |
| :--- | :--- | :---: |
| **Financial Turnover & Company Strength** | • Turnover $>$ ₹1.5 Crore: 15 Marks<br>• Turnover ₹60 Lakhs to ₹1.5 Crore: 10 Marks<br>• Tamil Nadu Registered MSME: 5 Marks bonus | **20 Marks** |
| **Experience in Water GIS & Civic Tech** | • $\ge 3$ Urban Utility / GIS Projects: 20 Marks<br>• 1 to 2 Utility / GIS Projects: 10 Marks | **20 Marks** |
| **Live Product Demonstration** | Technical demo: Real-time GIS pipeline vector grid, tank telemetry simulation, conversational AI Tamil water leak call, and plumber mobile geo-fencing test. | **30 Marks** |
| **IoT Sensor Architecture & Telemetry Plan** | Sensor durability, battery autonomy, cellular transmission reliability, and fail-safe burst detection. | **15 Marks** |
| **On-Site Operational Methodology** | Command center deployment plan, leak triage workflow, and plumber training protocol. | **15 Marks** |
| **TOTAL TECHNICAL SCORE** | — | **100 Marks** |

---

## 8. PROJECT IMPLEMENTATION PHASING & MILESTONES

| Milestone | Activity Scope | Delivery Window | Payment (% of Capex) |
| :---: | :--- | :---: | :---: |
| **T0** | Letter of Acceptance (LoA) & Contract Signing | Day 0 | — |
| **M1** | Inception Report, Baseline Water Network Architecture, Cloud Provisioning & Telephony Setup | Day 20 | 15% |
| **M2** | Completion of 100% GIS Field Vector Survey of Underground Water Distribution Network | Day 50 | 25% |
| **M3** | Supply, Installation & Calibration of OHT Ultrasonic Sensors & Pressure Transmitters | Day 70 | 25% |
| **M4** | Operational Go-Live: AI Voice Grievance Line, Plumber App, Citizen Portal & Water Command Center | Day 90 | 25% |
| **M5** | User Acceptance Testing (UAT) Sign-off by Municipal Engineer & Handover | Day 105 | 10% |
| **O&M** | Quarterly Operations, Sensor Maintenance, Telephony & On-Site Command Center Support | Quarterly | Equal quarterly payments |

---

## 9. ANNEXURES & DECLARATIONS

### Annexure I: Live System Evaluation Credentials (For Tender Committee Verification)
- **Live Platform Portal:** `https://ivr-frontend-system-sengotics.vercel.app/`
- **Primary AI Voice Helpline:** `04440115043` (Test natural spoken Tamil water grievance registration)
- **Keypad DTMF Helpline:** `04440115434`
- **Evaluation Admin Login:** `admin@sengotics.com` | **Password:** `Admin@1234`
- **Field Plumber Login:** `electrician@sengotics.com` (Plumber queue) | **Password:** `Admin@1234`

### Annexure II: Officer Certification & Approval Block
*(To be signed by the competent municipal authority upon adoption into tender notification)*

```
Recommended for Approval:                            Approved & Sanctioned:


___________________________________                 ___________________________________
Assistant Engineer / Municipal Engineer             Municipal Commissioner / Executive Officer
Water Supply & Drainage Wing                        [Name of Local Body]
[Name of Local Body]                                Seal & Date:
Seal & Date:
```
