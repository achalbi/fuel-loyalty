# 11 — API Contracts (every endpoint)

Current transport: session-cookie HTML forms + a handful of JSON endpoints. For the native rebuild, re-expose the HTML-form actions as JSON APIs with the **same params, validations, and messages** (06/07 give per-screen copy; 04 gives rule messages). This file lists the full route surface; JSON shapes are given where they exist today.

Legend: 🌐 public · 👤 staff_access (admin or staff) · 🔑 admin · 🤖 admin session OR Bearer `ADMIN_NOTIFICATION_API_TOKEN`.

## Public & platform

| Method + path | Auth | Params | Response |
|---|---|---|---|
| GET `/` | 🌐 | | Redirect by role (admin→dashboard, staff→new transaction, anon→/loyalty) |
| GET `/loyalty` | 🌐 | `lang` | Lookup form (locale switch persists cookie) |
| POST `/loyalty` | 🌐 (CSRF-exempt) | `loyalty[phone_number]`, `lang` | 302 → `/loyalty/result?lookup_token=…`; 422 re-render "Phone number must be a 10 digit number." |
| GET `/loyalty/result` | 🌐 | `lookup_token`, `full_history=1` | Result page; expired → 302 back with alert; unknown phone → 422 "No customer found for that phone number." |
| GET `/manifest.json` | 🌐 | | PWA manifest (public cache 300 s) |
| GET `/service-worker.js` | 🌐 | | SW (no-cache) |
| GET `/up` | 🌐 | | Health check |
| POST `/analytics/events` | 🌐 (CSRF-exempt) | `{name, page_path, properties{}}` | 202 empty; 422 `{errors: […]}` (name must be in 9-event whitelist) |
| POST `/push/subscriptions` | 🌐 | `{token, platform}` | 201/200 `{id, active, platform}`; 422 `{error}` |
| DELETE `/push/subscriptions` | 🌐 | `{token}` | 204 |

## Devise & account

| Method + path | Auth | Notes |
|---|---|---|
| GET/POST `/users/sign_in` | 🌐 | `user[login]` (username/email/phone), `user[password]`, `user[remember_me]` |
| DELETE `/users/sign_out` | 👤 | |
| GET `/password/edit`, PATCH `/password` | 👤 | `user[current_password, password, password_confirmation]` |
| GET `/my_pump`, PATCH `/my_pump` | 👤 (self) | `user[fuel_pump_id, assigned_fuel_pump_nozzle_ids[]]` |

## Customer profile (staff workspace)

| Method + path | Auth | Params / notes |
|---|---|---|
| GET `/customers/:id` | 👤 | Profile (hero, vehicles, recent 3 transactions, ledger) |
| GET `/customers/:id/edit`, PATCH `/customers/:id` | 👤 | `customer[name, phone_number]` |
| GET `/customers/:id/points_ledger` | 👤 | `page` — HTML fragment, 5/page |
| GET `/customers/:id/transaction_history` | 👤 | `page` — HTML fragment, 5/page after a 3-row preview offset |
| POST `/customers/:customer_id/vehicles` | 👤 | `vehicle[vehicle_number, fuel_type, vehicle_kind, commercial_company_name, commercial_contact_name, commercial_contact_phone_number, commercial_address, commercial_notes]` |
| GET `…/vehicles/:id/edit`, PATCH `…/vehicles/:id` | 👤 | same params (+ `vehicle_form_context=modal`) |
| DELETE `…/vehicles/:id` | 👤 | Blocked with transactions: "Vehicle cannot be removed because transaction history exists." |

## Staff namespace

