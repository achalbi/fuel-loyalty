# 01 — Overview & Architecture

## What the app is

A single-station fuel loyalty system with three user surfaces:

1. **Public (no login):** `/loyalty` — a customer enters their 10-digit phone number and sees their points balance and recent activity. This is the entire customer-facing product.
2. **Staff (login):** record fuel transactions (with plate scanning), redeem points, register/manage customers and vehicles, self-assign a pump ("My Pump"), enable device notifications.
3. **Admin (login):** everything staff can do, plus analytics dashboard, user management, staff shift/cycle/attendance management, fuel/vehicle/pump catalogs, reward configuration, theme, push notification schedules, manual points adjustments, transaction listing, customer deletion.

## Current tech stack (what you're replacing)

| Layer | Current | Notes for native rebuild |
|---|---|---|
| Backend | Rails 8.1.2, Ruby 3.3.10, PostgreSQL, Puma (port 8080), Thruster | Rebuild freely; keep the data model + business rules in 02/04 |
| Auth | Devise (sessions + cookies), Pundit policies | Native app needs token-based auth (see 03) |
| Frontend | Server-rendered ERB + Bootstrap 5 + Tabler icons + Turbo Drive | No SPA framework. **No Stimulus** despite the gem being present |
| Client JS | 4 vanilla-JS files: `application.js` (~1800 lines), `vehicle_plate_scanner.js`, `admin_dashboard.js`, `theme_boot.js` | All behaviors documented per-screen in 05–07 |
| PWA | Manifest + service worker + FCM web push + install prompts | Mapping to native in 10 |
| Fonts/icons | Poppins (self-hosted, Latin + Devanagari), Tabler Icons | |
| Deploy | Docker → Google Cloud Run (`us-central1`), Cloud Build, Supabase Postgres, Cloudflare CDN | |
| Background work | **None.** No Sidekiq/cron/ActiveJob. Scheduler is an HTTP endpoint hit by Cloud Scheduler every minute | See 08 |
| Realtime | **None.** Action Cable/Redis configured but unused. No polling anywhere | Don't port |

## Roles

Exactly two authenticated roles (`users.role` enum): `admin: 0`, `staff: 1` (default staff). Customers are **not** users — they are records looked up by phone; they never log in.

## Root routing

`GET /` redirects: signed-in admin → `/admin/dashboard`; signed-in staff → `/staff/transactions/new`; anonymous → `/loyalty`.

## App shells & navigation

Two layouts switched on sign-in state:

**Public shell** (`/loyalty`, Devise pages): white navbar with brand → `/` and a "Staff Login" button → `/users/sign_in` (navbar hidden on Devise pages). Centered card content.

**Signed-in shell:**
- **Fixed top bar:** hamburger (mobile) toggles sidebar; right cluster: plate-scanner camera button (opens scanner on the transaction page, else links to `/staff/transactions/new?plate_scanner=1`), New Transaction icon, Loyalty Lookup icon, role badge ("Admin"/"Staff"), avatar dropdown (name, `+91` phone or "Mobile not set", mobile-only theme + sidebar-mode switches, "Change Password" → `/password/edit`, "Logout" → DELETE `/users/sign_out`).
- **Left sidebar** (240px, collapsible to 60px icon rail; off-canvas <992px):
  - Staff — section "Operations": New Transaction, Customers, Redeem Points, Notifications.
  - Admin — sections Admin / Attendance / App Management: Dashboard, Users, Customers, Transactions, Fuel Types, Pumps, Vehicle Types, Reward Rates, Redeem Points, Adjust Points, Staff, Shifts, Cycles, Attendance, Notifications, Theme.
  - Both roles — trailing section "Access": Loyalty Lookup, My Pump.
- **No bottom nav bar.**

## Global UI conventions (replicate once, reuse everywhere)

- **Flash messages:** `notice` → green success alert; anything else → red danger alert, rendered at top of content.
- **Phone inputs:** always a fixed `+91` prefix addon; input strips non-digits, hard-capped at 10 digits; custom validity message "Enter a 10 digit phone number." Only the 10 local digits are stored.
- **Destructive confirms:** two patterns — (a) native confirm (Turbo `data-turbo-confirm`) for pause/deactivate-type actions; (b) a shared confirm modal for deletes ("Remove this customer?", "Remove this vehicle?", etc.). Native: use a standard destructive-action dialog.
- **Validation-failure modals:** when a form inside a modal fails server validation, the page re-renders (HTTP 422) with that modal auto-opened and errors listed (`errors.full_messages` joined). Native: keep the sheet/dialog open and show inline errors.
- **Lazy panels:** points ledger and transaction history load as HTML fragments on first expand, with spinner + "Try again" retry. Native: paginated API calls on first open.
- **Radio "pill" groups:** fuel type / vehicle type / payment mode / pump / nozzle pickers are Bootstrap `btn-check` pill groups, first option carries `required`; empty state alert when no active options exist.
- **Dark mode:** full dark theme. Selection order: saved preference (`localStorage["fuel-loyalty-theme"]`) → OS `prefers-color-scheme`. See 10 for palettes.
- **Theming:** admin-set primary color propagates to all UI via CSS variables (`--fl-primary` family); native should fetch theme from the backend (see 07 Theme + 10).
- **Empty states:** every list has explicit empty-state copy (documented per screen).
- **Currency:** `₹` with 2 decimals for values < 100, else 0 decimals (dashboard); transaction amounts show 2 decimals.
- **Dates:** "dd Mon YYYY · hh:mm AM" style timestamps; short date format elsewhere.

## Key request-level behaviors

- Every authenticated response sends `Cache-Control: private, no-store`. Public/PWA pages override with public cache headers (see 10).
- Unsupported browsers get a static 406 page (min: Safari 16.4, Chrome 120, Firefox 121, Opera 106, Samsung Internet 24; IE blocked; bots allowed) — irrelevant to native, but the backend gate exists.
- Unauthorized (Pundit) → redirect `/` with alert **"You are not authorized to perform that action."**
