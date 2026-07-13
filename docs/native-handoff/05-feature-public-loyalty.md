# 05 — Public Loyalty Lookup (customer-facing)

The only surface customers ever see. No login, no account. In the PWA this is the start URL (`/loyalty?source=pwa`); in the native app it should be the default (unauthenticated) home screen.

## Internationalization

11 locales: en, hi (Hindi), kn (Kannada), ta (Tamil), te (Telugu), ml (Malayalam), or (Odia), bn (Bengali), mr (Marathi), gu (Gujarati), pa (Punjabi). Resolution: `?lang=` param → persisted cookie `loyalty_language` (permanent) → `en`. A language `select` (top-right, label "Language") auto-submits on change. Native: persist language choice locally; translation tables live in `config/locales/loyalty_pages.rb` + `loyalty_shared.yml` — port them wholesale. All copy below is the `en` set.

## Screen 1 — Lookup form (`GET /loyalty`)

Centered card:
- Brand lockup, heading **"Loyalty Lookup"**, subtitle "Enter your mobile number to view your current loyalty points and recent visits."
- One field: **Phone number** — `+91` prefix addon, numeric keypad, required, maxlength 10, pattern `\d{10}`, validity hint "Enter a 10 digit phone number".
- Submit: **"Check Points"** (full-width, primary).
- **PWA install panel** (source `loyalty_page`) — N/A natively (see 10).
- **Push opt-in panel** (only when web push configured): title "Enable Loyalty Alerts", "Optional" badge, Enable/Disable buttons — natively this becomes the OS notification-permission prompt + `/push/subscriptions` registration (see 08).
- Public/anonymous shell is CDN-cacheable (see 10); irrelevant natively except: the POST is **CSRF-exempt** so cached shells can submit.

## Flow — submit (`POST /loyalty`, param `loyalty[phone_number]`)

- Normalize to digits. Not 10 digits → re-render form, error **"Phone number must be a 10 digit number."** (HTTP 422).
- Valid → mint signed lookup token (2-min expiry, see 04.5) → redirect `GET /loyalty/result?lookup_token=…` (+ `lang` if non-default).

## Screen 2 — Result (`GET /loyalty/result?lookup_token=…`)

Guards:
- No token → redirect to form, alert **"Enter your phone number to continue."**
- Invalid/expired token → redirect, alert **"That lookup link has expired. Please enter your phone number again."**
- Token OK but no matching customer → re-render form, error **"No customer found for that phone number."** (422).

On success (token silently rotated for any follow-up links):

1. **Hero card:** "Total Points" with an animated count-up (1100 ms, cubic ease-out) + confetti/firework burst (skipped under reduced-motion). Status line beneath:
   - rewards paused → "Rewards are currently paused for this customer. Please contact station staff."
   - `max_redeemable ≥ minimum` → "Rewards unlocked: {max_redeemable} points. Minimum redemption: {minimum} points."
   - else → "{points_until_redeemable} points more to unlock rewards. Minimum redemption: {minimum} points."
2. Customer name (titleized) + "Phone: {10 digits}".
3. **"Last 5 Loyalty Activities"** — ledger rows where entry_type ∈ {earn, redeem}, newest first. Each row is expandable: collapsed = date (short format) + signed points (`+N` green / `−N` red); expanded = fuel badge (P/D/C initial by fuel type), "Vehicle: {number|N/A}", "Fuel Amount: ₹{amount|N/A}". Empty state: "No loyalty activity found."
4. **"Show Full History"** button appears only when > 5 activities (`?full_history=1`), toggles to "Show Last 5".

Deliberately NOT shown: cash value, redeem button, transaction IDs, staff/pump info. Redemption is staff-operated only.

## Native rebuild notes

- Replace the token round-trip with a direct API call (e.g. `POST /api/loyalty/lookup {phone}` returning the payload above), but keep equivalent abuse protection: short-lived result validity, and consider rate limiting by phone/IP — the current design's only guard is the 2-minute token.
- Keep the count-up + celebration animation; it's a core delight moment (respect reduced-motion).
- Offline: the PWA caches this page shell for offline display with an offline fallback page; native should cache the last-known balance with a "last updated" stamp (see 10).
