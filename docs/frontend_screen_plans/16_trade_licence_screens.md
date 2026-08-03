# Screen Plan 16: Trade Licence & Renewal

> **Backend Phase:** Phase 11 (Municipality-Specific Modules)
> **Target Audience:** Revenue Officers, Sanitary Inspectors, Health Officers, Licensing Clerks

---

## Why this module exists

Every shop, eatery, workshop and godown operating inside the local body's
limits needs a licence from it, and that licence has to be renewed every year.
For most town panchayats and municipalities this is the second largest own-source
revenue line after property tax, and unlike property tax it lapses silently —
an unrenewed licence produces no demand notice unless somebody runs the list.

This module exists to make that list run itself.

### Statutory basis

Trade licensing for local bodies in Tamil Nadu sits under the **Tamil Nadu
District Municipalities Act, 1920** (the "dangerous and offensive trades"
provisions, ss. 249–250), with equivalent powers for town panchayats and
village panchayats under their own enactments. Corporations operate under their
own city Acts.

> ⚠ **The specifics below are the model's defaults, not legal advice.**
> Licence categories, fee amounts and the penalty ladder are fixed by each
> body's council resolution and differ between corporations, municipalities and
> town panchayats. Before go-live for a client these must be replaced with that
> body's gazetted schedule. The implementation keeps them in one named constant
> for exactly this reason.

**Out of scope:** FSSAI food-safety registration is a *central* licence issued
under the Food Safety and Standards Act, 2006. A food business needs both, and
this module records the FSSAI number as a reference on the trade licence — it
does not issue or renew it.

---

## The lifecycle this module models

```
DRAFT → SUBMITTED → INSPECTION → APPROVED ⇄ (annual renewal)
                        ↓             ↓
                    REJECTED      EXPIRED → (renewed late, with penalty)
                                     ↓
                                 SUSPENDED / CANCELLED
```

### The licence year

The licence year runs with the **financial year — 1 April to 31 March** —
regardless of when the licence was first granted. A licence issued in November
still expires on 31 March, and the first year's fee is charged pro-rata by
completed quarters. This is why a licence cannot simply carry "valid for 12
months from issue".

### Renewal and the penalty ladder

| Window | Treatment |
|:---|:---|
| Renewed on or before 31 March | Ordinary fee |
| 1–30 days late | Ordinary fee + late penalty |
| 31–90 days late | Higher penalty band |
| Over 90 days late | Licence lapses; a fresh application is required, not a renewal |

Renewal is otherwise a light-touch action: the same trade at the same premises
under the same owner does not go back through inspection unless something
material changed, or the category is one that requires annual inspection.

---

## 1. Trade Licence Register (`/municipality/trade-licences`)

### Purpose
The working list. Every licence the body has issued, searchable by licence
number, trade name, owner, door number or survey number.

- **KPI strip:** Active licences · Expiring within 30 days · Lapsed & unrenewed · Fee collected this year
- **Filters:** Status, trade category, ward, "due for renewal", "inspection overdue"
- **Row:** Trade name and licence number, category chip, status pill, premises line, expiry with a countdown when inside 30 days, fee state
- **Bulk action:** Generate renewal notices for everything expiring in a chosen window — the single action that stops the silent-lapse problem

## 2. Licence Application Form (`/municipality/trade-licences/new`)

### Purpose
Intake for a new trade licence.

- **Applicant & ownership:** proprietor / partnership / private limited / society, with the authorised signatory when not the proprietor
- **Premises:** door number, street, ward, survey number, floor area, ownership (own / rented, with landlord consent reference when rented)
- **Trade:** category and sub-category, description, motive power in HP, worker count, operating hours
- **Statutory references:** FSSAI number, GST number, fire NOC, pollution board consent — recorded as references, each with its own expiry so a licence tied to a lapsed NOC is visible
- **Live fee preview:** category × area × motive power, with the pro-rata first-year calculation shown as a breakdown rather than a single number

## 3. Licence Detail (`/municipality/trade-licences/:id`)

### Purpose
The licence file, and every action on it.

- **Header:** trade name, licence number, status, expiry with a renewal countdown
- **Readiness panel:** what blocks approval or renewal — fee outstanding, inspection due, a statutory reference that has expired
- **Fee breakdown:** base, area component, motive power component, penalty if late — each line traceable
- **Inspection history:** scheduled and completed visits with findings and compliance
- **Renewal history:** every licence year, its fee, and what was paid — the register has to show a continuous chain, not just the current year
- **Certificate:** issued licence with a QR that verifies publicly, same pattern as birth/death certificates
- **Actions:** submit, schedule inspection, record finding, record payment, approve, reject, renew, suspend, cancel

## 4. Renewal Board (`/municipality/trade-licences/renewals`)

### Purpose
The revenue officer's working queue for the renewal season.

- **Three buckets:** expiring soon · overdue but renewable · lapsed beyond recovery
- **Per row:** what is owed including penalty, days late, last contact
- **Actions:** send renewal notice (WhatsApp/SMS via the notification engine), record payment, renew in one step when nothing has changed

## 5. Public Verification (`/public/verify-licence/:token`)

### Purpose
The target of the QR code printed on the licence displayed in the shop.

A citizen, a health inspector from another department, or a customer can scan
and see: trade name, licence number, category, premises, validity, and whether
it is current. Nothing else — no owner contact details, no fee history.

---

## Role access

| Role | Access |
|:---|:---|
| `licensing_clerk` | Intake, fee collection, renewal processing |
| `sanitary_inspector` | Inspections, findings, suspension recommendations |
| `health_officer` | All of the above, plus approval for food and offensive trades |
| `revenue_officer` | Renewal board, fee collection, defaulter reports |
| `municipal_commissioner` | Approval, suspension, cancellation |

---

## Platform subsystems used

| Subsystem | Use |
|:---|:---|
| `NumberGenService` | Licence numbers, financial-year scoped |
| `WorkflowService` | Approval chain; conditional routing on trade category and motive power |
| `SlaService` | Statutory decision window on a new application |
| `AuditService` | Every mutation, with before/after — licence disputes are common |
| `DocumentService` | Premises proof, NOCs, the issued licence PDF |
| `NotificationService` | Renewal notices |
