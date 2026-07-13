# 02 — Data Model

PostgreSQL. All `id`s are bigint autoincrement; all tables have `created_at`/`updated_at`. Enum integer values are load-bearing — replicate exactly.

## Entity map

```
Customer 1—N Vehicle          Customer 1—N Transaction 1—0..1 PointsLedger
Customer 1—N PointsLedger     Transaction N—1 User (staff who recorded)
Transaction N—0..1 FuelPump, N—0..1 FuelPumpNozzle, N—1 Vehicle
FuelPump 1—N FuelPumpNozzle   FuelPumpNozzle N—1 FuelType (by code)
User N—0..1 FuelPump (assigned) ; User N—N FuelPumpNozzle (via UserPumpNozzleAssignment)
Vehicle N—1 FuelType (by code string) ; Vehicle N—1 VehicleType (by vehicle_kind code)
FuelRewardRate — per FuelType code   VehicleType — per-kind reward override
ShiftTemplate 1—N ShiftAssignment N—1 User ; ShiftAssignment N—0..1 ShiftCycle
ShiftCycle 1—N ShiftCycleStep N—1 ShiftTemplate
AttendanceRun N—1 ShiftTemplate ; 1—N AttendanceEntry N—1 User (scheduled/actual/replacement)
NotificationSchedule, PushSubscription, SchedulerLease, ThemeSetting, RewardSetting (singletons/config)
AnalyticsEvent N—0..1 User
```

## users

| Column | Type | Rules |
|---|---|---|
| name | string NOT NULL | presence; normalized `squish.titleize` |
| username | string NOT NULL, unique | presence; case-insensitive unique; format `\A\S+\z` (no whitespace); stripped |
| email | string NOT NULL default "", unique | optional in UI; downcased; if blank/internal, auto-set to `user-{phone}@users.fuel-loyalty.local` |
| encrypted_password | string | Devise bcrypt; password length 6–128 |
| phone_number | string, unique | required (custom validator); exactly 10 digits `\A\d{10}\z`; normalized strip non-digits; error "must be a 10 digit mobile number" |
| role | integer NOT NULL default 1 | enum `{admin: 0, staff: 1}`; guard: cannot demote the last admin ("must leave at least one admin user") |
| active | boolean default true | inactive users cannot sign in |
| deleted_at | datetime | soft delete (staff only; must be inactive first) |
| employee_code | string, unique | optional; case-insensitive unique |
| subtitle | string | optional, max 120 chars |
| fuel_pump_id | FK fuel_pumps | "My Pump" assignment (optional) |
| remember_created_at, reset_password_token/sent_at | | Devise rememberable/recoverable |

Pump-assignment validation context (`:pump_assignment`): pump must be active; ≥1 nozzle selected; nozzles must belong to the selected pump; all nozzles active.

Display helpers: `display_name` = name → username → "+91 {phone}" → "User"; `avatar_initial` = first char.

## customers

| Column | Type | Rules |
|---|---|---|
| name | string | presence |
| phone_number | string NOT NULL, unique | 10 digits; normalized; error "must be a 10 digit number" (wording differs from User) |
| active | boolean default true | inactive customers cannot have transactions recorded |
| rewards_paused | boolean default false | paused: earns 0 points, cannot redeem |
| vehicle_number | string | **legacy, unused by logic** (still searched in admin customer search) |

Associations: vehicles (ordered by vehicle_number, dependent destroy), points_ledgers (dependent destroy), transactions (**restrict** — customer with transactions cannot be deleted).

Computed (see 04 for math): `total_points` = SUM(points_ledgers.points); `minimum_redeemable_points`; `max_redeemable_points`; `points_until_redeemable` = max(min − total, 0); `registered_vehicle_type_codes` = distinct vehicle kinds.

## vehicles

| Column | Type | Rules |
|---|---|---|
| customer_id | FK NOT NULL | |
| vehicle_number | string NOT NULL | presence; **unique per customer** (case-insensitive) — same plate CAN exist under different customers; normalized upcase + strip non-alphanumerics; must match STANDARD `\A[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}\z` or BH `\A[0-9]{2}BH[0-9]{4}[A-Z]{2}\z`; error "is invalid" |
| fuel_type | string NOT NULL | must be an existing, active FuelType code (a persisted record may keep an inactive current value); normalized parameterize `_` |
| vehicle_kind | string NOT NULL | must be an existing, active VehicleType code (same escape); normalized `tr("-","_")` + parameterize |
| commercial_company_name | string | required when kind ∈ {lcv, mcv, hcv} |
| commercial_contact_name | string | required when commercial |
| commercial_contact_phone_number | string | optional; 10-digit if present; normalized digits |
| commercial_address | text | required when commercial |
| commercial_notes | text | optional |

