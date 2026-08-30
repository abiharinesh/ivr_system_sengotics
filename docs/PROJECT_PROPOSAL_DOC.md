# Project Proposal Document — Ooraatchi Local Body e-Governance Platform

**Submitted by:** Sengotics  
**Project Name:** Ooraatchi — Smart GIS Municipal Governance, Conversational AI Voice Agent & Dual Helpline Infrastructure  
**Live Production Portal:** [https://ivr-frontend-system-sengotics.vercel.app/](https://ivr-frontend-system-sengotics.vercel.app/)  
**Primary AI Voice Agent Helpline:** `04440115043`  
**Secondary Keypad IVR Helpline:** `04440115434`  

---

## 1. Executive Summary

**Ooraatchi by Sengotics** is a next-generation, multi-tenant AI governance platform engineered specifically for Tamil Nadu Municipal Corporations, Municipalities, Town Panchayats, and Village Panchayats.

The platform eliminates the digital divide through a **Dual-Helpline Voice Infrastructure**:
1. **Primary Helpline (04440115043) — Conversational AI Voice Agent:** Powered by Exotel and state-of-the-art conversational LLMs, the voice agent speaks realistically in natural Tamil, Tanglish, and English. It intelligently extracts grievance parameters, dynamically queries existing complaint statuses from the database, gives instant spoken updates to citizens, and answers municipal inquiries without robotic menu trees.
2. **Secondary Helpline (04440115434) — Fast Keypad DTMF IVR:** Provides rapid, keypad-driven grievance logging (e.g. entering pole keypad ID `101`, `102`, `103`) for users preferring traditional numeric dialpad shortcuts.

These voice channels work seamlessly alongside on-ground GIS asset mapping, geo-fenced mobile apps for field workforce verification, real-time I3C command dashboards, revenue engines, and procurement modules.

---

## 2. Live Interactive Demo & Trial System Access

Evaluators and committee members can test the system live using the credentials, dual helpline numbers, and QR code below:

### 🌐 Live Web Portal
* **URL:** `https://ivr-frontend-system-sengotics.vercel.app/`
* **Supported Browsers:** Chrome, Edge, Safari, Firefox (Desktop & Mobile)

---

### 📞 Dual Helpline System & Live Demo Numbers

| Helpline Type | Phone Number | Technology & Capability | How to Test |
| :--- | :--- | :--- | :--- |
| **Primary Helpline** *(Conversational AI Voice Agent)* | `04440115043` | **Real-Time Conversational AI Voice Agent:** Realistic natural speech in Tamil/Tanglish/English. Checks live complaint status (`fetch_existing_complaints`), registers new grievances, handles landmarks, and answers municipal queries conversationally. | Call and speak naturally: *"பஸ் ஸ்டாண்ட் பக்கத்துல ஸ்ட்ரீட் லைட் எரியல"* or ask *"என்னோட புகார் நிலை என்ன?"* to hear live database queries spoken back. |
| **Secondary Helpline** *(Keypad DTMF IVR)* | `04440115434` | **Automated Keypad IVR:** Traditional DTMF tone menu with rapid numeric pole ID entry. | Call and enter sample Keypad ID (e.g., `101`, `102`, `103`) on your phone dialpad. |

---

### 🔑 Administrator Portal Credentials

Log in to the live portal at `https://ivr-frontend-system-sengotics.vercel.app/` using the following demo accounts:

| Access Role | Email Address | Password | Permissions & Scope |
| :--- | :--- | :--- | :--- |
| **Super Admin** | `superadmin@sengotics.com` | `Admin@1234` | Platform-wide control, tenant onboarding, global RBAC matrix, district analytics |
| **Panchayat Admin** | `admin@sengotics.com` | `Admin@1234` | Branch administration, asset mapping, tender issuance, field staff assignment |
| **Field Electrician** | `electrician@sengotics.com` | `Admin@1234` | Mobile field queue, GPS geo-fenced repair photo capture & closure |

---

## 3. Sample Pole Test Registry Table

| Attribute | Test Pole 01 (Commercial) | Test Pole 02 (Residential) | Test Pole 03 (Rural) |
| :--- | :--- | :--- | :--- |
| **Pole Number** | `PL-MTP-001` | `PL-MTP-002` | `PL-MTP-003` |
| **IVR Keypad ID** *(Secondary 04440115434)* | **101** | **102** | **103** |
| **Spoken Landmark** *(Primary Voice Agent 04440115043)* | Near Bus Stop, Main Road Junction / *பேருந்து நிறுத்தம் அருகில்* | Corner of Pillaiyar Kovil Street / *பிள்ளையார் கோவில் தெரு முனை* | Opposite Primary Health Centre / *ஆரம்ப சுகாதார நிலையம் எதிரில்* |
| **Panchayat / Org Unit** | Mettupalayam Ward 12 | Dhayanur Ward 4 | Karamadai Union Zone 2 |
| **Coordinates (Lat, Long)** | 11.3005° N, 76.9467° E | 11.2890° N, 76.9312° E | 11.2754° N, 76.9601° E |
| **Public Report Token** | `TKN-9821-DEMO` | `TKN-4512-DEMO` | `TKN-7834-DEMO` |

---

## 4. QR Code Asset Maintenance Demo Card

Scan the QR code with any smartphone camera to open the instant citizen reporting portal:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│               🏛️  METTUPALAYAM MUNICIPALITY              │
│ ─────────────────────────────────────────────────────── │
│                                                         │
│          Scan to report street light fault              │
│            பழுதுபார்க்க ஸ்கேன் செய்யவும்              │
│                                                         │
│                 ┌─────────────────┐                     │
│                 │  [  QR CODE  ]  │                     │
│                 │   SCAN ME TO    │                     │
│                 │  REPORT FAULT   │                     │
│                 └─────────────────┘                     │
│                                                         │
│               POLE NUMBER: TY-001                       │
│                                                         │
│   AI Voice Agent: 04440115043  |  Keypad IVR: 04440115434│
│   Portal: https://ivr-frontend-system-sengotics.vercel.app/│
└─────────────────────────────────────────────────────────┘
```

---

## 5. Core Platform Modules

### Module 1: Real-Time Conversational AI Voice Agent & Dual Helpline Engine
* **Conversational AI Voice Agent (Primary 04440115043):** Full two-way natural language dialogue in Tamil, Tanglish, and English powered by Exotel integration. Realistic human-like speech synthesis.
* **Real-Time Complaint Lookup & Intelligence:** Automatically fetches existing complaint statuses from PostgreSQL when callers check on ticket progress; provides instant spoken resolution updates.
* **Dynamic Grievance Registration:** Extracts problem category (streetlight, water leak, garbage, drain clog), landmark, and severity without requiring rigid DTMF button presses.
* **Keypad DTMF IVR (Secondary 04440115434):** Dedicated numerical keypad entry channel for instant pole ID logging (101/102/103) and fallback.
* **Automatic Spatial Auto-Routing:** Auto-maps issues via PostGIS geometry: Asset → Ward → Responsible Department → Field Crew Mobile App.
* **Automated SMS & WhatsApp Dispatch:** Immediate SMS confirmation with live tracking link dispatched to the citizen upon ticket creation or status update.

### Module 2: QR-Enabled Asset Management & GIS Mapping
* Unique digital identities for electric poles, water pipelines, borewells, sumps, and smart bins.
* Physical weatherproof QR stickers with instant scan-to-report interface (no app download required).

### Module 3: Field Workforce & Geo-Fenced Resolution Proof
* Role-specific mobile applications for Electricians, Plumbers, and Sanitary Inspectors.
* **Geo-Fenced Verification:** Enforces photo evidence capture strictly within a 50m radius of the asset, preventing remote or fraudulent ticket closure.

### Module 4: I3C Command Center & Executive Decision Analytics
* Live KPI command dashboard for Commissioner and Municipal Engineers.
* Real-time SLA countdown timers, heatmap cluster analysis, and contractor performance ratings.

### Module 5: Municipal Revenue, Procurement & Digital M-Book
* Property tax plinth-area engine, market stall daily collection tokens, and facility bookings.
* End-to-end e-tendering, contractor grading, digital measurement book (M-Book), and dynamic canvas PDF generator.

---

## 6. Corporate & Contact Details

* **Company:** Sengotics  
* **GSTIN:** 33DKDPA5555E1ZL  
* **MSME Udyam Reg No:** UDYAM-TN-03-0308455  
* **GeM Seller ID:** N78K260014298113  
* **Corporate Office:** 4/360, Anna Nagar, Dhayanur, Karamadai Tholampalayam Road, Near Gram Panchayat Office, Kemmarampalayam, Kalampalayam, Mettupalayam, Coimbatore, Tamil Nadu – 641113  
* **Contact Email:** contact@sengotics.com  
* **Contact Phone:** +91 9597769501  
* **Website:** [www.sengotics.com](https://www.sengotics.com)  
* **Live System Demo URL:** [https://ivr-frontend-system-sengotics.vercel.app/](https://ivr-frontend-system-sengotics.vercel.app/)  
  
