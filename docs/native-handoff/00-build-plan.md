# Native Rebuild — Build Plan & Status

Living tracker for rebuilding Ace Fuel Loyalty as native apps. **Android first.**

## Session status (2026-07-13)

**Backend `/api/v1` — COMPLETE & verified** (Phases 2 & 4): full staff + admin surface, JWT auth, params normalized to nested `model[...]` (flat-compat). Runs locally on `:3007` (with `PLATE_RECOGNIZER_API_TOKEN` set → recognize_plate live).

**Android — COMPLETE build; compiles + assembles (~63MB APK):**
- Staff: loyalty, login, home, customers list+profile, New Transaction wizard, redeem, adjust — **smoke-tested on-device**.
- Admin: all 13 screens (dashboard w/ KPIs+bar charts, transactions, users, fuel types, vehicle types, pumps, reward rates, theme, staff, shifts, cycles, attendance, notifications/schedules) built as self-contained Nayara-styled verticals + wired into an **Admin menu** (role-gated on Home). **On-device verified** — Admin menu + Dashboard confirmed rendering live server data (customers/revenue/points KPIs) with working range/segment/fuel filters.
- **Plate scanner** (CameraX capture → `recognize_plate` server + ML Kit on-device fallback) wired into the New Transaction vehicle field. **On-device verified** — capture → downscale → server ALPR round-trip → structured result → Retake/Use states all confirmed.
- **FCM push** (programmatic Firebase init from the fuel-loyalty client config, `AceFuelMessagingService`, token registration to `/push/subscriptions` on login).
- Client requests normalized to nested envelopes.

**Phase 5 polish — DONE:**
- i18n — **DONE.** English base `res/values/strings.xml` (16 keys) + 10 translated locales (`hi kn ta te ml or bn mr gu pa`) under `res/values-<lang>/`, `res/xml/locales_config.xml`, and `android:localeConfig` on the manifest. `LoyaltyLookupScreen` refactored to `stringResource(...)`. Merges + builds clean.
- Offline cache of last loyalty balance ("last updated" stamp) — **DONE** (`LoyaltyCache` DataStore + offline banner).
- Adaptive launcher icon + splash — vector adaptive icon (`ic_launcher` / `ic_launcher_round`) in place.
- Release signing config — `signingConfigs` reads `keystore.properties`; needs a real keystore to sign. R8 minify deferred (`isMinifyEnabled=false`) until keep-rules are validated.

**Scanner reliability fix (this session):** raw full-res sensor JPEG (4.6–5 MB, verified from Rails log base64 length) was base64-encoded straight to upload → PlateRecognizer's 3 MB cap rejected it with **413**, and on a stale tunnel it timed out at the 10s OkHttp default → surfaced as "Couldn't reach the server" / "status 413". Fixed by (a) downscaling the capture to ≤1600px long-edge + JPEG q80 + EXIF rotation before upload (payload now ~200–500 KB, EXIF stripped — verified in log) and (b) a dedicated `plateRetrofit` with a 45s call/read/write timeout. **Positive recognition verified end-to-end on-device**: pointed the camera at a rendered `KA 01 AB 1234` plate → server ALPR returned 200 `KA01AB1234` in ~4.2s → auto-filled the New Transaction vehicle field → auto vehicle lookup (404, made-up plate). Two deploy gotchas hit: a concurrent rebuild can clobber the installed APK (check `dumpsys package … lastUpdateTime` after install), and the `UsbFfs` adb-reverse tunnel silently stops forwarding after the phone idles even though `adb reverse --list` still shows it (re-add with `--remove-all` + `reverse tcp:3007 tcp:3007`).

