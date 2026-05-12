# Panchayat tender-to-field verification — final specification

**Version:** 1.2  
**Scope:** Tender workflow, government-style PDF pack, public seller access, and geo field verification on top of the existing IVR / pole / complaint stack.

---

## 1. Purpose and scope

This document specifies the **end-to-end tender workflow** for Panchayat officers. A **tender** is the parent object for procurement. **Line items** may link to **electric poles** and/or **complaints** (e.g. street lights) or describe **free-text work** (e.g. pipeline, Anganwadi) without pole linkage.

The system shall support:

- **Tamil government-style PDFs** in correct procedural order (aligned with reference scans in `refer/`).
- **Rule-based milestone dates** (anchor, windows, offsets).
- A **public read-only tender link** for sellers, with optional self-service quotation submission.
- **Geo-tagged field verification** with photos matched to the **nearest pole** within a configured radius, reusing the same distance approach as complaint resolution proof.

**Baseline:** Existing backend includes Panchayats, poles with coordinates, complaints with lifecycle and resolution proof (EXIF, distance to pole). The **tender domain and PDF pipeline** are to be implemented per this specification.

**Note on `src/electrician`:** That module implements **`User` role `electrician`** (complaint assignment, job app, WhatsApp proof). It is **not** repurposed as tender vendors. Tender vendors use a separate **`Vendor`** model and a new **`src/vendor/`** Nest module (admin CRUD + public quote flows). The tender and field-verification flows **must not** require `electrician` login; field evidence uses **token links** as specified in §8.

---

## 2. Actors and responsibilities

| Actor | Responsibility |
|--------|----------------|
| **Panchayat office (officer)** | Create tender from work or complaints; set timeline rules; generate/regenerate PDFs with optional field overrides; publish **public tender link** and **field verification link**; confirm comparative award, work order, payment fields; review field evidence. |
| **Seller / contractor** | Open public tender link; submit quotation with **required phone** (+ name, amount, optional attachment) subject to tender **access mode**, **or** remain offline while the officer records the quote. |
| **Field staff** | Open **token-based verification link**; upload **geo-tagged** photos; system proposes pole matches for officer review. |

---

## 3. Full operational flow

### 3.1 Pole / complaint–driven path (primary)

1. **Complaint intake (existing)**  
   Citizen raises a complaint via IVR/voice; system links **pole** when known. Complaints remain in existing workflow until the office bundles them for procurement.

2. **Identify work to procure**  
   Officer filters **open complaints** (category, area, etc.), selects a set, and **creates a tender draft**. Line items may be **one per complaint** or **aggregated quantity** with `complaint_id` / `pole_id` links.

3. **Tender draft: scope, vendors, dates**  
   Enter work description (Tamil/English), select **vendors** from **vendor master** (and/or one-off rows), set **`quotation_access_mode`** (`invited_only` | `open_with_phone`), and **timeline rules** (anchor, quotation window e.g. 5–8 days, optional internal offsets such as −2/−5 days from deadline, short market-pricing window). The system **resolves milestone dates** (quotation due, internal checkpoints, work-order/completion targets as rules allow).

4. **Pre-award documents**  
   Generate **விலைப்புள்ளி கோருதல் (RFQ)** PDF. Officer may apply text overrides and regenerate. **Publish tender:** activate the **public token URL** for sellers.

5. **Quotation collection**  
   Sellers view the tender via the public link. **Self-service** submissions require **phone** (and name, amount, etc.); **`POST` is gated** by access mode (invited-only: phone must match an invited vendor; open: any phone, vendor stub upsert, rate limits). **Officer entry** from paper or WhatsApp always allowed. Generate **கொட்டேஷன்** PDF **per bidder**, with screening stamps (e.g. approved / rejected) where applicable.

6. **Comparative statement and award**  
   After the quotation deadline (or officer early close), generate **ஒப்பு நோக்கு பட்டியல் (comparative statement)** with all amounts and **L1 (lowest)** highlighted. Officer confirms **awarded vendor** → status **vendor selected**.

