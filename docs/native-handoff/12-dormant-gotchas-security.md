# 12 — Dormant Features, Gotchas, Env & Security

## Dormant — schema/models with NO live code path (decide: drop or build)

| Item | State |
|---|---|
| `vehicle_type_reward_offers` table | Table only. No model/controller/view. Points math never reads it |
| `vehicle_types.reward_points_per_rupee` | Column only, never referenced |
| `customers.vehicle_number` | Legacy; only matched by admin customer search |
| `shift_cycles.period_days` | Column (default 1); rotation uses step durations instead |
| `shift_swaps` table + model | Full model with enum/validations; no route/controller/view |
| Attendance entry overrides (`overridden`, `last_overridden_*`) + `attendance_entry_changes` | Audit foundation; nothing writes or displays it; entries are immutable after save |
| `points_ledgers.entry_type = expire (2)` | Enum value + display label exist; nothing ever writes expiry rows (no points-expiry feature) |
| Redis / Action Cable / importmap / Stimulus | Configured or bundled but unused. Don't port |

## Known product gaps (design decisions needed for native)

1. **Password reset:** recoverable enabled but unreachable (no UI link; synthetic internal emails). Today: admin sets a new password. Decide: admin-reset only, or add OTP/SMS reset.
2. **Redemption concurrency:** no locking around balance check → double-redeem possible under parallel requests. Add a transaction + lock in the rebuild (04.2).
3. **Public lookup abuse:** only guard is the 2-minute signed token; no rate limiting on phone enumeration. Add throttling.
4. **No edit/void for transactions or redemptions:** corrections happen via manual points adjustments (signed adjust entries, no reason field). Consider a reason/audit field.
5. **Push is broadcast-only:** no per-user targeting; subscriptions aren't linked to users at all.
6. **CSV/PDF export:** dashboard "Download PDF" is just browser print.
7. **Attendance edits:** immutable entries; fix-by-invalidate-and-recreate. The dormant override/audit tables suggest a planned inline-edit feature — decide whether to build it.

## Environment variables (backend rebuild checklist)

Core: `DATABASE_URL`, `SECRET_KEY_BASE` (signs loyalty tokens!), `APP_URL` (mailer/asset/manifest links; or `APP_HOST` + `APP_PROTOCOL`), `MAILER_FROM`, `RELEASE_SHA` (cache versioning), `RAILS_SERVE_STATIC_FILES`.
Firebase/push: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` (or ADC), `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID`, `FIREBASE_MEASUREMENT_ID`, `FIREBASE_WEB_VAPID_KEY` (web), `PUSH_NOTIFICATION_LINK`, `ADMIN_NOTIFICATION_API_TOKEN`.
Plate scanner: `PLATE_RECOGNIZER_API_TOKEN`, `PLATE_RECOGNIZER_REGION` (default `in`), `PLATE_RECOGNIZER_API_URL` (optional).
CDN: `PUBLIC_BASE_URL`, `CLOUDFLARE_ZONE_ID`, `CLOUDFLARE_API_TOKEN`.
Vestigial: `REDIS_URL`.

## 🔴 Security actions before/during rebuild

1. **Rotate committed secrets.** `cloudbuild.yaml` hard-codes real values: `SECRET_KEY_BASE`, Supabase `DATABASE_URL` (with password), Firebase API key, `ADMIN_NOTIFICATION_API_TOKEN`, Plate Recognizer token, VAPID keys. `docker-compose.yml` and `docs/push-notifications.md` also embed a live Plate Recognizer token. Move to Secret Manager and rotate all of them.
2. Keep the cache boundary: `/loyalty/result`, `/admin`, `/staff`, `/users`, `/customers` and any authenticated response must never be edge/device cached.
3. Scheduler endpoint: keep constant-time token compare; Cloud Scheduler must send the bearer as a plain header (OIDC overwrites Authorization).
4. Preserve the last-admin guard, admin-undeletable rule, and soft-delete-requires-deactivate rule.
5. Loyalty tokens are signed but **not encrypted** — payload (phone) is readable if leaked; expiry is the protection. If you keep the pattern, keep it short-lived.

## Parity test checklist (verify the rebuild against these)

- ₹250 petrol, default settings → 4 pts; ₹99 → 0 pts; vehicle-type override 0 → always 0 pts; paused customer → 0 pts and **no ledger row**.
- Redeem: balance 420, min/incr 100 → max 400; 250 rejected ("must be in multiples of 100"); paused rejected; below-min rejected.
- Same plate under two customers → vehicle lookup returns both; wrong `vehicle_id`+number pairing rejected.
- Nozzle fuel-type mismatch rejected; nozzle mode with no My Pump rejected; pump mode ignores nozzles.
- Monthly schedule day 31 fires on Feb 28/29; once-schedule deactivates after send; second concurrent runner skips via lease.
- Attendance duplicate valid window rejected; cycle-misaligned window rejected; only invalid runs deletable; mark-valid blocked when the window got reused.
- Login works with username, email, and phone; inactive/soft-deleted rejected with the exact messages in 03.