**Server-side FCM send — WIRED & VERIFIED END-TO-END (this session):** `POST /api/v1/admin/notifications/send` → `FirebasePushService.broadcast` → FCM HTTP v1 was already implemented; the real gaps were in registration + config, now fixed:
- **CSRF (the blocker):** `PushSubscriptionsController` inherits the web `ApplicationController`, so the native app's cookieless JSON POST hit `InvalidAuthenticityToken` → 422 → zero tokens ever registered. Fixed with `skip_before_action :verify_authenticity_token` (endpoint only carries an FCM token; the web PWA still sends its CSRF token fine).
- **Optional platform:** kotlinx.serialization (`encodeDefaults` defaults to false) drops the `platform` default `"android"`, so the client actually POSTs just `{"token":…}`; the controller's `.fetch(:platform)` then 422'd. Made `platform` optional (`subscription_params[:platform]`); the model coerces blank → `"unknown"`. (Native subs therefore record `platform="unknown"` — optional client fix below to send it explicitly.)
- **Android delivery block:** added an `android: { priority: "high", notification: { channel_id: "fuel_loyalty_broadcast", … } }` block to the FCM payload so notification-messages wake dozing/frozen apps (ColorOS HANS froze the app in background) and display on a valid channel.
- **Config:** server needs `FIREBASE_PROJECT_ID=fuel-loyalty` (from cloudbuild `_FIREBASE_PROJECT_ID`). Credentials come from `FIREBASE_SERVICE_ACCOUNT_JSON` **or** ADC — locally the machine's gcloud ADC is authorized to send to `fuel-loyalty` (verified). In prod, cloudbuild sets `FIREBASE_PROJECT_ID` and the Cloud Run runtime service account provides ADC — no explicit key committed. Dev server must be launched with `FIREBASE_PROJECT_ID=fuel-loyalty` set (no dotenv gem).
- **Verified:** relaunched app → real token registered (201, token len 142), enabled app notifications (ColorOS blocks `pm grant`/`appops set` → toggled via Settings UI), sent broadcast → `{"requested":1,"sent":1,"failed":0}` → device showed the heads-up notification (title + body + sound, `fuel_loyalty_broadcast` channel).

- **Client platform fix — DONE & deployed:** removed the default from `PushSubscriptionRequest.platform` (was `= "android"`) so kotlinx always serializes it (a default-valued field is otherwise dropped). Rebuilt + reinstalled; verified the client now POSTs `platform=android` and the sub records `platform="android"` (was `"unknown"`), with the end-to-end broadcast still delivering the heads-up notification.

