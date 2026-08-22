# Project Proposal Document — Ooraatchi Local Body e-Governance Platform

**Submitted by:** Sengotics  
**Project Name:** Ooraatchi — Multi-Tenant IVR Voice Helpline, GIS Asset Tracking & Urban Governance System  
**Live Production Portal:** [https://ivr-frontend-system-sengotics.vercel.app/](https://ivr-frontend-system-sengotics.vercel.app/)  

---

## 1. Executive Summary

**Ooraatchi by Sengotics** is an AI-powered, multi-tenant e-governance platform designed specifically for Tamil Nadu Municipal Corporations, Municipalities, Town Panchayats, and Village Panchayats.

The platform bridges the digital divide by offering a 100% voice-based citizen grievance helpline alongside modern web & mobile portals for administration, field workforce management, tax/revenue, regulatory services, and public works procurement.

---

## 2. Live Interactive Demo & Trial System Access

Evaluators and committee members can test the system live using the credentials, IVR numbers, and QR code below:

### 🌐 Live Web Portal
* **URL:** `https://ivr-frontend-system-sengotics.vercel.app/`
* **Supported Browsers:** Chrome, Edge, Safari, Firefox (Desktop & Mobile)

---

### 📞 Live IVR Helpline & Demo Trial Numbers

Dial either of the following numbers from any mobile/landline phone to experience automated multi-lingual (Tamil / English) voice complaint logging:

| Helpline Type | Phone Number | Description |
| :--- | :--- | :--- |
| **Primary IVR Helpline** | `04440115043` | Main AI-assisted voice grievance registration helpline |
| **Demo Trial Helpline** | `04440115434` | Dedicated trial number for project proposal demonstration |

---

### 🔑 Administrator Portal Credentials

Log in to the live portal at `https://ivr-frontend-system-sengotics.vercel.app/` using the following demo accounts:

| Access Role | Email Address | Password | Permissions & Scope |
| :--- | :--- | :--- | :--- |
| **Super Admin** | `superadmin@sengotics.com` | `Admin@1234` | Platform-wide control, tenant onboarding, global RBAC matrix, district analytics |
| **Panchayat Admin** | `admin@sengotics.com` | `Admin@1234` | Branch administration, asset mapping, tender issuance, field staff assignment |

---

## 3. QR Code Asset Maintenance Demo Card

Below is the printable QR Code card template used across local body assets (electric poles, water tanks, public taps, waste bins). Scan the QR code with any smartphone camera to open the instant citizen reporting portal.

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│               🏛️  OORAATCHI LOCAL BODY                   │
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
│       Helpline: 04440115043 / 04440115434               │
│       Portal: https://ivr-frontend-system-sengotics.vercel.app/  │
└─────────────────────────────────────────────────────────┘
```

---

## 4. System Architecture & Key Modules

### Module 1: AI Voice IVR Helpline
* **Automated Voice Intake:** Citizens dial `04440115043` or `04440115434` to report issues (streetlights, water pipeline leaks, sanitation) in Tamil or English.
* **Speech Recognition & Speech-to-Text:** Converts voice recordings to structured text using Whisper & Google STT AI models.
* **Instant Ticket Generation:** Automatically extracts asset number, problem description, location, and assigns a unique ticket tracking ID.

### Module 2: GIS Asset Mapping & Pole Tagging
* Every physical asset (e.g., Electric Pole `TY-001`, Water Tank `WT-04`) is mapped with latitude & longitude.
* Interactive map view for administrators showing real-time fault clusters and active maintenance locations.

### Module 3: Field Workforce & Geo-Fenced Resolution
* Assigned electricians and maintenance crews receive mobile notifications.
* **Geo-Fenced Verification:** Field staff must upload completion proof photos within the pre-set GPS geo-fence radius (e.g. 50m) of the target asset.
* Prevents fake or remote ticket resolution.

### Module 4: Tenders & Public Works Procurement
* Create and publish works tenders (road repair, street light installation, pipeline replacement).
* Vendor portal for submitting sealed bids, evaluating tenders, and generating work orders.

### Module 5: Executive MIS Analytics & Role Console
* Interactive heatmap, SLA compliance rates, resolution time breakdown.
* Granular 4-tier Role-Based Access Control (RBAC) linking screen access, organization unit, and user accounts.

---

## 5. Security & Government Compliance

* **Data Sovereignty:** All database records and logs hosted within India-compliant cloud data centers.
* **Audit Trail:** Immutable activity logs capturing every user login, role change, ticket status update, and tender action.
* **Encryption:** SSL/TLS in transit, AES-256 for sensitive stored payload data.

---

## 6. Corporate & Contact Details

* **OEM / Vendor:** Sengotics  
* **GSTIN:** 33DKDPA5555E1ZL  
* **MSME Udyam Reg No:** UDYAM-TN-03-0308455  
* **Corporate Office:** 4/360, Anna Nagar, Dhayanur, Karamadai Tholampalayam Road, Near Gram Panchayat Office, Kemmarampalayam, Kalampalayam, Coimbatore, Tamil Nadu – 641113  
* **Contact Email:** contact@sengotics.com  
* **Corporate Website:** [www.sengotics.com](https://www.sengotics.com)  
* **Live System Demo URL:** [https://ivr-frontend-system-sengotics.vercel.app/](https://ivr-frontend-system-sengotics.vercel.app/)  