`COMMERCIAL_VEHICLE_KINDS = %w[lcv mcv hcv]`. All commercial fields are cleared unless the vehicle is commercial. Deletion restricted while transactions exist. `display_name` = "{number} | {fuel} | {kind}".

## transactions

| Column | Type | Rules |
|---|---|---|
| customer_id | FK NOT NULL | |
| user_id | FK NOT NULL | staff who recorded |
| vehicle_id | FK NOT NULL (validated presence) | |
| fuel_amount | decimal(10,2) NOT NULL | numeric > 0 (₹ amount, not litres) |
| payment_mode | string NOT NULL default "cash" | **string-backed enum** `{cash: "cash", credit: "credit"}` |
| fuel_pump_id | FK optional | set in pump mode |
| fuel_pump_nozzle_id | FK optional | set in nozzle mode |

`has_one :points_ledger` (restrict — cannot delete a transaction that has a ledger row). No status/void/edit capability anywhere.

## points_ledgers

| Column | Type | Rules |
|---|---|---|
| customer_id | FK NOT NULL | |
| transaction_id | FK optional | set for `earn` rows |
| entry_type | integer NOT NULL | enum `{earn: 0, redeem: 1, expire: 2, adjust: 3}` (no default; `expire` never written by current code) |
| points | integer NOT NULL | signed: earn +, redeem −, adjust ± |
| cash_reward_amount | decimal(12,2) | ≥ 0; **snapshotted at creation**: `RewardSetting.current.cash_value_for_points(points.abs)` if cash value configured — immune to later rate changes |

Balance = arithmetic SUM of all rows. There is no running-balance column and no expiry job.

## reward_settings (singleton — `first_or_initialize`)

| Column | Type | Default | Meaning |
|---|---|---|---|
| rupees_per_reward_unit | integer NOT NULL | 100 | ₹ per reward unit in earn math; integer > 0 |
| minimum_redeemable_points | integer | NULL | global min; when NULL falls back to vehicle-type minimums; integer > 0 |
| cash_value_per_point | decimal(10,2) | NULL | ₹ per point on redemption; ≥ 0; NULL/0 = cash rewards not configured |
| nozzle_feature_enabled | boolean NOT NULL | true | ON: staff use My Pump + nozzle; OFF: staff pick a pump per transaction |

Derived: `effective_minimum_redeemable_points(fallback: 100)` = configured value if > 0 else fallback; **`redemption_increment` = `effective_minimum_redeemable_points`** (step size equals the minimum).

## fuel_types

`code` (unique, format `\A[a-z0-9]+(?:_[a-z0-9]+)*\z`, auto-generated from name on first save, then fixed), `name` (unique), `active` (default true). Defaults seeded: Petrol/`petrol`, Diesel/`diesel`, CNG / LPG/`cng_lpg`. Destroy blocked while vehicles or nozzles use the code; destroying deletes its FuelRewardRate rows.

## fuel_reward_rates

`fuel_type` (unique, must be an existing FuelType code), `points_per_100` (integer ≥ 0). Fallback defaults when no row exists: **petrol 2, diesel 1, cng_lpg 1, unknown 0**. A stored 0 stays 0.

## vehicle_types

| Column | Rules |
|---|---|
| code | unique; format `\A[a-z]+(?:_[a-z]+)*\z`; immutable after create |
| name | unique, presence |
| short_name | presence (auto-filled from name if blank) |
| app_label_source | `name` or `short_name` (default `short_name`) — which label the app displays |
| icon_name | one of 8: `ti-bike`, `custom-tuk-tuk`, `ti-car`, `custom-pickup-truck`, `ti-truck`, `custom-big-truck`, `ti-bus`, `ti-tractor` |
| minimum_redeemable_points | integer ≥ 100, **multiple of 100**, default 100 |
| reward_points_per_100 | integer ≥ 0, nullable — when set (including 0) **overrides** the fuel-type rate for this vehicle kind |
| reward_points_per_rupee | decimal(8,2) — **DORMANT, never referenced** |
| active | default true |

Defaults seeded (canonical order): Two-Wheeler/`two_wheeler`, Three-Wheeler/`three_wheeler`, LMV/`lmv`, LCV/`lcv`, MCV/`mcv`, HCV/`hcv`. Destroy blocked while vehicles use the code. `minimum_redeemable_points_for_codes(codes)` = **MIN** across the given codes, default 100.

## fuel_pumps / fuel_pump_nozzles / user_pump_nozzle_assignments