7. **Work order**  
   Generate **வேலை உத்தரவு (work order)** with awardee, work text, **completion deadline**, numbered conditions (supervision, stamp paper, etc.), and copy distribution list.

8. **Field verification**  
   Officer creates a **verification session** (token, expiry, optional **pole subset** = poles on this tender). Field staff upload images; server reads **EXIF GPS** and assigns **nearest pole** within radius → **matched / unmatched / ambiguous**. Officer reviews on a **tender field checklist** (required for completion). If tender flag **`auto_resolve_linked_complaints`** is on, **after officer confirms** field verification, linked complaints may be **bulk-resolved** with proof copied and guards (valid match or override, no ambiguous without override, audit log).

9. **Financial close**  
   Officer enters **payment metadata** (amount in figures and words, NK number, TNPASS/cheque references, resolution numbers if applicable). Generate **தனி அலுவலர் … நடவடிக்கைகள் (SO proceedings)** and **Form 19 செலவினச் சீட்டு (expenditure voucher)**.

10. **Tender closed**  
    All required PDFs generated and versioned; field evidence and pole/complaint state align with sign-off. Status **closed**; public tokens **expired** or retained **read-only** for audit.

### 3.2 Work without poles

The same tender and PDF sequence applies. **Pole matching** is omitted or limited to optional geography; line items use description, quantity, and unit only.

### 3.3 Flow summary

```
Complaints + poles → Tender draft (items, sellers, dates)
  → RFQ PDF → Publish public tender link
  → Quotations → Per-vendor quotation PDFs
  → Comparative (L1) → Award → Work order PDF
  → Field verification link → Geo photos → Nearest-pole match
  → Proceedings + Form 19 → Closed
```

---

## 4. Tender status machine

| Status | Meaning |
|--------|---------|
| `draft` | Editing; PDFs may be draft/regenerated. |
| `published` | RFQ issued; **public tender link** active. |
| `quotations_closed` | Collection ended by time or officer. |
| `vendor_selected` | Comparative done; awardee fixed. |
| `field_verification` | Verification link active; evidence under review. |
| `closed` | Financial documents complete; audit trail final. |

---

## 5. Date engine (milestones)

- **Anchor date:** e.g. publish date or RFQ issue date (configurable).
- **Rules as JSON** (examples):
  - `quotation_deadline = anchor + N days` (N from preset such as 5–8 or custom).
  - Internal checkpoints: e.g. from `quotation_deadline` with `offset_days: -2`, or from anchor `+5` days.
  - **Market / trend pricing window:** short window (e.g. 1–2 days) relative to anchor or deadline.
  - **Completion / receipt:** derived when **work order date** or vendor start is recorded.
- A **resolver** computes a **milestone map** (ISO dates). The UI shall surface **conflicts** (e.g. impossible ordering between two milestones).
- Durations and presets are **configuration**, not only hard-coded literals.

---

## 6. Document pack (procedural order)

All distinct form types implied by **`refer/`** scans shall be supported in order. Templates use Tamil-capable fonts (e.g. Noto Sans Tamil). Each generation may store **`field_overrides` JSON**; **versions** are retained for audit.

| Order | Document | Stage | Notable fields / behaviour |
|------:|----------|-------|----------------------------|
| 1 | **விலைப்புள்ளி கோருதல்** (RFQ) | Publish | Sender (panchayat/union), **பெறுநர்** list, work narrative, reply-within-X-days from date engine |
| 2 | **கொட்டேஷன்** (quotation letter) | Per bidder | From/to, subject, reference, work text, **total**, signature; **screening stamp** (e.g. rejected / approved) |
| 3 | **ஒப்பு நோக்கு பட்டியல்** (comparative statement) | Post–quote deadline | Columns per vendor, amounts, **L1** boilerplate, officer signature |
| 4 | **வேலை உத்தரவு** (work order) | Post-award | Tender/date/contractor refs, work description, **numbered conditions**, completion date, distribution list |
| 5 | **தனி அலுவலர் … நடவடிக்கைகள்** (SO proceedings) | Expenditure auth | NK number, date, bill/MB/resolution refs, amount figures + **words**, payee, TNPASS ref/date if used |
| 6 | **செலவினச் சீட்டு** (Form 19 expenditure voucher) | Payment | Serial, date, expense head, lines + total, certifications, cheque/TNPASS block, “Passed for Rupees …”, signatories |

