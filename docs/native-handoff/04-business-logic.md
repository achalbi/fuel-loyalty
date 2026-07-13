# 04 — Business Logic (exact algorithms)

These rules are the core of the product. Replicate byte-for-byte; all numbers verified against code.

## 4.1 Points earning (PointsCalculator)

```
points = floor(fuel_amount / rupees_per_reward_unit) * points_per_100
```

- `fuel_amount`: the ₹ transaction amount (BigDecimal).
- `rupees_per_reward_unit`: `RewardSetting.rupees_per_reward_unit` (default **100**).
- `points_per_100` rate precedence:
  1. `VehicleType.reward_points_per_100` for the vehicle's kind — **used if non-NULL, including 0**.
  2. Else `FuelRewardRate.points_per_100` for the vehicle's fuel type (stored row; a stored 0 stays 0).
  3. Else built-in defaults: petrol **2**, diesel **1**, cng_lpg **1**, unknown fuel **0**.
- Floor happens on completed reward units only: ₹250 petrol → floor(2.5)=2 × 2 = **4 pts**; ₹99 → **0 pts**.
- Rewards paused customer → points forced to 0 and **no ledger row is written** (see 4.3).

## 4.2 Points redemption (PointsRedeemer)

Definitions:
- `customer.total_points` = SUM of all ledger rows.
- `customer.minimum_redeemable_points` = `RewardSetting.minimum_redeemable_points` if configured (> 0), **else MIN(minimum_redeemable_points) across the customer's registered vehicle-type codes** (default 100 if the customer has no vehicles/types).
- `redemption_increment` = `RewardSetting.effective_minimum_redeemable_points(fallback: 100)`. ⚠️ Subtle: the increment's fallback is the **global 100**, not the customer's vehicle-type minimum. Minimum and increment only differ when the global setting is blank and a vehicle type has a minimum ≠ 100.
- `max_redeemable_points(available, min, incr)`: `incr = max(incr, 1)`; `min = max(min, incr)`; if `available < min` → 0; else `floor(available / incr) * incr`. Returns 0 outright if rewards paused.

Redemption flow `call(phone_number:, points:)` — validation ladder, each failing with the given message on `points` (phone errors on `phone_number`):

1. Phone must be 10 digits → "must be a 10 digit number"; customer must exist → "was not found".
2. Rewards paused → "cannot be redeemed while rewards are paused for this customer".
3. `max < minimum` → "must have at least {minimum} available points to redeem".
4. `points <= 0` → "must be greater than 0".
5. `points % increment != 0` → "must be in multiples of {increment}".
6. `points < minimum` → "must be at least {minimum} points".
7. `points > max` → "cannot exceed {max} redeemable points".

On success: create ledger row `points: -points, entry_type: redeem`. The row snapshots `cash_reward_amount = points × cash_value_per_point` if configured (see 4.4). Returns `{customer, points_redeemed, cash_reward_amount}`.

⚠️ **No row locking** — concurrent redemptions aren't serialized (balance is a live SUM). For the rebuild, wrap redemption in a transaction with a customer-row lock or a balance check at commit.

## 4.3 Transaction recording (TransactionCreator)

Inputs: `user` (staff), `fuel_amount`, `vehicle_id`, `lookup_mode` ("phone" | "vehicle"), `phone_number`, `vehicle_number`, `fuel_pump_nozzle_id`, `fuel_pump_id`, `payment_mode`. Entire flow in one DB transaction; any failure rolls back everything.

1. **Resolve customer + vehicle.**
   - Vehicle mode: normalize + validate `vehicle_number` format ("is invalid"); load `Vehicle` by `vehicle_id`; its stored number must equal the normalized entered number ("must match the entered vehicle number"); missing → "must be selected from the matched customer list". Customer = vehicle's owner.
   - Phone mode: validate 10-digit phone; find customer by phone ("was not found"); vehicle must belong to that customer ("must belong to the selected customer").
   - Either mode: customer must be active → "Customer must be active to record transactions".
2. **Resolve pump/nozzle** — branches on `RewardSetting.nozzle_feature_enabled`:
   - **ON (default):** pump := the user's assigned active My Pump, else "Set up My Pump with at least one active nozzle before recording a transaction". Nozzle := `fuel_pump_nozzle_id` among the user's assigned active nozzles on that pump, else "must be selected from your assigned nozzles". Nozzle fuel type must equal vehicle fuel type (normalized compare) → "must match the selected vehicle's fuel type".
   - **OFF:** pump := active pump by `fuel_pump_id`, else "must be selected from active pumps"; nozzle is nil.
3. **Payment mode** must be `cash` or `credit` → "must be cash or credit".
4. Create `Transaction(customer, user, vehicle, fuel_amount, payment_mode, fuel_pump, fuel_pump_nozzle)` — fuel_amount must be > 0.
5. **Points:** if `customer.rewards_paused` → `points_earned = 0`, no ledger row. Else compute via 4.1 and create ledger row `{transaction, points, entry_type: earn}` (may legitimately be 0 points — a 0-point earn row IS written when not paused).
6. Returns `{customer, transaction, points_earned, rewards_paused}`.

## 4.4 Cash reward snapshot (PointsLedger callback)

