# 03 — Auth, Roles & Permissions

## Authentication (current: Devise sessions)

- Modules: `database_authenticatable`, `recoverable`, `rememberable`, `validatable`. **No** registration, confirmation, lockout, or session timeout.
- Password: bcrypt, length 6–128.
- **Login field accepts three identifiers** (UI label says "Username" but matches case-insensitively): `LOWER(username)`, `LOWER(email)`, or `phone_number` (input normalized to digits) — scoped to non-soft-deleted (`kept`) users.
- Sign-in screen: single "Username" field (helper: "Use your username to continue."), password field, "Remember me" checkbox (2-week cookie; all remember-me tokens expire on sign-out), "Sign In" button, "Back to Loyalty Lookup" link, PWA install panel. **No forgot-password link, no sign-up.**
- Failure messages: bad credentials → **"Invalid Login or password."**; inactive/soft-deleted → **"Your account is inactive or has been removed."** (`active_for_authentication?` = `active && !soft_deleted`).
- Post-login landing: admin → `/admin/dashboard`; staff → `/staff/transactions/new`.
- **Password reset is effectively dead:** recoverable is enabled (`reset_password_within` 6h) but there's no UI link, and phone-created users have synthetic internal emails (`user-{digits}@users.fuel-loyalty.local`), so email reset can't work. In practice admins reset passwords via user edit. **No forced/first-login password change exists.**
- Change password (self-service, `/password/edit`): current password + new + confirmation via `update_with_password`; session preserved (`bypass_sign_in`); success notice "Password updated successfully."; redirects to role home.

### Native-app recommendation

Replace cookie sessions with token auth (e.g. short-lived JWT + refresh) but keep the same credential resolution (username/email/phone + password) and the same active/soft-delete gates. Design an explicit password-reset story (admin reset or OTP) — the current one is a known gap.

## Soft delete (users only)

`soft_delete!`: rejected if the user is an admin ("Only staff accounts can be soft deleted") or still active ("User is in active state. Deactivate before soft deleting"). Sets `active: false, deleted_at: now`. Soft-deleted users are excluded from all queries (`kept` scope) and cannot authenticate. Customers are never soft-deleted — they use `active`/`rewards_paused` flags; hard delete is admin-only and blocked while transactions exist.

## Permission matrix (Pundit; deny-by-default)

"staff_access" = admin OR staff (any authenticated user is one of the two, so effectively "signed in", but checks are explicit).

| Capability | Public | Staff | Admin |
|---|---|---|---|
| Loyalty lookup (`/loyalty`) | ✅ | ✅ | ✅ |
| View customer profile (`customers#show`, ledger, history) | ❌ | ✅ | ✅ |
| Create/update customer; activate/deactivate; pause/resume rewards; lookup JSON | ❌ | ✅ | ✅ |
| **Delete customer** | ❌ | ❌ | ✅ |
| Vehicle create/update/delete (under a customer) | ❌ | ✅ | ✅ |
| Record transaction (new/create, lookups, plate recognize, inline register) | ❌ | ✅ | ✅ |
| **List all transactions** | ❌ | ❌ | ✅ |
| Redeem points | ❌ | ✅ | ✅ |
| **Manual points adjustment** | ❌ | ❌ | ✅ |
| My Pump (self pump/nozzle assignment) | ❌ | ✅ (own record only) | ✅ (own record only) |
| Staff notifications page; push subscribe/unsubscribe | ❌ (subscribe is public) | ✅ | ✅ |
| Admin dashboard + data JSON | ❌ | ❌ | ✅ |
| Users CRUD (no hard delete; soft-delete staff only) | ❌ | ❌ | ✅ |
| Staff members, shift templates/cycles/assignments, attendance runs | ❌ | ❌ | ✅ |
| Fuel types / fuel pumps (+ nozzle feature toggle) / vehicle types | ❌ | ❌ | ✅ |
| Reward rates + reward settings; theme settings | ❌ | ❌ | ✅ |
| Notification schedules CRUD/run/send_now; ad-hoc send | ❌ (or Bearer token — below) | ❌ | ✅ |
| Analytics event ingest (`POST /analytics/events`) | ✅ (CSRF-exempt) | ✅ | ✅ |
| Push subscription register/remove (`/push/subscriptions`) | ✅ | ✅ | ✅ |

Special rules: `UserPolicy#destroy?` requires target to be staff (admins can never be deleted); last-admin demotion blocked at model level; `manage_pump?` requires `record == current_user`.

## Machine auth (keep in rebuild)

`Admin::SchedulesController` and `Admin::NotificationDeliveriesController` accept **either** an admin session **or** `Authorization: Bearer <ADMIN_NOTIFICATION_API_TOKEN>` (constant-time SHA-256 compare, CSRF null_session). This is how Cloud Scheduler triggers `POST /admin/schedules/run` every minute. Preserve an equivalent service-token path.

## Customer "auth" (public lookup token)

Customers never authenticate. The loyalty result page is guarded by a signed, expiring token (see 04 — LoyaltyLookupToken): HMAC-signed payload `{phone_number, nonce}`, purpose `loyalty_lookup`, **2-minute expiry**, minted on phone submit, rotated on each successful result render. This is the app's only rate-limiting/expiry mechanism on customer data.