**Technical notes:** HTML/CSS → PDF (e.g. Puppeteer) or vector PDF (e.g. pdf-lib) with embedded fonts; **derived** amount-in-words, L1 vendor, dates from Section 5; store `template_id`, `generated_at`, storage path, overrides; **regenerate** when tender data, quotes, award, or payment fields change.

---

## 6a. Vendor management and quotation access

- **`Vendor`** (scoped to Panchayat): name, **phone_e164** (required), place/village, optional notes, active.
- **`TenderVendorInvite`:** links `Tender` ↔ `Vendor` for **invited_only** mode; RFQ PDF recipient list uses invited vendors (plus optional display-only “suggested” vendors in open mode).
- **`Tender.quotation_access_mode`:**
  - **`invited_only`** — `POST /quotations` allowed only if body **phone** matches an invited vendor (normalized).
  - **`open_with_phone`** — any submitter with **phone + name**; create/link `Vendor` for new phones; **rate limit** (e.g. by IP + phone hash).
- **Officer** always records quotations in admin (offline bids).
- **Duplicate phone** on same tender: implement as **reject second** or **latest wins** (pick one in build; document in API).

---

## 7. Public tender API (sellers)

- **Token:** high-entropy, unguessable, issued on publish (pattern similar to existing resolution keys on complaints).
- **`GET /public/tenders/:token`** — read-only: tender metadata, line items, narrative, **computed dates**, **`quotation_access_mode`** (invited vs open), instructions. Do not leak other bidders’ PII.
- **`POST /public/tenders/:token/quotations`** — body: **phone (required)**, name, amount, remarks, optional file; enforce access mode and rate limits as per **§6a**.

---

## 8. Field verification

- **Session:** `FieldVerificationSession` — token, expiry, optional **pole ID subset** (tender-linked poles) or geographic filter.
- **Upload:** extract **EXIF GPS** (reuse field-ops proof patterns).
- **Algorithm:** candidate poles = tender-linked set (or panchayat poles in buffer); for each image coordinate, **nearest pole** within **default or tender-specific radius** (consistent with complaint resolution radius semantics); dedupe multiple images → same pole; persist `matched_pole_id`, `distance_meters`, `match_confidence` (`single_nearest` vs `ambiguous_two_within_radius`, etc.).
- **Officer dashboard:** **checklist** (per pole/line item), matched / unmatched / ambiguous lists, **manual reassignment**, action **Confirm field verification**.
- **Complaints:** **Checklist is mandatory** for tender completion. **`Tender.auto_resolve_linked_complaints`** (boolean): when true and officer confirms, **bulk-resolve** linked `Complaint` rows with best proof, lat/lng, `resolution_location_valid`, note with tender ref — **only if** guards pass (no ambiguous match without override; optional require valid geo flag). When false, complaints unchanged by this flow.

---

## 9. Conceptual data model

New entities (names illustrative):

- `Vendor` — panchayat_id, name, phone_e164, place, notes, active.
- `Tender` — panchayat scope, status, anchor, milestone rules JSON, public token, **`quotation_access_mode`**, **`auto_resolve_linked_complaints`**, metadata.
- `TenderVendorInvite` — tender_id, vendor_id (for invited_only).
- `TenderLineItem` — quantity, unit, description; optional FKs to `ElectricPole`, `Complaint`.
- `TenderQuotation` — vendor_id or ad-hoc name+phone, amounts, attachments, screening outcome.
- `TenderDocument` — template id, generated_at, storage path, `field_overrides`, version chain.
- `FieldVerificationSession` — token, expiry, pole scope.
- `FieldVerificationUpload` — image URL, EXIF lat/lng, match result fields.
- **`TenderFieldChecklistItem`** (or equivalent) — officer completion flags per pole/line item.

