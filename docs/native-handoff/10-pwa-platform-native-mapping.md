# 10 — PWA/Platform Layer → Native Mapping

What the PWA does at the platform level, and what each behavior becomes natively.

## App identity (manifest)

`/manifest.json` (dynamic): name/short_name **"Ace Fuel Loyalty"**; icons `/icon.svg` (any), `/icon-192.png`, `/icon.png` (512); `start_url: "/loyalty?source=pwa"`; display standalone; `theme_color` = admin primary color (dynamic!); `background_color #F7FFF8`; lang en; categories business/productivity; shortcuts: "Loyalty Lookup" → `/loyalty`, "Staff Login" → `/users/sign_in`. Native: app name/icons from these assets; shortcuts → app shortcuts/quick actions (Loyalty Lookup, Staff Login).

## Service worker / offline → native caching

Web caching strategy (versioned caches, renamed per release via `RELEASE_SHA`):
- Static assets: cache-first. `/loyalty` navigation: network-first → cache → `/offline.html` fallback. All other navigations: network → offline page.
- **Never cached (hard denylist):** `/loyalty/result` and anything under `/admin`, `/staff`, `/users`, `/customers`; plus any response with `Cache-Control: private/no-store` (all authenticated pages). Cloudflare edge mirrors the same split (cache `/assets/*`, `/manifest.json`, `/loyalty`; bypass on session cookie/Authorization).
- OCR (Tesseract CDN) assets: cache-first in a dedicated cache.

Native mapping: cache the loyalty lookup shell + last successful balance (show with "last updated" stamp when offline); never persist authenticated/staff data beyond normal HTTP caching; show an offline state equivalent to `offline.html` (self-contained page, links back to loyalty). Keep the sensitive/cacheable boundary exactly.

## Install prompts → N/A (but keep the funnel)

Web has install CTAs on loyalty + login pages with per-OS manual instructions and a 9-event analytics funnel. Natively installation is the store's job — drop the UI, optionally keep analytics events for parity dashboards.

## Analytics contract

`POST /analytics/events` (no auth, CSRF-exempt) body `{"name", "page_path", "properties": {...}}` → 202. **Server whitelist: only these 9 names** (anything else 422): `pwa_install_cta_viewed`, `pwa_install_prompt_available`, `pwa_install_cta_clicked`, `pwa_install_manual_instructions_shown`, `pwa_install_prompt_shown`, `pwa_install_prompt_accepted`, `pwa_install_prompt_dismissed`, `pwa_install_completed`, `pwa_install_prompt_error`. Every payload also carries `standalone: <bool>`. If the native app needs its own events, extend the whitelist server-side. Client also mirrors to gtag/dataLayer/plausible when present.

## Theming & dark mode

- Server-driven primary color (ThemeSetting). Derived palette (compute natively the same way): `--fl-primary` = hex; `strong` = darken 14%; `accent` = lighten 18%; `soft` = rgba(primary, 0.14/0.18); `contrast` = luminance `((R×299)+(G×587)+(B×114))/1000 ≥ 150 ? #081E0F : #F7FFF8`; dark-mode primary = lighten 16% first.
- Static palette worth porting — light: bg `#f6f1e6`, surface `#fffaf0`, text `#251d12`; dark (warm): bg `#15120d`, text `#f5ead2`, primary `#6fd88a` (from default green). Font **Poppins** (Latin + Devanagari). Icons: Tabler set + 3 custom PNGs (tuk-tuk, pickup-truck, big-truck).
- Dark mode: user preference persisted, falls back to OS setting. Native: expose the same toggle (System/Light/Dark) and fetch theme color from the backend at launch (add a small `GET /api/theme` — currently the color is only embedded in HTML/manifest).

## Client behaviors worth replicating natively

- Debounced lookups at **300 ms**; race-guarded responses.
- Count-up animation 1100 ms + confetti on the points hero (respect reduced-motion).
- Phone inputs: digits only, cap 10.
- Lazy pagination: ledger/history pages of 5 with retry states.
- No polling/realtime anywhere — all refresh is user-triggered. Don't add sockets to the rebuild "for parity"; there is none.

## Infra notes (for the backend rebuild)

- Runtime: Docker on Cloud Run (port 8080), Cloud Build deploy with a migrate job; Supabase Postgres; Cloudflare in front; `RELEASE_SHA` versions caches/asset URLs.
- Redis + Action Cable are configured but **unused** (no channels, no consumer, redis gem commented out) — do not port.
- No ActiveJob jobs, no custom mailers (only Devise recoverable emails, `MAILER_FROM` env).
- Theme change triggers Cloudflare purge of `/loyalty`, `/loyalty?source=pwa`, `/manifest.json` (`Cdn::Purger`; env `PUBLIC_BASE_URL`, `CLOUDFLARE_ZONE_ID`, `CLOUDFLARE_API_TOKEN`; no-op if unset).
- Browser support gate + `useragent` gem: web-only concern, skip.