On ledger create, if `cash_reward_amount` not already set: `cash_reward_amount = RewardSetting.cash_value_for_points(|points|)` where `cash_value_for_points` = `points × cash_value_per_point` only when `cash_value_per_point` is present and > 0, else NULL. Applies to every entry type (earn, redeem, adjust).

## 4.5 Loyalty lookup token (LoyaltyLookupToken)

- `generate(phone)`: HMAC-signed (Rails `MessageVerifier` on `secret_key_base` — signed, NOT encrypted) payload `{phone_number: normalized, nonce: SecureRandom.hex(8)}`, purpose `"loyalty_lookup"`, **expires_in 2 minutes**. Stateless — nothing stored server-side.
- `verified_phone_number(token)`: returns the phone if valid + unexpired + purpose matches, else nil.
- The result page mints a fresh token on every successful render (rotation) so links keep working during a session but a leaked URL dies in ≤2 min.

## 4.6 Vehicle plate text normalization & OCR correction (VehiclePlateText)

- `normalize`: upcase, strip all non-`[A-Z0-9]`.
- Valid formats: STANDARD `\A[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}\z` (e.g. KA05MH1234) or BH `\A[0-9]{2}BH[0-9]{4}[A-Z]{2}\z`.
- `normalize_detected` (OCR fixup): if already valid, return. Else brute-force segment layouts — STANDARD: district length ∈ {1,2} × series length ∈ {0..3}, number length = total − 2 − district − series constrained 1..4; BH: exact `digit(2) + "BH" + digit(4) + alpha(2)`, length 10. Per-segment substitutions: digits→letters in alpha segments `0→O, 1→I, 2→Z, 5→S, 6→G, 8→B`; letters→digits in numeric segments `O→0, Q→0, D→0, I→1, L→1, T→1, Z→2, S→5, B→8, G→6`. Keep the valid candidate with the **fewest character replacements**; reject if replacements > **3**; fall back to raw normalized.

## 4.7 Notification scheduling (NotificationScheduleRunner) — see 08 for delivery

Due check `is_due?(schedule, now)` (all in IST, `Time.zone.local` → DST-correct):
- Inactive → not due. Compute `occurrence_at`:
  - once → `scheduled_date` at `scheduled_time`.
  - daily → today at `scheduled_time`.
  - weekly → (start of week **Sunday** + `day_of_week` days) at time.
  - monthly → `min(day_of_month, last day of current month)` at time (Feb 30 → Feb 28/29).
- Due iff `now >= occurrence` AND (`last_sent_at` blank OR `last_sent_at < occurrence`). One send per occurrence; missed occurrences fire on the next runner tick (runner runs every minute via Cloud Scheduler).

Run loop: acquire DB lease (key `notification_schedule_runner`; skip if another run holds it with a heartbeat < **10 min** old; heartbeat each iteration; release in ensure). For each active schedule that's due: broadcast via FCM; on success set `last_sent_at = now` and **deactivate if frequency = once**. Result: `{checked, due, sent, failed, details, acquired, skipped, message}`.

## 4.8 Shift rotation math (ShiftCycle#window_for)

- `cycle_duration = Σ step.shift_template.duration_minutes` (ordered by position).
- `cycle_start = starts_on date at first step's start_time`.
- For a moment `t`: `elapsed = floor((t − cycle_start)/60s)`; nil if negative/no steps/zero duration.
- `position_in_cycle = elapsed % cycle_duration`; walk steps accumulating durations; the step containing `position_in_cycle` wins. Returns `{shift_template, starts_at, ends_at, position}` (absolute window via `cycle_offset = elapsed − position_in_cycle`).
- `shift_template_for(t)` = that window's template (or first step's). `valid_window_for?(template, starts, ends)` compares template + second-truncated boundaries — used to force attendance windows to align to the cycle.

## 4.9 Attendance roster (AttendanceRosterBuilder)

`call(shift_template:, starts_at:)` → active ShiftAssignments for that template, `effective_at(starts_at)`, joined to **active staff-role users**, ordered name → username → phone. One planned attendance entry per rostered user (status present, check_in = window start, check_out = window end). Swaps/cycles do not alter the roster — cycles only validate window alignment.

## 4.10 Shift assignment creation (admin)

New assignment: `active: true`, `effective_from = now (seconds zeroed)`, `shift_cycle = template.current_shift_cycle(at effective_from)` (active cycle whose current window maps to this template, else first). In one transaction: any currently-active overlapping assignment for the user gets `effective_to = effective_from − 1 second`, then the new one saves. History is preserved as effective-dated rows.

## 4.11 Analytics report math (admin dashboard)

See 07 §1 for the full JSON; key formulas: revenue = SUM(fuel_amount); points_issued = SUM(points) where earn; points_redeemed = SUM(ABS(points)) where redeem; avg_spend = revenue/transactions; visits_per_customer = transactions/DISTINCT customers; active_customers = distinct customers with a transaction in the trailing 30 days ending at range end; change% = (cur−prev)/prev×100 (1 dp, nil if prev = 0) vs the immediately-preceding equal-length window; segments: `new` = first-ever transaction inside range, `repeat` = transacted in range but first visit predates it; redemption slabs bucket redeemed points by `redemption_increment` (non-multiples → "Other / Legacy"); redemption_rate = redeemed/issued×100.
