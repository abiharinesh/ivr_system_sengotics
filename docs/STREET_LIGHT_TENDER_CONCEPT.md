# GOVERNMENT OF TAMIL NADU • LOCAL ADMINISTRATION DEPARTMENT
## TENDER CONCEPT & SCOPE NOTE (FOR BIDDING VENDORS)

---

**Tender Subject:** Implementation of Smart Street Lighting Infrastructure & Grievance Management System with Weatherproof QR Asset Tagging, 24/7 Conversational AI Voice Calling, Citizen Apps, and Geo-Fenced Workforce Verification  
**Target Scope:** Municipal Street Light & Electric Pole Infrastructure  
**Issuing Authority:** Office of the Municipal Commissioner / Municipal Engineer  

---

### 1. THE PROBLEM STATEMENT (WHAT NEEDS TO BE SOLVED)
Urban and rural local bodies manage thousands of public street light poles spread across wide geographic wards, encountering critical operational bottlenecks:

1. **Unreported Dark Spots & Delayed Redressal:** Street lights often remain non-functional for days because civic bodies lack an automated mechanism to detect outages, relying solely on delayed manual complaints.
2. **Digital Exclusion of Citizens:** Existing web portals and complex apps require typing, English literacy, and multi-step logins, cutting off rural, elderly, and non-tech-savvy citizens from reporting faults.
3. **Fake Closures by Maintenance Contractors:** Field personnel often mark complaints "Resolved" without physically visiting the pole, leading to chronic dark spots, citizen complaints, and wasted public expenditure.
4. **Lack of Digitized Spatial Asset Inventory:** The administration lacks accurate GIS coordinates, pole IDs, fixture wattages, and phase balance records, hindering energy audits and preventative maintenance.

---

### 2. THE CONCEPT (HOW THE SOLUTION WORKS)
The proposed solution integrates **on-ground physical asset tagging**, **conversational artificial intelligence**, and **geo-verified field enforcement** into one closed-loop lifecycle:

```
[ CITIZEN REPORTS FAULT ]
   ├── Option A: Scans Pole QR Code (Instant Browser PWA — No App Download)
   └── Option B: Dials 24/7 AI Voice Helpline (Speaks naturally in Tamil/English)
              │
              ▼
[ POSTGIS SPATIAL AUTO-ROUTING ]
Auto-locates pole coordinates, creates ticket, and dispatches to Ward Electrician Mobile App
              │
              ▼
[ MANDATORY GEO-FENCED FIELD CLOSURE ]
   ├── Electrician app is locked unless standing within ≤ 50 meters of the pole
   └── Must capture live before/after camera photo + OCR scans the pole number tag
              │
              ▼
[ VERIFIED RESOLUTION & CITIZEN NOTIFICATION ]
Ticket closes on I3C Dashboard; citizen receives SMS with live resolution photo
```

---

### 3. CORE SOLUTION PILLARS

#### A. Weatherproof QR Code Asset Plates (Physical Tagging)
- Every pole is mounted with a durable, UV-resistant, weatherproof QR plate at $2.2\text{m}$ height displaying the Municipal Crest, Unique Pole Keypad ID, and crypto QR code.
- **How it works:** Any citizen pointing their phone camera at the QR code opens an instant reporting page in their mobile browser—**zero app download required**. The pole number, ward, and location are automatically pre-filled.

#### B. 24/7 Dual-Helpline Voice System (Conversational AI + Keypad IVR)
- **Primary Conversational AI Agent (`04440115043`):** Citizens speak naturally in colloquial Tamil, Tanglish, or English (e.g., *"பேருந்து நிறுத்தம் பக்கத்துல ஸ்ட்ரீட் லைட் எரியல"*). The AI extracts the landmark, creates the ticket, and dynamically speaks back live status updates on follow-up calls.
- **Secondary Keypad IVR (`04440115434`):** For basic 2G feature phones; caller dials the helpline and enters the 3-digit Pole ID on their keypad (e.g., `101#`) to instantly log the outage.

#### C. Citizen Engagement Suite (Mobile App & Instant PWA)
- **Instant Scan Web PWA:** Zero-install mobile browser portal for one-tap complaint submission.
- **Citizen Mobile App:** Interactive street light map, personal complaint history, automated SMS/WhatsApp alerts with live tracking links upon repair.

#### D. Field Electrician App with Mandatory Geo-Fencing
- **Mandatory $\le 50$-Meter Radius Lock:** Ticket closure is strictly blocked unless the electrician’s phone GPS is within 50 meters of the physical pole coordinates.
- **Live Camera Before/After Photo & OCR Proof:** Electrician must capture a live photo of the repaired light; built-in OCR scans the pole number tag to ensure zero fake closures.

---

### 4. SCOPE OF DELIVERABLES FOR BIDDING VENDORS

| Component | Vendor Deliverable & Responsibility |
| :--- | :--- |
| **1. GIS Asset Survey** | 100% door-to-door GPS mapping of all street light poles with wattage, phase, and landmark metadata. |
| **2. QR Plate Supply & Mounting** | Supply and installation of weatherproof, UV-coated plates using non-drilling industrial adhesive/straps. |
| **3. Telephony & AI Voice Engine** | Provision of 24/7 conversational Tamil/English AI voice helpline + DTMF lines with 99.5% uptime SLA. |
| **4. Software & Mobile Apps** | Cross-platform Flutter apps (Mobile + Web) for Admin Dashboard, Field Electrician queue, and Citizen reporting. |
| **5. Turnkey Operations** | Deputation of dedicated technical personnel at the Municipal Command Center for daily triage and SLA monitoring. |

---

```
Recommended for Approval:                            Approved for Tender Notification:


________________________________________             ________________________________________
Junior Engineer / Assistant Engineer                 Municipal Engineer / Commissioner
Local Administration Department                      Local Administration Department
```