**Remaining / optional:**
- Minor: give the plate OkHttp client an explicit `connectTimeout` (currently inherits the 10s default) so a dead tunnel fails fast/coherently rather than at the connect-timeout boundary.
- ColorOS aggressively freezes backgrounded apps; reliable background push on such OEMs needs the app battery-optimization-exempted (the `android` high-priority block helps but isn't a guarantee on all Chinese OEM skins).

## Locked decisions

| Decision | Choice |
|---|---|
| Android stack | **Kotlin + Jetpack Compose** (native) |
| Backend API | **Add `/api/v1` JSON + JWT auth to this Rails app**, reusing existing models/services |
| Target scope | **Full parity** (public loyalty + staff + admin) |
| Repo layout | Monorepo — Android app under [`android/`](../../android); Rails API in-place |

## Toolchain (verified building + running on device)

- **Android:** AGP 9.2.1 · Gradle 9.5.0 · Kotlin 2.2.10 (AGP built-in Kotlin — do **not** apply `kotlin.android`) · Compose BOM 2024.12.01 · compileSdk/targetSdk 36 · minSdk 26 · JDK 21.
- **Device:** wireless-adb Realme RMX3868, Android 16 (API 36), arm64.
- **Backend:** Ruby 3.3, Rails 8.1.2, PostgreSQL 16 (local via Homebrew), `jwt` gem.

### Run the backend (local dev)
```bash
brew services start postgresql@16
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export DATABASE_URL="postgres://achalindiresh@localhost:5432/fuel_loyalty_development"
bundle install
bin/rails db:prepare db:seed      # creates DB, loads schema, seeds admin/staff
bin/rails server -p 3007 -b 127.0.0.1
```
Seeded logins: `admin` / `password123`, `staff` / `password123` (also resolvable by phone `9000000001` / `9000000002`).

### Build & run the Android app
```bash
cd android
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
./gradlew :app:installDebug      # builds + installs on the connected device
```
> Gradle must write to `~/.gradle` and read `~/.android` — run outside the restrictive sandbox.

## API design conventions

- Base: `Api::V1::BaseController` (`ActionController::API`) — bearer auth, Pundit, uniform error envelope
  `{"error":{"code","message","details?}}`. Public endpoints extend `Api::V1::PublicController`.
- Auth: stateless JWT (`Api::TokenService`) — access 30 min, refresh 30 days, HS256, key derived from
  `secret_key_base` (override `API_JWT_SECRET`). Revocation not yet modelled (logout = client discard).
- Services reused as-is (`TransactionCreator`, `PointsRedeemer`, `PointsCalculator`, …) — they raise
  `ActiveRecord::RecordInvalid`; the base controller serializes `record.errors` to 422.
- Reference for exact rules/strings/shapes: [`backend-map/`](backend-map/README.md).

## Phase plan

### ✅ Phase 0 — Foundations (DONE)
- [x] Map the Rails backend → `backend-map/` (14 subsystem specs).
- [x] Android scaffold (Compose, theme seed, brand icon) — builds, installs, runs on device.
- [x] Rails `/api/v1` + JWT: `TokenService`, base/public controllers, error envelope.
- [x] Auth endpoints: `POST auth/login`, `POST auth/refresh`, `DELETE auth/logout`, `GET auth/me`.
- [x] Public endpoints: `GET theme`, `POST loyalty/lookup`. All verified end-to-end via curl.

### 🟡 Phase 1 — Android data layer + first live slice (code complete; compiles)
- [x] Deps: Retrofit + OkHttp + kotlinx.serialization (self-written `KotlinxJsonConverterFactory` — the 2023 JakeWharton converter's ABI is unreadable by Kotlin 2.2.10), DataStore, Navigation-Compose, lifecycle-viewmodel/runtime-compose, material-icons-extended. **Manual DI** (`ServiceContainer` + `LocalContainer`), not Hilt yet (avoids KSP on the bleeding-edge toolchain).
- [x] `AceFuelApi` (Retrofit), `AuthInterceptor` (bearer), `TokenAuthenticator` (transparent refresh on 401), `TokenStore` (DataStore + in-memory mirror), `AuthRepository`/`LoyaltyRepository`/`ThemeRepository`, `apiCall` → `ApiResult` error mapping.
- [x] Theme fetched from `/api/v1/theme`; `BrandPalette` derived per doc 10; light/dark via `AceFuelLoyaltyTheme`.
- [x] Public **Loyalty Lookup** screen (phone form, animated count-up, status copy, expandable activity rows) wired to `POST /api/v1/loyalty/lookup`.
- [x] Staff **Login** screen wired to `auth/login`; startup session bootstrap (`auth/me`); `HomeScreen` + logout; reactive nav.
- [x] `assembleDebug` **BUILD SUCCESSFUL**.
- [x] **Live on-device round-trip — VERIFIED** on the physical RMX3868 (USB + `adb reverse tcp:3007 tcp:3007`, base URL `http://localhost:3007/`, `ANDROID_SERIAL=WSYHNVMBDAJJ6PNR`). App fetched theme live, drove loyalty lookup → 200, rendered **Total Points 434** + correct "Rewards unlocked" status. (The bundled emulator is unusable — incomplete SDK image, missing `kernel-ranchu`; use the physical device.)

### 🟡 Phase 2 — Backend API: staff + admin bases (in progress)
- [x] `Api::V1::Staff::BaseController` (staff/admin gate) + `GET staff/customers/lookup` (customer object on 200, envelope on 422/404) + `POST staff/redemptions` (reuses `PointsRedeemer`). Curl-verified: auth 401, lookup 200/422/404, redeem 201 (persisted 504→404) + `"must be in multiples of 100"` 422.
- [x] `Api::V1::Admin::BaseController` (admin-only gate — **unblocks the whole admin surface**) + `POST admin/points_adjustments` (signed `adjust` ledger). Curl-verified: staff→403, admin +50/−20 apply, zero→422, unknown→404.
- [x] **Android screens (compile):** Redeem Points (phone lookup → customer card → increment-stepped picker → redeem) and Adjust Points (admin-only on Home, signed input). Wired into nav from `HomeScreen`.
- [x] **Customer search/index + profile read (VERIFIED on-device):** `GET staff/customers` (top-by-points / search), `GET staff/customers/:id` (hero + vehicles + recent txns), `GET :id/ledger` (paginated), `PATCH activate/deactivate/pause_rewards/resume_rewards`. Android Customers list + profile screens driven live on the RMX3868 — rendered 434 pts, vehicle, ₹250 txn, color-coded ledger. **Bug found & fixed:** LazyColumn key collision across sections (vehicle/txn/ledger all id `1`) → namespaced keys.
- [x] **My Pump + Transaction backend (VERIFIED via curl):** `GET/PATCH /api/v1/my_pump` (pump catalog + assignment, `ready` flag), `GET staff/transactions/lookup` (all plate matches + customers), `POST staff/transactions` (`TransactionCreator`). Verified: My Pump ready-toggle, lookup, ₹300 petrol create → +6 pts / total 440 / Pump 1·Nozzle 1, unassigned-nozzle guard → 422.
- [x] **Android New Transaction wizard UI (VERIFIED on-device):** 3-step Find→Matching customer→Fuel details, Vehicle+Phone modes, auto-select on single match, My-Pump nozzle picker filtered by fuel type, Cash/Credit, blockers (inactive/pump-not-ready/no-nozzle), success card. Smoke-tested on the RMX3868: plate lookup → auto-select → ₹400 petrol → **+8 pts, balance 448**, `POST /staff/transactions` 201.
- [x] **Customer + vehicle CRUD (VERIFIED):** `POST staff/customers` (create + initial vehicle), `PATCH staff/customers/:id` (name/phone), nested `vehicles` create/update/destroy. Verified: create 201 / missing-fields 422, add/edit vehicle, delete 200 (free) vs **409** (has txns), rename.
- [x] **Password change** `PATCH /api/v1/password` (wrong-current 422, change 200 + re-login) and **`recognize_plate`** proxy (503 unconfigured path) — verified.
- [x] Ran `update_theme_default_to_nayara` migration (backend theme default → navy `#1D63B0`, added by the design migration).
- [x] `register_customer` (inline customer+vehicle during txn) — verified ("Customer created successfully.").
- [ ] CameraX + ML Kit on-device plate capture (client side of `recognize_plate`) — needs device camera + not started.

### ✅ Phase 4 — Backend API: admin surface (COMPLETE, verified)
Built via a 10-agent fan-out, routes merged, all curl-verified as admin (staff → 403 gate):
- [x] `GET dashboard` (reuses `Admin::Dashboard::OverviewReport`), `GET transactions` (filters/sort/paging).
- [x] `users` CRUD (last-admin guard, kept scope). `fuel_types` / `vehicle_types` / `fuel_pumps` CRUD (+ `feature_settings` nozzle toggle; delete→409 when in use).
- [x] `reward_rates` show/update (3 param groups), `theme_settings` show/update.
- [x] `staff_members` (index/update/soft-delete) + `shift_templates` + `shift_cycles` (+activate/deactivate) + nested `shift_assignments`; `attendance_runs` (index/new-planner/create/show/invalidate/mark_valid/destroy, reuses `AttendanceRosterBuilder`).
- [x] `schedules` CRUD + `send_now` + `schedules/run` (runs `NotificationScheduleRunner`, 200); `notifications/send` (422 when FCM unconfigured — expected).
- [x] Renamed the `notifications#send` action → `#deliver` (avoids shadowing `Object#send`).

- [x] **API param convention NORMALIZED to nested `model[...]` (verified both shapes).** `Api::V1::BaseController` now sets `wrap_parameters false` + a `resource_params(*keys)` helper: canonical shape is nested `model[...]` (doc-11 / web), with flat top-level tolerated as a compat fallback so the on-device-verified flat staff flow keeps working. Every controller converted (via a 9-agent fan-out). Re-verified: nested 200/201 for loyalty/redeem/adjust/user/fuel_type/shift_template(virtual duration)/theme/fuel_pump(nested nozzles); flat still 200/201 for loyalty/redeem/adjust/lookup.

### 🟢 Concurrent: Nayara design-system migration
A parallel effort is migrating all Android UI to a Nayara token set (`docs/design/design-tokens.json`, `ui/theme/Nayara*.kt`, `NayaraButton`/`MaterialTheme.nayara`) + the `update_theme_default_to_nayara` backend migration. Per direction, I'm leaving all UI/theme files to it and building backend only.

### ⬜ Phase 3 — Android: staff app
- [x] New Transaction wizard (3 steps, both lookup modes), Redeem, Customers, Customer profile, My Pump, Notifications, Change Password.
- [x] CameraX + ML Kit plate scanner (replaces Tesseract; keeps `recognize_plate`) — verified on-device.
- [x] FCM push (register token, deep-link taps).

### ✅ Phase 4 — Backend API: admin surface (COMPLETE, verified)
- [x] Dashboard data JSON, users, staff/shifts/cycles/attendance, catalogs (fuel types/pumps/vehicle types), reward rates, theme write, schedules + run/send, points adjustments, transactions list.

### ✅ Phase 5 — Android: admin app + polish (COMPLETE)
- [x] Admin dashboard (charts), all admin management screens.
- [x] i18n (11 locales, ported tables), offline last-balance cache, app icons/splash, release signing config.

## Known gaps to design (from doc 12)
Password reset story · redemption concurrency lock · public-lookup rate limiting · transaction/redemption audit · JWT revocation. Track and decide before launch.
