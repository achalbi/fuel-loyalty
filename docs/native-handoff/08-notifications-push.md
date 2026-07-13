# 08 — Push Notifications (FCM)

Broadcast-only system: every message goes to **all active device tokens** (no per-user targeting, no topics). Two triggers: ad-hoc admin send and scheduled sends. Zero background infrastructure — an external cron (Cloud Scheduler) pings an HTTP endpoint every minute.

## Architecture

```
Admin UI ─ POST /admin/notifications/send ─┐
Admin UI / Cloud Scheduler (1-min cron,     ├─> FirebasePushService.broadcast(title, message)
  Bearer token) ─ POST /admin/schedules/run┘        │  FCM HTTP v1, one request per token
Device ─ POST/DELETE /push/subscriptions <──────────┘  (batches of 500, invalid-token cleanup)
```

## Device registration (keep this contract for native)

- `POST /push/subscriptions` — JSON `{"token": "<fcm-token>", "platform": "android|ios|desktop|web"}` → 201 (new) / 200 (existing), body `{id, active, platform}`; 422 when token missing. Upsert by token; reactivates.
- `DELETE /push/subscriptions` — JSON `{"token": "..."}` → 204. Deactivates.
- Current web client: detects platform by UA; stores token in localStorage; on token rotation DELETEs the old one then POSTs the new; explicit opt-out flag suppresses re-registration; permission-denied deactivates the stored token.
- **Native app:** get the FCM token via Firebase SDK (Android) / APNs-backed FCM (iOS), POST it with the real platform value, re-POST on token refresh, DELETE on logout/opt-out. The same backend then serves web + native uniformly.

## Delivery (FirebasePushService)

- Endpoint: `POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`, `Authorization: Bearer {OAuth token}` (service account `FIREBASE_SERVICE_ACCOUNT_JSON` or Application Default Credentials; scope `https://www.googleapis.com/auth/firebase.messaging`).
- Iterates `PushSubscription.active` ordered by id, **batches of 500** with one reused HTTPS connection per batch, 0.05 s sleep between batches, 15 s timeouts. FCM v1 has no multicast — one POST per token.
- Payload per token:

```json
{ "message": {
  "token": "<token>",
  "notification": { "title": T, "body": M },
  "data": { "title": T, "message": M, "link": "<PUSH_NOTIFICATION_LINK|/loyalty>", "notification_id": "<uuid>" },
  "webpush": {
    "headers": { "Urgency": "high", "TTL": "86400" },
    "notification": { "title": T, "body": M, "icon": "<APP_URL>/notification-pump-icon.svg", "badge": ".../notification-pump-badge.svg", "tag": "fuel-loyalty-broadcast" },
    "fcm_options": { "link": "<APP_URL>/loyalty" }
  }
}}
```

- Native: add an `android`/`apns` block instead of relying on `webpush`; keep `data.link` + `data.notification_id` so taps deep-link (current tap behavior: open/focus the link, default `/loyalty` → natively, the loyalty/home screen).
- **Invalid-token cleanup:** FCM error details with errorCode `UNREGISTERED` or `INVALID_ARGUMENT` → subscription deactivated. Success → `last_used_at` bumped.
- Result object: `{requested, sent, failed, invalidated, batches, errors[]}` — surfaced in admin flash messages and JSON.

## Scheduling

- Model + form semantics: 02 notification_schedules + 07.12. Due-time math (IST, weekly starts Sunday, month-end clamping, once auto-deactivates): 04.7.
- **Runner trigger:** `POST /admin/schedules/run` (admin session OR `Authorization: Bearer <ADMIN_NOTIFICATION_API_TOKEN>`). Production: Cloud Scheduler HTTP job every 1 minute with the bearer header (plain header — OIDC would overwrite Authorization). Responses: skipped (lease held) → "Scheduler run skipped because another run is already in progress."; 0 due → "No schedules are due right now…"; else "Scheduler run finished. {sent} schedules sent, {failed} failed."
- **Concurrency guard:** DB lease row (`scheduler_leases`, key `notification_schedule_runner`) with row-lock acquire, per-iteration heartbeat, 10-minute stale timeout — prevents double-sends across multiple app instances. Keep this (or an equivalent lock) in any rebuild with >1 server instance.
- `POST /admin/schedules/:id/send_now` sends immediately (updates `last_sent_at` only if something was actually sent; "No active device tokens…" when zero registered).

## Foreground behavior (current web → native)

Web: foreground FCM messages dispatch an in-page event and show a system notification via the service worker (tag = `notification_id` or `fuel-loyalty-broadcast`; tap focuses/opens the link). Native: show a local notification (or in-app banner) on foreground messages; background messages are handled by the OS. Notification icons: `/notification-pump-icon.svg` + badge variant — export as native notification assets.

## Config (env)

`FIREBASE_PROJECT_ID` (required to send), `FIREBASE_SERVICE_ACCOUNT_JSON` (or ADC), `FIREBASE_API_KEY / AUTH_DOMAIN / STORAGE_BUCKET / MESSAGING_SENDER_ID / APP_ID / MEASUREMENT_ID` (client config), `FIREBASE_WEB_VAPID_KEY` (web only), `PUSH_NOTIFICATION_LINK` (default `/loyalty`), `ADMIN_NOTIFICATION_API_TOKEN` (scheduler bearer), `APP_URL` (absolute asset links). Cross-project note: Cloud Run runs in one GCP project while Firebase is another — the runtime service account needs the "Firebase Cloud Messaging API Admin" role on the Firebase project (documented breakpoint). Full runbook: `docs/push-notifications.md` in the repo.