| Method + path | Auth | Params / notes |
|---|---|---|
| GET `/staff/customers` | 👤 | `q` search; no query = top 3 by points; limit 50 |
| GET `/staff/customers/new` | 👤 | prefill `phone_number`, `vehicle_number` |
| POST `/staff/customers` | 👤 | `customer[name, phone_number, vehicle_number, fuel_type, vehicle_kind, commercial_*]` — initial vehicle required |
| **GET `/staff/customers/lookup`** | 👤 | `phone_number` → JSON below |
| PATCH `/staff/customers/:id/activate` / `deactivate` / `pause_rewards` / `resume_rewards` | 👤 | status toggles |
| GET `/staff/transactions/new` | 👤 | prefill `transaction[...]` or `transaction_lookup[...]`, `plate_scanner=1` |
| POST `/staff/transactions` | 👤 | `transaction[lookup_mode, phone_number, vehicle_number, vehicle_id, fuel_amount, fuel_pump_id, fuel_pump_nozzle_id, payment_mode]` |
| **GET `/staff/transactions/lookup`** | 👤 | `vehicle_number` → JSON below |
| **POST `/staff/transactions/recognize_plate`** | 👤 | `{plate_scan: {image_data: "data:image/jpeg;base64,…"}}` → JSON below |
| POST `/staff/transactions/register_customer` | 👤 | customer+vehicle params + `transaction_lookup[...]` carry-through |
| **GET `/api/v1/staff/catalog`** | 👤 | active fuel types + vehicle kinds for the native inline "add customer" form → JSON below |
| GET `/staff/redemptions/new`, POST `/staff/redemptions` | 👤 | `redemption[phone_number, points]` |
| GET `/staff/notifications` | 👤 | static page |

### Customer lookup JSON (`GET /staff/customers/lookup?phone_number=`)

200 (verified exact shape):
```json
{
  "found": true,
  "customer": {
    "id": 12, "name": "Ravi Kumar", "phone_number": "9876543210",
    "active": true, "rewards_paused": false,
    "status_label": "Active", "rewards_status_label": "Rewards Active",
    "total_points": 420,
    "cash_value_per_point": 0.5,
    "total_points_cash_reward": 210.0,
    "minimum_redeemable_points": 100,
    "redemption_increment": 100,
    "max_redeemable_points": 400,
    "max_redeemable_cash_reward": 200.0,
    "vehicles": [
      {"id": 3, "vehicle_number": "KA05MH1234", "fuel_type_code": "petrol",
       "fuel_type": "Petrol", "vehicle_kind": "LMV", "display_name": "KA05MH1234 | Petrol | LMV"}
    ]
  }
}
```
Cash fields are null when `cash_value_per_point` isn't configured.
422 `{"found": false, "message": "Phone number must be a 10 digit number."}` · 404 `{"found": false, "message": "Customer not found for that phone number.", "register_customer_path": "…"}`

### Vehicle lookup JSON (`GET /staff/transactions/lookup?vehicle_number=`)

200: array of **all** matching vehicles (plate may exist under several customers), each `{vehicle fields + nested customer payload as above}`, sorted by customer name/phone. 422 `{"message": "Vehicle number is invalid."}` · 404 `{"message": "No customer was found for that vehicle number.", "register_customer_path": "…"}`

The native `/api/v1/staff/transactions/lookup` returns the same 404 with an error envelope `{"error": {"code": "vehicle_not_found", …}}`. The app treats that as the entry point to the inline "add customer" flow (see the catalog + register_customer endpoints), not a hard error.

### Staff catalog JSON (`GET /api/v1/staff/catalog`)

`{"fuel_types": [{"code", "label"}], "vehicle_kinds": [{"code", "label", "commercial"}]}` — active options mirroring `FuelType.active_options` / `VehicleType.active_options`. `commercial` is `true` for lcv/mcv/hcv so the client shows the commercial fields (company/contact/address). Feeds the native inline registration form for an unregistered plate; `POST /api/v1/staff/transactions/register_customer` (customer + vehicle, atomic) then returns the customer so the transaction can be recorded.

### Plate recognition JSON

200 `{found: true, plate, raw, confidence, valid, corrected, provider: "plate_recognizer", candidates: [≤3]}` · 422 `{found: false, message}` · 503 not configured · 502 upstream failure.

## Admin namespace (all 🔑 unless marked 🤖)

