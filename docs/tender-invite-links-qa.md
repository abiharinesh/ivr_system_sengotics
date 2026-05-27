# Tender Invite Links QA Checklist

## Setup
- Create a tender in `draft` with at least one line item.
- Add at least 2 vendors and invite them.
- Publish the tender.

## Admin-side copy link checks
- **Open mode:** header shows `Copy public link` → URL `<frontend-origin>/public/open/<publicToken>`.
- **Invite-only mode:** header shows hint “Per-vendor invite links — see Vendors tab”; no public link chip.
- **Vendors tab:** top card “Invite links (one per vendor)” lists each vendor with link icon; `Copy all` copies every link.
- Each vendor row: copy icon tooltip explains publish requirement when tender is still draft.
- Create a field session and verify copied URL format is `<frontend-origin>/public/field/<token>`.

## Public open-link flow (`/public/open/:token`)
- Open the public link in an incognito browser tab.
- Verify open-market UI loads (no vendor-specific invite banner).
- Submit with valid name, phone, amount and verify success.
- Re-submit with same phone and verify latest submission replaces prior one.
- Attempt too many submissions from same phone/IP quickly and verify throttle error is shown.

## Invite-only flow (`/public/invite/:token`)
- Open vendor invite link in incognito and verify invite-specific UI loads.
- Verify invited vendor details are pre-filled.
- Submit with valid amount and verify success.
- Submit with a different phone in the optional phone field and verify rejection.
- Close quotations from admin and verify invite link submission is rejected.

## Lifecycle and compatibility checks
- After quotation close, verify new open/invite submissions are blocked.
- Verify old legacy link (`/public/tenders/:token`) still opens read view.
- Verify invite token gets invalid after revocation events (`close-quotations`, `close tender`).
