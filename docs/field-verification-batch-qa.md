# Field verification batch links — QA checklist

Use this after deploying the section-link + geotag upload feature.

## Prerequisites

- Tender with **3+ line items** linked to poles that have **latitude/longitude** in the database.
- Backend env: `FIELD_OCR_ENABLED=true` (default), optional `FIELD_MATCH_RADIUS_M=120`.
- Flutter web URL base configured (`WEB_APP_BASE_URL` / production domain).

## Officer — section links

1. Open tender → **Field verification** tab.
2. Click **Create section link** — enter name (e.g. "Section A"), select 2 poles, expiry 14 days.
3. Confirm link copied to clipboard; URL format: `{origin}/public/field/{token}`.
4. Create a second section with a different pole subset — tokens must differ.
5. **Copy all links** — clipboard contains name + URL per section.
6. Session cards show label, pole count, upload count, expiry.

## Field staff — public upload (mobile Chrome)

1. Open section link in incognito — see section name, work items, pole list for that batch only.
2. Upload a **GPS Map Camera** JPG (with `Lat …, Long …` overlay).
3. Success message: *"Image has been uploaded. Location matched to Pole #X …"*
4. Upload same image via **WhatsApp forward** (EXIF stripped) — overlay OCR should still read Lat/Long.
5. Upload with **manual pole** selected when overlay unreadable — manual match message.
6. Upload from location far from batch poles — upload saved, unmatched / officer review message.
7. Optional **notes** field appears on upload form and persists on server.

## Checklist and confirm

1. After confident match, checklist row for that pole shows match confidence + distance.
2. **Conflict** badge when tag OCR disagrees with GPS (if tag visible in photo).
3. Officer can tick/untick checklist manually.
4. **Confirm verification** blocked until all items done.
5. With `auto_resolve_linked_complaints`, confirm blocked on ambiguous/conflict matches.

## API smoke tests

- `GET /public/field-sessions/:token` returns `session.label`, `work_items[]`, `poles[]`.
- `POST /public/field-sessions/:token/uploads` returns `message`, `coord_source`, `matched_pole_id`.

## Regression

- Legacy route `/public/field/:token` still loads Flutter upload screen.
- Creating session without `pole_subset_ids` (API only) still defaults to all tender poles.
