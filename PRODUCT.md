# Product Profile: Ooraatchi by Sengotics

> **Product Tagline:** Next-Generation Web GIS, Conversational AI Voice Helplines & Integrated E-Governance Platform for Smart Local Bodies  
> **GeM Category:** WEB GIS Based Project Management Software  
> **Brand / OEM:** Sengotics (Trusted Digital Future)  
> **Live Portal:** [https://ivr-frontend-system-sengotics.vercel.app/](https://ivr-frontend-system-sengotics.vercel.app/)  
> **Primary Conversational AI Helpline:** `04440115043`  
> **Secondary Keypad DTMF Helpline:** `04440115434`  
> **Target Audience:** Municipal Corporations, Municipalities, Town Panchayats, Village Panchayats, Urban Local Bodies (ULBs), and Public Utility Contractors across India.

---

## 1. Executive Summary & Product Overview

**Ooraatchi** (ஊராட்சி) is an all-in-one, multi-tenant e-governance and infrastructure management platform developed by **Sengotics**. Engineered specifically for local governing bodies, Ooraatchi eliminates administrative fragmentation by unifying **Web GIS spatial intelligence**, **dual-helpline voice telephony (Tamil & English Conversational AI + DTMF)**, **IoT utility telemetry**, **e-tendering & procurement**, and **anti-fraud geo-fenced field workforce tracking** into a single, cohesive sovereign cloud platform.

Unlike conventional software providers who deliver remote, disconnected tools, Sengotics pairs the Ooraatchi platform with a **Turnkey Operations Model (Product + Full On-Site Staffing)**, embedding trained personnel directly inside the municipality's Integrated Command & Control Center (I3C) to manage day-to-day triage, asset monitoring, and field escalation.

---

## 2. Core Value Proposition: The Sengotics Difference

| Dimension | Traditional Municipality Operations | With Ooraatchi by Sengotics |
| :--- | :--- | :--- |
| **Citizen Redressal** | Citizens must visit offices in person or navigate confusing mobile apps requiring smartphone literacy. | **Dual-Helpline Inclusivity:** Anyone can call from any phone. Primary line uses natural conversational Tamil/English AI; secondary line offers rapid keypad DTMF shortcuts. |
| **Asset Infrastructure** | Static spreadsheets or paper registers; unknown asset health, unmapped streetlights and pipelines. | **Interactive Web GIS (PostGIS):** Real-time spatial mapping with weatherproof QR tags on every pole, valve, and utility asset. |
| **Field Accountability** | Field contractors report ticket resolution remotely with no verifiable proof of presence. | **Anti-Fraud Geo-Fencing:** Tickets can only be closed within ≤ 50m GPS radius of the physical asset, backed by AI-OCR photo verification. |
| **Procurement & Tenders** | Fragmented manual tenders, offline quotation comparisons, delayed work order issuances. | **End-to-End E-Tendering Engine:** GFR 2017 compliant tender lifecycle, automated L1/L2 comparative statements, digital M-Book, and canvas PDF designer. |
| **Departmental Silos** | Disconnected software for building permits, trade licences, sanitation, and birth/death records. | **Unified Local Body Modules:** Integrated statutory workflows, automated fee calculation, SLA countdowns, and cross-departmental dashboards. |
| **Deployment & Support** | Distant vendors offering ticket-based email support and leaving software idle. | **Turnkey On-Site I3C Staffing:** Dedicated Sengotics personnel stationed inside the municipal command center managing live daily operations. |

---

## 3. Key Product Pillars (For Product Listing & Highlights)

### 🎙️ Pillar 1: Dual-Helpline Voice Redressal (100% Inclusive)
- **Primary AI Voice Agent (`04440115043`):** Two-way conversational voice bot powered by Exotel and state-of-the-art LLMs. Speaks natural, polite Tamil, Tanglish, and English. Automatically extracts grievance parameters (issue type, street, landmark) and performs live database lookups to answer citizen status inquiries conversationally.
- **Secondary Keypad DTMF IVR (`04440115434`):** Instant dialpad numeric entry for rapid logging (e.g. entering pole keypad ID `101`, `102`, `103`) optimized for basic feature phones.

### 🗺️ Pillar 2: Interactive Web GIS & Physical QR Asset Mapping
- High-precision PostgreSQL/PostGIS spatial mapping of street light poles, water pipelines, valves, borewells, sumps, and municipal buildings.
- Weatherproof physical QR code tags affixed to street-level assets for instant scan-to-report access by citizens without installing any mobile application.

### 📍 Pillar 3: Geo-Fenced Field Proof & AI-OCR Verification
- Dedicated mobile workflows for Electricians, Plumbers, and Sanitary Inspectors.
- **Strict 50-meter GPS Geo-Fence:** Field workers cannot mark tickets resolved unless their physical device is located within 50 meters of the asset.
- **Google Vision AI-OCR:** Automated image analysis verifying pole markings and work authenticity to prevent bogus ticket closures.

### 📋 Pillar 4: E-Tendering, Procurement & Digital M-Book
- End-to-end procurement compliant with **General Financial Rules (GFR) 2017** and **GeM standards**.
- Dynamic milestone tracking (anchor dates + offset days), invite-only sealed bidding, automated comparative statements, digital Measurement Book (M-Book), and Fabric.js visual canvas PDF designer.

### 🏛️ Pillar 5: Statutory Municipal Governance Modules
- Out-of-the-box modules for **Building Permits** (with NOC gates), **Vital Events (Birth & Death Registration under RBD Act 1969)**, **Solid Waste & Dynamic Bin Tracking**, **Trade Licences**, and **Market Stall (*Santhai*) Revenue Tokens**.

### 🏢 Pillar 6: Turnkey Integrated Command & Control Center (I3C)
- Executive dashboards with live SLA countdowns, GIS heatmap cluster analysis, contractor performance ratings, and statutory ZIP export engines.
- Full turnkey on-site staffing provided by Sengotics to run the municipal helpline and operations center.

---

## 4. Comprehensive Module Breakdown

### Module 1: Conversational AI Voice Helpline & Smart IVR
* **Tamil & English Natural Dialogue:** Understands regional dialects (e.g., Kongu Tamil), mixed Tanglish, and spoken landmarks without rigid menu trees.
* **Dynamic Database Intelligence:** Queries real-time complaint records (`/api/ivr/bot/fetch-complaints`) to speak live ticket statuses back to citizens.
* **Spatial Landmark Matching:** Correlates spoken landmarks ("near Mariamman temple", "opposite bus stand") to exact physical infrastructure records in the GIS database.
* **Automated Citizen Dispatches:** Instant SMS notifications with live web tracking links upon ticket registration and resolution.

### Module 2: Advanced Web GIS & Physical Infrastructure Registry
* **PostGIS Spatial Engine:** Sub-second spatial queries for ward boundaries, radius searches, and network line traces.
* **Electrical Pole Management:** Tracks pole ID, keypad ID, wattage, fixture type, installation date, and historical fault logs.
* **Water Utility Pathways:** GeoJSON pipeline routes, junction valves, distribution sumps, and overhead tank mappings.
* **Public QR Reporting Portal:** Token-gated citizen interface triggered by scanning on-pole QR tags.

### Module 3: IoT Utility Telemetry & Real-Time Monitoring
* **Overhead Tank (OHT) Monitoring:** Real-time water capacity, fill percentages, and fill/drain cycle analytics.
* **Pipeline Flow Rate (LPS):** Continuous litres-per-second monitoring to detect unauthorized tapping and main pipe bursts.
* **Pressure Logging:** Time-series telemetry charts with configurable high/low threshold alerts.
* **Predictive Maintenance:** Early-warning automated alerts (SMS/Email) before asset failure disrupts public supply.

### Module 4: E-Tendering, Procurement & Vendor Ecosystem
* **Full Tender Lifecycle:** Draft → Published (Invite-Only or Open) → Quotation Collection → Comparative Statement → Work Order Award → Execution.
* **Asset-Linked Line Items:** Line items mapped directly to physical GIS infrastructure assets.
* **Visual Document Template Designer:** In-browser Fabric.js canvas editor allowing administrators to design custom letterheads, stamps, margins, and watermarks for automated Gotenberg PDF generation.
* **Immutable Audit Trail:** Tamper-proof logging of every status change, quotation submission, and officer approval.

### Module 5: Field Workforce Mobile App & Anti-Fraud Resolution
* **Mobile-First Field Queue:** Daily work orders and public grievances routed straight to field technicians' phones.
* **Geo-Fenced Closure Guard:** Hardware GPS validation enforcing presence within ≤ 50m of target asset.
* **Before/After AI-OCR Capture:** Live camera-only photo evidence submission cross-referenced with asset serial numbers.

### Module 6: Statutory Urban & Rural Body Administrative Modules
* **Building Permits & NOC Engine:** Application intake, plinth area calculation, inspection reports, and multi-agency NOC checklists before permit generation.
* **Birth & Death Register:** Statutory compliance with Section 13 late-fee bands (21 days, 30 days, 1 year, Magistrate order), with tamper-proof certificate cancellation upon corrections.
* **Solid Waste Management:** Dynamic bin capacity derivation, collection frequency tracking, and sanitation route monitoring.
* **Trade Licences:** Financial-year validity cycles (1 Apr – 31 Mar), quarter-wise pro-rating, renewal penalties, and mandatory closure after 90 days delinquency.
* **Municipal Revenue Recovery:** Digital tokens for weekly market (*santhai*) vendor stalls, utility pole commercial cable leases, and community hall reservations.

### Module 7: Multi-Tier Administration & Granular Local Body RBAC
* **25 Pre-Configured Roles** tailored across all 6 Tamil Nadu local body types:
  1. *Corporation / Municipality:* Commissioner, Municipal Engineer, Assistant/Junior Engineer, Health Officer, Sanitary Inspector, Revenue Inspector, Town Planning Officer, Registrar.
  2. *Town Panchayat:* Executive Officer (EO).
  3. *Village Panchayat:* Panchayat President, Panchayat Secretary, Bill Collector.
  4. *Panchayat Union / Block:* Block Development Officer (BDO).
  5. *District Panchayat:* District Panchayat Officer (DPO).
  6. *Cross-Cutting:* Super Admin, Panchayat Admin, I3C Staff, Contractor, Electrician, Plumber, Agent.
* **Dynamic Entitlement Matrix:** Roles inherit permissions hierarchically with granular route-level screen access and branch-type restrictions.

### Module 8: Executive Command Center (I3C) & Statutory Reporting (MIS)
* **Live Operations Command Screen:** Real-time grievance counters, active contractor crews, and SLA escalation alarms.
* **One-Click Statutory Export Engine:** Compiles complete ZIP archives containing audit logs, GPS coordinates, and timestamped photo evidence for state audit compliance.
* **Contractor Performance Index:** Automated scoring based on SLA compliance, average resolution hours, and verified photo accuracy.

---

## 5. Technical Specifications & Architecture

| Parameter | Specification Details |
| :--- | :--- |
| **Product Deployment** | Cloud SaaS (Multi-Tenant Sovereign Architecture) / On-Premise / Hybrid |
| **Backend Framework** | NestJS (Node.js & TypeScript), Modular Architecture, Prisma ORM |
| **Frontend Applications** | Flutter (Web-First Portal + Cross-Platform Android & iOS Mobile) |
| **Spatial Database** | PostgreSQL with PostGIS Spatial Extensions (Hosted on MeitY-Compliant Cloud) |
| **AI / Machine Learning** | OpenAI Whisper (Speech-to-Text), Google Gemini (Conversational Intelligence & Intent Extraction), Google Vision AI (OCR) |
| **Telephony Integration** | Exotel Cloud Telephony (Two-Way Voice Streaming, Dynamic Webhooks & DTMF) |
| **Document Generation** | Headless Chromium (Gotenberg) + Fabric.js Visual Canvas Vector Design Engine |
| **Authentication & Security** | JWT Authentication, Hierarchical RBAC, AES-256 Data Encryption, Immutable Audit Logs |
| **Statutory Compliance** | General Financial Rules (GFR) 2017, GeM T&C, Digital Personal Data Protection (DPDP) Act 2023, RBD Act 1969 |

---

## 6. Live Interactive Demos & Testing Data

Website visitors, procurement officers, and evaluators can test the live system:

* **Live Web Portal URL:** [https://ivr-frontend-system-sengotics.vercel.app/](https://ivr-frontend-system-sengotics.vercel.app/)
* **Primary AI Voice Agent Helpline:** `04440115043` *(Call and speak naturally in Tamil or English)*
* **Secondary Keypad DTMF Helpline:** `04440115434` *(Call and test keypad IDs `101`, `102`, `103`)*

### Demo Portal Credentials
| Role | Email / Username | Password | Access Scope |
| :--- | :--- | :--- | :--- |
| **Super Admin** | `superadmin@sengotics.com` | `Admin@1234` | Full platform control, tenant onboarding, global RBAC |
| **Panchayat Admin** | `admin@sengotics.com` | `Admin@1234` | Municipal assets, tenders, field crew assignment |
| **Field Electrician** | `electrician@sengotics.com` | `Admin@1234` | Mobile field queue & GPS geo-fenced repair resolution |

### Sample Test Poles
* **Pole 1 (Commercial Junction):** Pole `PL-MTP-001` | Keypad ID: `101` | Landmark: *Near Bus Stop, Main Road Junction*
* **Pole 2 (Residential Ward):** Pole `PL-MTP-002` | Keypad ID: `102` | Landmark: *Corner of Pillaiyar Kovil Street*
* **Pole 3 (Rural Outskirts):** Pole `PL-MTP-003` | Keypad ID: `103` | Landmark: *Opposite Primary Health Centre*

---

## 7. Website-Ready Content Blocks (For Web Builder AI)

### SEO Metadata
- **Page Title:** Ooraatchi by Sengotics — Smart Web GIS, AI Voice Helplines & Municipal Governance Platform
- **Meta Description:** Ooraatchi by Sengotics is a turnkey Web GIS and e-governance platform for municipal corporations and panchayats. Features conversational Tamil/English AI voice helplines, IoT water telemetry, e-tendering, and geo-fenced field proof.
- **Keywords:** Ooraatchi, Sengotics, Web GIS Municipality, AI IVR Helpline Tamil, Municipal E-Tendering, PostGIS Asset Management, Panchayat Governance Software, Smart City I3C Command Center, GeM Municipal Software.

### Hero Section Copy
- **Badge:** Trusted Digital Future • GeM Registered OEM
- **Heading:** Smart GIS Governance & AI Voice Helplines for Modern Municipalities
- **Subheading:** Unify citizen grievance redressal, GIS asset tracking, e-tendering, and field workforce accountability into one secure, multi-tenant sovereign cloud platform.
- **Primary CTA:** Explore Live Demo (`https://ivr-frontend-system-sengotics.vercel.app/`)
- **Secondary CTA:** Call AI Helpline (`tel:04440115043`)

### Key Stats for Website Counters
- **100%** Citizen Accessibility via Conversational Tamil & English AI Voice
- **≤ 50m** GPS Geo-Fencing for Anti-Fraud Field Resolutions
- **8+** Fully Integrated Municipal Governance Modules
- **25** Pre-Configured Local Body Governance Roles
- **24/7** Turnkey On-Site I3C Command Center Support

### Frequently Asked Questions (FAQ) for Website
1. **Q: How does the AI voice helpline handle illiterate or elderly citizens?**  
   *A:* Citizens do not need a smartphone, internet connection, or literacy. They simply dial `04440115043` from any basic phone and speak naturally in their local dialect. The AI understands their grievance, queries the database, registers the ticket, and confirms via SMS.
2. **Q: Can field contractors fake ticket closures?**  
   *A:* No. The Ooraatchi mobile application strictly validates device GPS coordinates against the asset's PostGIS location (≤ 50-meter radius) and requires real-time camera capture analyzed by Google Vision AI before allowing ticket resolution.
3. **Q: Is the platform compliant with government procurement rules?**  
   *A:* Yes. The e-tendering engine is fully aligned with General Financial Rules (GFR) 2017, GeM guidelines, and state PWD norms, featuring invite-only sealed bidding and automated L1/L2 comparative statements.
4. **Q: Does Sengotics provide on-site operational support?**  
   *A:* Yes. Under our Turnkey Model, Sengotics stations dedicated operations personnel directly inside the municipality’s Integrated Command & Control Center (I3C) to handle daily monitoring and escalation.

---

## 8. Corporate & OEM Information

* **Company Name:** Sengotics  
* **Tagline:** Trusted Digital Future  
* **GSTIN:** `33DKDPA5555E1ZL`  
* **MSME Udyam Registration:** `UDYAM-TN-03-0308455`  
* **GeM Seller ID:** `N78K260014298113`  
* **Registered Office:** 4/360, Anna Nagar, Dhayanur, Karamadai - Tholampalayam Road, Near Gram Panchayat Office, Kemmarampalayam, Kalampalayam, Mettupalayam, Coimbatore, Tamil Nadu – 641113  
* **Email:** `contact@sengotics.com`  
* **Phone:** `+91 9597769501`  
* **Official Website:** [www.sengotics.com](https://www.sengotics.com)