- **fuel_pumps:** `sequence_number` (unique, auto next=max+1), `active` (default true). Display "Pump {n}". Must have ≥ 1 nozzle. Destroy blocked while transactions reference it.
- **fuel_pump_nozzles:** `fuel_pump_id`, `fuel_type_code` (must exist & be active for new picks), `sequence_number` (unique within pump, auto-fills gaps from 1), `active`. Display "Nozzle {n}". Destroy blocked while transactions reference it.
- **user_pump_nozzle_assignments:** join (user_id, fuel_pump_nozzle_id) unique.

## Shift & attendance tables

- **shift_templates:** `name` (unique ci), `start_time` string "HH:MM" (24h, `\A([01]\d|2[0-3]):[0-5]\d\z`, error "must use HH:MM"), `duration_minutes` (integer > 0; UI enters hours, ×60 rounded), `active`.
- **shift_cycles:** `name` (unique), `starts_on` date, `active`, `period_days` (**DORMANT**, default 1 — rotation is computed purely from step durations). Must have ≥ 1 step. Deletable only when no assignments reference it.
- **shift_cycle_steps:** `shift_cycle_id`, `shift_template_id`, `position` (integer > 0, unique per cycle).
- **shift_assignments:** `user_id`, `shift_template_id`, `shift_cycle_id` (optional; if present the cycle must have steps), `effective_from` (NOT NULL), `effective_to` (nullable; ≥ effective_from), `active`, `notes`. Scope `effective_at(t)`: `effective_from <= t AND (effective_to IS NULL OR effective_to >= t)`.
- **attendance_runs:** `shift_template_id`, `recorded_by_id`, `starts_at`, `ends_at` (> starts_at), `shift_name_snapshot` + `duration_snapshot_minutes` (copied from template before validation), `stale` boolean default false (false = Valid record, true = Invalid), `notes`. Must include ≥ 1 entry. **Unique valid window:** no other valid run may exist for the same (shift_template_id, starts_at, ends_at) — error "Attendance has already been recorded for this shift and time window."
- **attendance_entries:** `attendance_run_id` + `scheduled_user_id` (unique pair), `actual_user_id`, `replacement_user_id`, `external_replacement_name`, `status` enum `{present: 0, absent: 1, late: 2, half_day: 3, leave: 4, off: 5}` default present, `check_in_at`/`check_out_at` (out ≥ in), `notes`, plus **dormant** override columns (`overridden`, `last_overridden_at/by`). Before validation: actual := replacement if set; else if status ≠ absent and no actual/external name, actual := scheduled. `worker_name` = actual → external name → "Not covered" (absent) → scheduled.
- **attendance_entry_changes:** **DORMANT** audit table (before/after jsonb, `change_reason`) — model exists, no UI writes it.
- **shift_swaps:** **DORMANT** — model + table (`swap_kind` enum `{this_shift_only: 0, temporary: 1, permanent: 2}`, from/to user & template, reason, starts/ends, recorded_by; users must differ; ends > starts) but no route/controller/view.

## notification_schedules

`title` (≤120 in UI), `message` (≤240 in UI), `frequency` ∈ `%w[once daily weekly monthly]`, `scheduled_time` string "HH:MM" (IST), `scheduled_date` (required for once), `day_of_week` 0–6 Sunday=0 (required for weekly), `day_of_month` 1–31 (required for monthly; clamps to month-end at runtime), `active` (once-schedules auto-deactivate after first successful send), `last_sent_at`. Irrelevant date/day fields are nulled per frequency on save.

## push_subscriptions

`token` (unique, stripped), `platform` ∈ `%w[android ios web desktop unknown]` (invalid input → "unknown"), `last_used_at`, `active`. Upsert by token (`register!` reactivates). Deactivated on FCM `UNREGISTERED`/`INVALID_ARGUMENT` or explicit unsubscribe.

## Other tables

- **theme_settings** (singleton): `primary_color` string default `#43B05C`; format `\A#[0-9A-F]{6}\z` (normalized uppercase); error "must be a valid hex color".
- **scheduler_leases:** `key` (unique), `running`, `lease_token`, `started_at`, `last_heartbeat_at`, `finished_at`. DB-backed distributed lock for the notification runner (key `notification_schedule_runner`, 10-minute timeout).
- **analytics_events:** `name` (must be one of 9 PWA-install event names — see 10), `page_path` (required), `properties` jsonb, `user_agent`, `user_id` (optional).
- **vehicle_type_reward_offers:** **DORMANT** — table only, no model/code references.

## Dormant schema summary (do not build)

`vehicle_type_reward_offers` (whole table), `vehicle_types.reward_points_per_rupee`, `customers.vehicle_number` (legacy; only touched by admin search), `shift_cycles.period_days`, `shift_swaps` (model exists, no UI), attendance entry override columns + `attendance_entry_changes` (no UI). Revive deliberately or drop.
