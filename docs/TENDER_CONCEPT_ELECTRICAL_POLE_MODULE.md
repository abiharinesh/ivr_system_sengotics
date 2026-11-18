# GOVERNMENT OF TAMIL NADU / LOCAL ADMINISTRATION DEPARTMENT
## TENDER CONCEPT & TECHNICAL SPECIFICATION DOCUMENT
### Volume I: Scope of Work, Technical Architecture, BOQ & Service Level Agreement (SLA)

---

**Tender Reference:** ROC / ENGG / ELEC / 2026 / T-01  
**Project Title:** Implementation of Smart GIS-Based Street Light & Electric Pole Infrastructure Management System with Conversational AI Voice Helpline, Weatherproof QR Code Asset Tagging, Citizen Reporting App, and Geo-Fenced Workforce Verification  
**Issuing Authority:** Office of the Municipal Commissioner / Executive Officer / Block Development Officer  
**Jurisdiction:** [Name of Municipality / Town Panchayat / Panchayat Union, e.g., Mettupalayam Municipality, Coimbatore District]  
**Procurement Method:** Open Competitive E-Tendering (Two-Cover System: Technical Bid & Financial Bid) under Tamil Nadu Transparency in Tenders Act, 1998 & Rules, 2000  

---

## TABLE OF CONTENTS
1. [Tender Notice & Bid Summary](#1-tender-notice--bid-summary)
2. [Project Background, Objectives & Need Analysis](#2-project-background-objectives--need-analysis)
3. [Comprehensive Scope of Work (SOW)](#3-comprehensive-scope-of-work-sow)
   - 3.1 Pillar 1: Door-to-Door GIS Asset Survey & Retroreflective QR Tagging
   - 3.2 Pillar 2: 24/7 Dual-Helpline Voice Infrastructure (Conversational AI + Keypad IVR)
   - 3.3 Pillar 3: Citizen Engagement & Multi-Channel Reporting Ecosystem
   - 3.4 Pillar 4: Field Electrician Workforce Mobile Application with Geo-Fencing
   - 3.5 Pillar 5: Integrated Command & Control Center (I3C) Executive Dashboard
   - 3.6 Pillar 6: Automated Tender, Work Order & Digital M-Book Integration
4. [System Architecture & Cloud Security Standards](#4-system-architecture--cloud-security-standards)
5. [Hardware & Material Specifications (QR Plates & Field Devices)](#5-hardware--material-specifications)
6. [Service Level Agreement (SLA) & Penalty Deduction Schedule](#6-service-level-agreement-sla--penalty-deduction-schedule)
7. [Bill of Quantities (BOQ) & Financial Schedule Template](#7-bill-of-quantities-boq--financial-schedule-template)
8. [Bidder Eligibility Criteria & Technical Evaluation Matrix](#8-bidder-eligibility-criteria--technical-evaluation-matrix)
9. [Project Implementation Schedule & Milestone Deliverables](#9-project-implementation-schedule--milestone-deliverables)
10. [Annexures & Declarations](#10-annexures--declarations)

---

## 1. TENDER NOTICE & BID SUMMARY

| S.No. | Parameter | Tender Specification Details |
| :--- | :--- | :--- |
| 1.1 | **Name of the Work** | Turnkey Implementation and Operational Maintenance of Smart GIS Street Light & Electric Pole Asset Management System including Conversational AI Voice Helpline, QR Code Citizen Portal, and Geo-Fenced Mobile Workforce Tracking. |
| 1.2 | **Tender Inviting Authority** | The Municipal Commissioner / Executive Officer, [Local Body Name]. |
| 1.3 | **Procurement Type** | E-Tender via Tamil Nadu Government E-Procurement Portal (`https://tntenders.gov.in`) and/or GeM Portal. |
| 1.4 | **Bidding System** | Two-Cover System: **Cover 1:** Pre-Qualification & Technical Bid; **Cover 2:** Financial Bid. |
| 1.5 | **Earnest Money Deposit (EMD)** | As specified in the E-Tender Notice (Exemption applicable for registered Tamil Nadu Micro & Small Enterprises / MSME / NSIC upon submission of valid Udyam certificate). |
| 1.6 | **Contract Period** | **Implementation Phase:** 60 Days from Work Order; **Operations & Maintenance (O&M) Phase:** 36 Months (extendable by mutual agreement up to 60 months). |
| 1.7 | **Language of Bid & System** | English & Tamil (Bilingual citizen interfaces & voice prompts mandatory). |
| 1.8 | **Performance Security** | 5% of the total accepted contract value in the form of Bank Guarantee (BG) from a Nationalized/Scheduled Commercial Bank. |
| 1.9 | **Cloud Hosting Mandate** | MeitY-empaneled Tier-III Data Center located within sovereign territory of India. |

---

## 2. PROJECT BACKGROUND, OBJECTIVES & NEED ANALYSIS

### 2.1 Context
Urban and rural local bodies (Municipal Corporations, Municipalities, Town Panchayats, and Village Panchayats) are responsible for maintaining thousands of public street lighting assets spread across wide geographic areas. Currently, local administration encounters substantial operational difficulties:
- **Digital Divide in Fault Reporting:** Traditional online web portals and mobile apps fail to cater to rural citizens, senior citizens, and semi-literate demographics who cannot type complex text complaints.
- **Unreported Dark Spots:** Faulty street lights often remain non-functional for days or weeks because civic bodies lack an automated, proactive complaint ingestion and dispatch mechanism.
- **Ghost & False Closures:** Maintenance contractors or field personnel often mark tickets "Resolved" without physically attending to the site, leading to citizen dissatisfaction and wasted public expenditure.
- **Lack of Digitized Asset Baseline:** Absence of an exact spatial inventory (GPS coordinates, pole type, fixture wattage, phase balance, wire condition) impedes scientific energy audits, predictive maintenance, and streamlined procurement.
- **Fragmented Tendering & Contractor Billing:** Work orders and contractor payments are delayed due to manual paper measurement books (M-Books) and lack of verifiable, tamper-proof field photographic proof.

### 2.2 Core Project Objectives
1. **100% Inclusivity in Citizen Access:** Provide conversational natural Tamil voice artificial intelligence (AI) and dialpad DTMF IVR so any citizen can report an outage in 30 seconds from any standard mobile or landline phone.
2. **Instant Asset Identification via Weatherproof QR Tags:** Mount UV-resistant, retroreflective QR code plates on every pole, enabling smartphone owners to log an issue instantly without downloading any mobile app.
3. **Mandatory Geo-Fenced Resolution Proof:** Enforce strict cryptographic and geographic ($\le 50\text{ meters}$) validation preventing electricians from closing tickets unless they are physically standing at the pole and uploading live before-and-after photographic evidence.
4. **Digital Governance & E-Tender Continuity:** Automatically aggregate recurring pole defects into procurement bundles, generating statutory Tamil Nadu local body document packs (RFQ, Comparative Statement, Work Order, Form 19 Expenditure Vouchers, and Special Officer Proceedings).

---

## 3. COMPREHENSIVE SCOPE OF WORK (SOW)

The selected Technology & Implementation Agency (Contractor/Vendor) shall execute the following functional pillars on a turnkey basis:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INTEGRATED PLATFORM ARCHITECTURE                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│   DUAL-HELPLINE  │       │  QR CODE ASSET   │       │  CITIZEN WEB /   │
│   AI & DTMF IVR  │       │   FIELD PLATES   │       │  MOBILE PORTAL   │
│ (Tamil/Eng Voice)│       │ (Scan to Report) │       │ (Track & Status) │
└────────┬─────────┘       └────────┬─────────┘       └────────┬─────────┘
         │                          │                          │
         └──────────────────────────┼──────────────────────────┘
                                    ▼
         ┌─────────────────────────────────────────────────────┐
         │     POSTGIS GIS DATABASE & DISPATCH ENGINE          │
         │  (Asset Mapping, Spatial Queries & SLA Countdown)   │
         └──────────────────────────┬──────────────────────────┘
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         ▼                                                     ▼
┌─────────────────────────────────┐           ┌─────────────────────────────────┐
│ FIELD WORKFORCE MOBILE APP      │           │ I3C EXECUTIVE COMMAND CENTER    │
│ • Mandatory ≤ 50m Geo-Fence     │           │ • Live Ward Heatmaps            │
│ • EXIF & OCR Plate Verification │           │ • SLA Escalations & Penalties   │
│ • Live Before/After Photo Proof │           │ • E-Tender & Form 19 Generator  │
└─────────────────────────────────┘           └─────────────────────────────────┘
```

### 3.1 Pillar 1: Door-to-Door GIS Asset Survey & Retroreflective QR Tagging
1. **Physical Ground Survey:**
   - The vendor shall deploy trained field survey personnel equipped with sub-meter GNSS/GPS devices to catalog 100% of street lighting poles across all wards of the local body.
   - Collected parameters shall include: Unique Pole ID, Ward Number, Street Name, GPS Latitude & Longitude (WGS-84 coordinate system), Pole Material (Tubular, Concrete/PSC, Octagonal, Lattice), Lamp Type (LED, Sodium Vapour, Tube Light), Wattage (20W, 40W, 70W, 120W, etc.), Phase/Circuit Line connection, Substation/Control Box feeder, physical pole condition, and prominent landmarks in both Tamil and English.
2. **Manufacture & Installation of Weatherproof QR Asset Plates:**
   - Fabricate physical retroreflective, UV-resistant, scratch-proof aluminum plates (Grade 6061-T6 or 3M commercial diamond-grade reflective sheeting mounted on rust-proof backing).
   - Plates must clearly display:
     - Municipal / Panchayat Crest & Name in Tamil.
     - Unique Pole Keypad ID (e.g., `101`, `102`) in high-contrast bold font legible from 10 meters away.
     - Permanent Dynamic 2D QR Code encoded with a cryptographic unique public token.
     - 24/7 AI Voice Helpline Number and SMS/WhatsApp reporting instructions.
   - Affix each plate at a standard height of 2.2 meters to 2.5 meters above ground level using non-corrosive stainless steel banding (304 grade) or tamper-proof drive rivets, preventing theft and vandalism.

---

### 3.2 Pillar 2: 24/7 Dual-Helpline Voice Infrastructure (Conversational AI + Keypad IVR)
The vendor shall provide and maintain a carrier-grade cloud telephony and AI voice infrastructure operating 24 hours a day, 365 days a year:

1. **Primary Helpline: Conversational AI Voice Agent (Natural Spoken Tamil & English):**
   - **Zero Dialpad Dependency:** Citizens simply speak in colloquial, conversational Tamil, Tanglish, or English without listening to rigid menu trees.
   - **Acoustic & Dialect Intelligence:** Equipped with deep-learning Automatic Speech Recognition (ASR) tuned to Tamil Nadu regional dialects (e.g., Kongu Tamil, Chennai Tamil, Madurai Tamil, Cauvery Delta Tamil).
   - **Dynamic Grievance Extraction:** Intelligently identifies the nature of the issue (light blinking, completely off, broken bracket, dangling live wire, daytime burning), landmark description, and urgency level.
   - **Live Database Status Interrogation:** When an existing caller dials in, the AI agent dynamically queries the PostgreSQL backend (`fetch_existing_complaints`), verifies ticket progress, and speaks back real-time status in natural Tamil (e.g., *"உங்கள் புகார் எண் 412 மீது கள மின்சார பணியாளர் நியமிக்கப்பட்டுள்ளார்; இன்று மாலைக்குள் பழுது நீக்கப்படும்"*).
   - **Emergency Triaging:** Flags electrical hazard complaints (sparking, fallen pole, electrocution risk) with critical priority and triggers instant SMS/call alerts to the Municipal Engineer and Junior Engineer.
2. **Secondary Helpline: High-Speed DTMF Keypad IVR:**
   - Optimized for basic feature phones and poor signal conditions.
   - Citizen dials the helpline number, selects language (1 for Tamil, 2 for English), and types the 3-digit or 4-digit Pole Keypad ID embossed on the pole tag (e.g., `101#`).
   - The system instantly locates the pole via database key, confirms the street name via automated TTS voice prompt, and logs the ticket.

---

### 3.3 Pillar 3: Citizen Engagement & Multi-Channel Reporting Ecosystem
1. **Instant Web Reporting (No App Installation Required):**
   - When a citizen scans the QR plate with any smartphone camera, the browser immediately opens a lightweight, mobile-responsive PWA (Progressive Web App).
   - Automatically loads the specific Pole ID, Ward Number, and Landmark from the cryptographic URL token.
   - One-tap fault selection: "Bulb Blown / Not Glowing", "Light Blinking", "Daytime On", "Damaged Arm / Wire Hanging".
   - Optional photo attachment and GPS verification.
2. **Citizen Mobile Application & Web Portal:**
   - Bi-lingual citizen self-service application available on Google Play Store and Web.
   - Features include: Interactive ward-wise street light map, "Report Fault Near Me" using device GPS, live ticket timeline with SMS/WhatsApp push updates, citizen satisfaction rating upon closure.
3. **Automated Citizen Notifications:**
   - Instant SMS confirmation with unique Complaint Reference Number and live tracking URL.
   - WhatsApp message containing electrician contact details upon assignment.
   - Final resolution notification containing the timestamped photo of the repaired pole.

---

### 3.4 Pillar 4: Field Electrician Workforce Mobile Application with Geo-Fencing
To eliminate false resolution of complaints, the vendor shall supply a dedicated mobile application for Municipal Electricians and Maintenance Contractors with the following mandatory security controls:

1. **Mandatory Geo-Fencing ($\le 50\text{m}$ Radius Enforcement):**
   - The application shall compute the real-time distance between the electrician's device and the physical GIS coordinates of the registered pole using Haversine / PostGIS spatial geometry.
   - Ticket resolution is **strictly locked** if the distance exceeds 50 meters. The application must block resolution attempts from home or remote locations.
2. **Cryptographic Photo Proof & EXIF Metadata Validation:**
   - The electrician must capture a live photo of the repaired fixture through the in-app camera (gallery uploads strictly prohibited).
   - The app extracts hardware-level EXIF metadata (embedded GPS latitude, longitude, and device timestamp).
   - The server verifies that the photo timestamp is within 3 minutes of upload and matches device telemetry.
3. **Automated OCR Number Plate Matching:**
   - Built-in optical character recognition (OCR) scans the uploaded photo to detect the physical pole number tag, ensuring the photograph corresponds to the exact asset assigned in the ticket.
4. **Offline Capability:**
   - Enables field workers to log repairs in rural shadow areas with no cellular coverage; encrypted verification packets auto-sync once network connectivity is restored.

---

### 3.5 Pillar 5: Integrated Command & Control Center (I3C) Executive Dashboard
An enterprise web-based portal engineered for Municipal Commissioners, Municipal Engineers, Junior Engineers, and Ward Councilors:
1. **GIS Spatial Map Layer:**
   - Color-coded asset health pins: Green (Functional), Red (Fault Reported), Yellow (Work in Progress), Grey (Under Tendering/Major Overhaul).
   - Dark-spot cluster heatmap highlighting chronically failing streets or high-incident electrical distribution transformers.
2. **Real-Time SLA & Escalation Engine:**
   - Live countdown clocks per ticket based on priority tier (Critical: 4 Hours, High: 12 Hours, Routine: 24 Hours).
   - Automated multi-level escalation matrix: Level 1 (Electrician) $\rightarrow$ Level 2 (Junior Engineer / Inspector) $\rightarrow$ Level 3 (Municipal Engineer) $\rightarrow$ Level 4 (Commissioner).
3. **Contractor Grading & Billing Engine:**
   - Automated SLA compliance scoring (uptime %, average turnaround time, repeat fault rate within 7 days).
   - Automatic deduction calculation for delayed repairs in monthly billing vouchers.

---

### 3.6 Pillar 6: Automated Tender, Work Order & Digital M-Book Integration
For complex maintenance works requiring procurement of new LED fixtures, underground cable laying, or pole replacement:
1. **Automated Procurement Bundling:**
   - The officer can select open/unresolvable complaints on the GIS dashboard and bundle them directly into a municipal tender draft.
2. **Tamil Nadu Government Document Chain:**
   - Automated compilation of statutory Tamil procurement PDFs:
     - **விலைப்புள்ளி கோருதல் (RFQ Document):** With line item schedule and statutory notice rules.
     - **கொட்டேஷன் (Vendor Quotation Forms):** Pre-formatted per registered electrical contractor.
     - **ஒப்பு நோக்கு பட்டியல் (Comparative Statement):** Automated L1 evaluation and rate comparison.
     - **வேலை உத்தரவு (Official Work Order):** Specifying execution window and legal contract terms.
     - **தனி அலுவலர் நடவடிக்கைகள் (Special Officer Proceedings):** Financial sanction proceedings with amount in figures and Tamil words.
     - **செலவினச் சீட்டு (Form 19 Expenditure Voucher):** Complete digital measurement book (M-Book) certification for audit compliance.

---

## 4. SYSTEM ARCHITECTURE & CLOUD SECURITY STANDARDS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SYSTEM SECURITY ARCHITECTURE                       │
└─────────────────────────────────────────────────────────────────────────────┘
  [CITIZEN VOICE / IVR] ──► [TELEPHONY SIP TRUNKS (Exotel Carrier Gateway)]
                                          │
                                          ▼
  [WEB / PWA / MOBILE]   ──► [WAF & SSL TLS 1.3 REVERSE PROXY]
                                          │
                                          ▼
                             [NESTJS CORE BACKEND API]
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        ▼                                 ▼                                 ▼
┌──────────────────┐            ┌──────────────────┐            ┌──────────────────┐
│  POSTGIS / DB    │            │  AI SPEECH & LLM │            │ SECURE S3 BUCKET │
│ PostgreSQL Cloud │            │ Whisper / GPT /  │            │ Tamper-Proof     │
│ Spatial Indexing │            │ Indic NLP Voice  │            │ Photo Evidence   │
└──────────────────┘            └──────────────────┘            └──────────────────┘
```

1. **Multi-Tenant Architecture:**
   - Single sovereign codebase supporting multi-tier hierarchy: State $\rightarrow$ District $\rightarrow$ Municipality / Block $\rightarrow$ Ward $\rightarrow$ Asset.
2. **Data Residency & Sovereignty:**
   - All citizen phone numbers, grievance audio recordings, and asset databases must reside strictly within Indian sovereign borders in MeitY-accredited data centers.
3. **Role-Based Access Control (RBAC):**
   - Strictly enforced roles: Super Admin, Municipal Commissioner, Municipal Engineer, Junior Engineer, Sanitary/Electrical Inspector, Field Electrician, Contractor, and Citizen.
4. **Security & Cryptography:**
   - AES-256 encryption at rest; TLS 1.3 encryption in transit.
   - OWASP Top 10 compliance; protection against SQL injection, cross-site scripting (XSS), and automated brute-force attacks.

---

## 5. HARDWARE & MATERIAL SPECIFICATIONS

### 5.1 Weatherproof QR Asset Plates
| Parameter | Technical Standard Specification |
| :--- | :--- |
| **Base Material** | High-Grade Anodized Aluminum Sheet (Alloy 6061-T6) or 3M Diamond Grade Retroreflective sheeting on 1.5mm aluminum composite backing. |
| **Dimensions** | 150 mm (Height) $\times$ 100 mm (Width) $\times$ 1.5 mm (Thickness) $\pm 5\%$. |
| **Reflectivity** | Retroreflective Class 2 (ASTM D4956 Type IV or higher) clearly visible under vehicle headlights and street lighting at night. |
| **Coating / Inks** | UV-curable industrial inks with high-durability polyurethane clear overcoat; resistant to fading, rain, acid wash, and direct sunlight. |
| **Expected Lifespan** | Minimum 7 Years outdoor exposure under tropical conditions (Temperature range: $10^\circ\text{C}$ to $50^\circ\text{C}$; Humidity up to 98%). |
| **Mounting Fixture** | Grade 304 Stainless Steel strapping bands (12.7 mm width) with heavy-duty wing seals, or high-tensile tamper-resistant drive rivets. |

---

## 6. SERVICE LEVEL AGREEMENT (SLA) & PENALTY DEDUCTION SCHEDULE

The contractor shall strictly adhere to the following turnaround times (TAT) for grievance resolution and system uptime:

### 6.1 Grievance Resolution SLA Matrix
| Fault Category | Classification & Description | Maximum Permissible Turnaround Time (TAT) | Penalty for SLA Breach |
| :--- | :--- | :--- | :--- |
| **Tier-1: Critical Hazard** | Fallen electric pole, dangling live wire, sparking box, shock hazard near school/hospital. | **Within 4 Hours** from intake | ₹500 per hour of delay. |
| **Tier-2: High Priority** | Complete street dark (more than 3 consecutive poles dead), main commercial road dark. | **Within 12 Hours** from intake | ₹200 per pole per day of delay. |
| **Tier-3: Standard Fault** | Isolated single street light failure, bulb fused, fixture flickering. | **Within 24 Hours** from intake | ₹100 per pole per day of delay. |
| **Tier-4: Daytime Burning** | Street lights remaining turned ON during daytime hours ($>06:30\text{ AM}$). | **Within 2 Hours** of notification | ₹50 per pole per occurrence. |

### 6.2 System Availability & Telephony SLA
- **Helpline Uptime:** Telephony IVR and AI Voice Agent must maintain **99.5% monthly availability** (excluding scheduled maintenance during off-peak hours with prior written approval).
- **Failure Penalty:** If voice helpline downtime exceeds 0.5% in any calendar month, a penalty of ₹2,000 per hour of downtime shall be deducted from the monthly maintenance bill.

---

## 7. BILL OF QUANTITIES (BOQ) & FINANCIAL SCHEDULE TEMPLATE

*Bidders shall quote rates strictly in the electronic financial bid cover (Cover 2). Below is the standard Bill of Quantities schedule:*

| Item No. | Description of Item / Scope Component | Unit of Measurement | Estimated Quantity (Base) | Quoted Unit Rate (₹) (Excl. GST) | Total Amount (₹) (Excl. GST) |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **1.01** | **Physical GIS Asset Survey:** Comprehensive door-to-door ground mapping of electric poles including sub-meter GNSS coordinates, fixture type, wattage, phase, line condition, and bilingual street landmarks. | Per Pole | 5,000 | ₹50.00 | ₹2,50,000.00 |
| **1.02** | **QR Asset Plate Fabrication & Installation:** Supply and installation of retroreflective anodized aluminum QR plates (150x100 mm, 1.5mm thickness) with stainless steel bands, high-contrast Pole ID, and UV protective clear coat. | Per Plate | 5,000 | ₹120.00 | ₹6,00,000.00 |
| **1.03** | **Cloud Software License & Platform Setup:** Enterprise setup of Ooraatchi GIS platform, Web Dashboard, RBAC modules, automated tender engine, PostGIS spatial database, and integration with local body GIS boundary. | Lump Sum | 1 Unit | ₹3,00,000.00 | ₹3,00,000.00 |
| **1.04** | **Dual-Helpline AI Voice Telephony & IVR Channel:** Setup and operation of conversational Tamil/English AI Voice Agent and DTMF Keypad IVR lines, including Exotel SIP trunks, ASR speech recognition models, and cloud dialer. | Per Month | 36 Months | ₹20,000.00 | ₹7,20,000.00 |
| **1.05** | **Field Workforce & Citizen Mobile Applications:** Mobile app deployment on Android Play Store, including geo-fenced resolution engine ($\le 50\text{m}$ radius lock), OCR verification, and PWA instant scan portal. | Lump Sum | 1 Unit | ₹2,00,000.00 | ₹2,00,000.00 |
| **1.06** | **Cloud Hosting & Data Security:** High-availability MeitY-empaneled Tier-III cloud hosting, automated daily backups, SSL TLS 1.3 certificates, and 99.5% uptime assurance. | Per Year | 3 Years | ₹90,000.00 | ₹2,70,000.00 |
| **1.07** | **Turnkey Operations & On-Site I3C Support:** Provision of dedicated, trained technical operator deployed at the Municipal Command Center for daily ticket triage, SLA monitoring, and report generation. | Per Month | 36 Months | ₹20,000.00 | ₹7,20,000.00 |
| **SUBTOTAL** | **Base Turnkey Contract Value (Excluding Applicable GST)** | — | — | — | **₹30,60,000.00** |
| **GST** | **Applicable GST @ 18% (CGST 9% ₹2,75,400 + SGST 9% ₹2,75,400)** | — | — | — | **₹5,50,800.00** |
| **TOTAL** | **Comprehensive Turnkey Contract Value (Inclusive of 18% GST)** | — | — | — | **₹36,10,800.00** |

### Financial Summary in Words:
- **Base Contract Value (Excluding GST):** ₹30,60,000.00 (*Rupees Thirty Lakhs Sixty Thousand Only* / ரூபாய் முப்பது லட்சத்து அறுபதாயிரம் மட்டும்)
- **Total Contract Value (Inclusive of 18% GST):** ₹36,10,800.00 (*Rupees Thirty-Six Lakhs Ten Thousand Eight Hundred Only* / ரூபாய் முப்பத்தாறு லட்சத்து பத்தாயிரத்து எண்ணூறு மட்டும்)
- **Capital Expenditure (Capex - Year 1 Setup, Survey, Plates & Software):** ₹13,50,000.00 (44.1%)
- **Operational Expenditure (Opex - 36-Month Telephony, Cloud & On-Site Operator):** ₹17,10,000.00 (55.9%)

---

## 8. BIDDER ELIGIBILITY CRITERIA & TECHNICAL EVALUATION MATRIX

### 8.1 Minimum Pre-Qualification (PQ) Eligibility Criteria
1. **Legal Entity:** The bidder must be a registered company under the Indian Companies Act, Limited Liability Partnership (LLP), or registered MSME enterprise with a valid GSTIN and PAN.
2. **Financial Standing:** The average annual financial turnover of the bidder during the last 3 financial years (FY 2022-23, 2023-24, 2024-25) shall not be less than ₹50 Lakhs (Relaxation applicable for registered DPIIT startups / Tamil Nadu MSME units as per government orders).
3. **Past Experience:** The bidder must have successfully executed or be currently operating at least one project involving GIS Asset Mapping, Cloud ERP, Smart Telephony/IVR, or Municipal e-Governance software for a Government entity, PSU, or municipal body.
4. **GeM Registration:** The bidder must be an active registered seller on the Government e-Marketplace (GeM).
5. **No Blacklisting:** The bidder shall submit an affidavit on ₹100 stamp paper certifying that the entity has not been debarred or blacklisted by any Central/State Government department or PSU.

### 8.2 Technical Evaluation Scoring Matrix (100 Marks Total)
*Only bidders scoring $\ge 75\text{ marks}$ in technical evaluation shall qualify for opening of the financial bid:*

| Evaluation Parameter | Criteria & Mark Breakdown | Max Marks |
| :--- | :--- | :---: |
| **Organizational Strength & Financial Turnover** | • Turnover $>$ ₹1 Crore: 15 Marks<br>• Turnover ₹50 Lakhs to ₹1 Crore: 10 Marks<br>• MSME / Startup in Tamil Nadu: 5 Marks bonus | **20 Marks** |
| **Prior Experience in GIS & Civic Technology** | • $\ge 3$ Similar Projects: 20 Marks<br>• 1 to 2 Similar Projects: 10 Marks | **20 Marks** |
| **Live Product Demonstration & Feature Validation** | Real-time demonstration before the technical committee: Conversational AI Tamil Voice Call, DTMF IVR pole lookup, QR scan flow, and field app geo-fencing test. | **30 Marks** |
| **System Architecture & Cloud Security Plan** | Architecture design, MeitY cloud compliance, PostGIS spatial indexing, and data recovery plan. | **15 Marks** |
| **On-Site Operational Support Methodology** | Staffing plan, helpdesk operations, training manual, and SLA escalation framework. | **15 Marks** |
| **TOTAL TECHNICAL SCORE** | — | **100 Marks** |

---

## 9. PROJECT IMPLEMENTATION SCHEDULE & MILESTONES

| Milestone | Activity Description | Target Completion Window | Payment Milestone (% of Capex) |
| :---: | :--- | :---: | :---: |
| **T0** | Issuance of Work Order & Letter of Acceptance (LoA) | Day 0 | — |
| **M1** | Inception Report, System Customization, Cloud Environment Provisioning, and Baseline Telephony Setup | Day 15 | 15% |
| **M2** | Completion of 100% GIS Field Survey of Electric Poles and Ward Boundary Integration | Day 35 | 25% |
| **M3** | Fabrication, Supply, and On-Pole Installation of all Weatherproof QR Code Plates | Day 50 | 30% |
| **M4** | Operational Go-Live: Commissioning of AI Voice Helpline, Citizen PWA, Electrician App, and I3C Dashboard | Day 60 | 20% |
| **M5** | User Acceptance Testing (UAT) Sign-off by Municipal Engineer & Final System Handover | Day 75 | 10% |
| **O&M** | Quarterly Operations, Telephony Maintenance & On-Site Support | End of each quarter | Equal quarterly installments |

---

## 10. ANNEXURES & DECLARATIONS

### Annexure I: Live System Evaluation Credentials (For Tender Committee Verification)
- **Live Platform Portal:** `https://ivr-frontend-system-sengotics.vercel.app/`
- **Conversational AI Voice Line:** `04440115043` (Test natural spoken Tamil fault reporting)
- **Keypad DTMF Helpline:** `04440115434` (Test keypad pole ID entry: `101`, `102`, `103`)
- **Evaluation Admin Login:** `admin@sengotics.com` | **Password:** `Admin@1234`
- **Field Electrician Login:** `electrician@sengotics.com` | **Password:** `Admin@1234`

### Annexure II: Officer Certification & Approval Block
*(To be signed by the competent municipal authority upon adoption into tender notification)*

```
Recommended for Approval:                            Approved & Sanctioned:


___________________________________                 ___________________________________
Junior Engineer / Assistant Engineer                Municipal Commissioner / Executive Officer
[Name of Local Body]                                [Name of Local Body]
Seal & Date:                                        Seal & Date:
```