Reuse existing **pole** geometry; avoid duplicating coordinates.

---

## 10. Security and audit

- HTTPS; **rate limiting** on public quote and upload endpoints.
- **Audit log:** publish, award, override edits, PDF generations.
- **PII:** collect seller phone/email only if required; follow applicable retention rules.

---

## 11. Implementation order (recommended)

1. Prisma (or equivalent) models + **Vendor** + **TenderVendorInvite** + tender CRUD + line items + access mode flags (optional pole/complaint FKs).  
2. Milestone resolver + timeline JSON API.  
3. PDF pipeline in procedure order: RFQ → quotation → comparative → work order → proceedings → Form 19; storage + regenerate.  
4. Public `GET` tender by token; optional `POST` quotation.  
5. Field verification session + upload + pole matching + **checklist** + optional **complaint bulk-resolve** on officer confirm (existing geo distance helper).  
6. Admin UI: **vendor directory**, PDF checklist (stale/missing), zip download, layout parity with `refer/`.

---

## 12. Resolved decisions (this iteration)

1. **Quotations:** **Vendor master** + per-tender **`invited_only`** | **`open_with_phone`**; **phone required** on link form; officer offline entry always.  
2. **Field verification:** **Checklist always**; **`auto_resolve_linked_complaints`** optional per tender with **guards** and **officer confirm**.

---

**Document path:** `docs/tender-field-verification-spec.md`  
**Source plan:** Cursor plan *Tender-to-field verification flow* (repo context + `refer/` inventory).

---

## 13. Reconciliation against v1.1 (informational)

The earlier v1.1 draft of this spec is superseded by this v1.2 document with no behavioral changes. The reconciliation captures terminology and shape choices that v1.1 left open:

- **Quotation duplicates:** v1.1 said “handle duplicates”; v1.2 specifies **latest-wins** with `superseded_by_id` chain (§6a, also §10/§12 of the implementation plan). The prior submission is retained, marked superseded.
- **Officer self-inspection:** v1.1 implied a field upload was required; v1.2 makes uploads **optional** when `tender.officer_self_inspection = true`, with checklist `is_done + notes` accepted as proof for tenders that do not auto-resolve complaints.
- **Payment metadata:** v1.1 left `payment_meta` open; v1.2 codifies the JSON shape (`payment_method`, `voucher_serial`, `voucher_date`, `so_proceedings_date`, `payment_amount`, `tnpass_*` / `cheque_*`, etc.) anchored to the Sundaramoorthy worked example.
- **Voucher serial:** Auto-generated as `<count_in_panchayat_in_fy>/<fyShort>-<fyShortNext>` using the Indian fiscal year (Apr 1 – Mar 31). Officers may override.
- **PDF templates:** v1.1 listed five; v1.2 includes six — adding the per-bidder **quotation** letter so each invited vendor has an addressable artifact (`{ template_id: 'quotation', vendor_id }`).
- **Public token revocation:** Closing a tender clears `public_token` (link goes 404) but retains the `TenderDocument` history.

### 13.1 Implementation snapshot (v1.2 → code)

| Spec § | Lives at |
|--------|----------|
| §3 status machine | `src/tender/tender-status.ts` |
| §4 milestone rules | `src/common/milestone.util.ts`, `src/tender/milestone.service.ts` |
| §5 officer endpoints | `src/tender/tender.controller.ts` |
| §6 PDF templates | `src/tender/pdf/templates.ts`, `src/tender/pdf/pdf.service.ts` |
| §7 public seller flow | `src/tender/public.controller.ts`, `src/tender/public.service.ts` |
| §8 field verification | `src/tender/field-verification.service.ts` (+ public + admin controllers) |
| §9 audit | `src/tender/audit.service.ts` (+ writes from every other service) |
| §12 worked example | `src/common/milestone.util.spec.ts` (cadence) and the Flutter `tender_create_screen.dart` defaults |