| Method + path | Params / notes |
|---|---|
| GET `/admin/dashboard` | filters `preset, start_date, end_date, segment, fuel_type` |
| **GET `/admin/dashboard/data`** | same filters → JSON `{filters, summary[8], charts{11}, rewards, meta}` (full shape in 07.1/04.11) |
| GET `/admin/users`; POST `/admin/users`; GET/:id; GET/:id/edit; PATCH/:id | `user[name, username, phone_number, email, active, password, password_confirmation]` + `user[role]` |
| GET `/admin/staff_members`; PATCH/:id; DELETE/:id (soft) | `user[name, active, employee_code, subtitle]` |
| POST `/admin/staff_members/:id/shift_assignments` | `shift_assignment[shift_template_id, notes]` |
| GET/POST `/admin/shift_templates`; PATCH/:id | `shift_template[name, start_time, duration_hours, duration_minutes, active]` |
| GET/POST `/admin/shift_cycles`; PATCH/:id; DELETE/:id; PATCH/:id/activate|deactivate | `shift_cycle[name, starts_on, active]` + `shift_cycle[step_shift_template_ids][]` (≤12) |
| GET `/admin/attendance_runs` | `filter (all|valid|invalid), start_date, end_date, page` (6/page) |
| GET `/admin/attendance_runs/new` | planner: `shift_template_id, starts_at` |
| POST `/admin/attendance_runs` | `attendance_run[shift_template_id, starts_at, ends_at, stale, notes, attendance_entries_attributes[{scheduled_user_id, actual_user_id, replacement_user_id, external_replacement_name, status, check_in_at, check_out_at, notes}]]` |
| GET/:id; PATCH/:id/invalidate; PATCH/:id/mark_valid; DELETE/:id (invalid only) | |
| GET/POST `/admin/fuel_types`; GET/:id/edit; PATCH/:id; DELETE/:id | `fuel_type[name, active]` |
| GET/POST `/admin/fuel_pumps`; GET/:id/edit; PATCH/:id; DELETE/:id | `fuel_pump[active, nozzles_attributes[{id, fuel_type_code, active, _destroy}]]` |
| PATCH `/admin/fuel_pumps/feature_settings` | `reward_setting[nozzle_feature_enabled]` |
| GET/POST `/admin/vehicle_types`; GET/:id/edit; PATCH/:id; DELETE/:id | `vehicle_type[name, short_name, app_label_source, code(create only), icon_name, minimum_redeemable_points, active]` |
| GET `/admin/fuel_reward_rates`; PATCH | one of: `reward_setting[rupees_per_reward_unit, cash_value_per_point, minimum_redeemable_points]` · `vehicle_type_reward_rates[<code>][reward_points_per_100]` · `fuel_reward_rates[<fuel_type>][points_per_100]` |
| GET `/admin/theme_settings`; PATCH | `theme_setting[primary_color]` |
| GET `/admin/notifications` | page state |
| POST `/admin/notifications/send` 🤖 | `notification[title, message]` |
| GET/POST `/admin/schedules` 🤖; PATCH/:id; DELETE/:id | `notification_schedule[title, message, frequency, scheduled_time, scheduled_date, day_of_week, day_of_month, active]` (nested or flat); JSON supported |
| POST `/admin/schedules/:id/send_now` 🤖 | JSON: `{schedule, delivery: {requested, sent, failed, invalidated, batches, errors}}` |
| **POST `/admin/schedules/run`** 🤖 | JSON: `{checked, due, sent, failed, details, acquired, skipped, message}` |
| GET `/admin/customers` (+ member `points_ledger`, `transaction_history`); GET/:id; new/create/edit/update/destroy | `q, status`; `customer[name, phone_number, (+vehicle fields on create)]` |
| GET `/admin/transactions` | `range (all|today), sort (time_desc|time_asc|amount_desc|amount_asc), start_date, end_date, page` (10/page) |
| GET/POST `/admin/points_adjustments` | `points_adjustment[phone_number, points]` (signed) |

## Suggested native API additions (not in current app)

- Token auth endpoints (login → access/refresh, logout).
- `GET /api/theme` → `{primary_color}` (currently only embedded in HTML/manifest).
- `POST /api/loyalty/lookup {phone}` → the result-page payload (replaces the token redirect dance) with server-side rate limiting.
- JSON variants of every HTML-form endpoint above (same params/messages).
