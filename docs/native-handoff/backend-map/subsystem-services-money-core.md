## Subsystem: services:money-core

Three PORO service objects. All live in `app/services`. No controllers/models/policies in this subsystem; external model dependencies are noted inline. Errors are signalled by raising `ActiveRecord::RecordInvalid` wrapping a model with `.errors.add`, so callers read `e.record.errors.full_messages`.

---

### `PointsCalculator` — `app/services/points_calculator.rb`

Pure computation. No DB writes. Computes points earned for a fuel purchase.

**Entry point**
- `PointsCalculator.call(fuel_amount, fuel_type:, vehicle_kind: nil)` → delegates to `new(...).call`.
- `initialize(fuel_amount, fuel_type:, vehicle_kind: nil)`:
  - `@fuel_amount = BigDecimal(fuel_amount.to_s)` (coerced to BigDecimal via string).
  - `@fuel_type = fuel_type`, `@vehicle_kind = vehicle_kind`.

**Return value**: an Integer number of points. No struct/hash.

**Algorithm (`#call`)**:
```
((fuel_amount / rupees_per_reward_unit).floor * points_per_100)
```
Step by step:
1. `rupees_per_reward_unit` = `BigDecimal(RewardSetting.current.rupees_per_reward_unit.to_s)` (memoized). **DB read** of the singleton `RewardSetting.current`.
2. `fuel_amount / rupees_per_reward_unit`, then `.floor` → integer count of whole reward units.
3. Multiply by `points_per_100`.

**`points_per_100` resolution (private)**:
- `vehicle_type_points_per_100` = `VehicleType.reward_points_per_100_for(@vehicle_kind)` (memoized with `||=`).
- If that is **`nil`** → fall back to `FuelRewardRate.points_per_100_for(@fuel_type)`.
- Else → use the vehicle-type value.
- NOTE: `||=` memoization means a legitimately `0`/`false` vehicle-type value would still re-query; but the `.nil?` branch decides fallback. Vehicle-kind rate takes precedence over fuel-type rate when present.

**External dependencies (must exist for API reuse)**:
- `RewardSetting.current.rupees_per_reward_unit`
- `VehicleType.reward_points_per_100_for(vehicle_kind)` → numeric or `nil`
- `FuelRewardRate.points_per_100_for(fuel_type)` → numeric

**Errors**: none raised directly (will propagate DB/nil errors if `RewardSetting.current` missing).

---

### `PointsRedeemer` — `app/services/points_redeemer.rb`

Redeems points for a customer by phone number; writes a negative `:redeem` ledger entry.

**Constants**
- `DEFAULT_REDEMPTION_INCREMENT = 100`
- `REDEMPTION_INCREMENT = DEFAULT_REDEMPTION_INCREMENT` (= 100; static alias)
- `Result = Struct.new(:customer, :points_redeemed, :cash_reward_amount, keyword_init: true)`

**Class methods**
- `PointsRedeemer.call(...)` → `new(...).call`.
- `PointsRedeemer.redemption_increment` → `RewardSetting.current.redemption_increment`; **rescues** `ActiveRecord::NoDatabaseError` and `ActiveRecord::StatementInvalid` → returns `DEFAULT_REDEMPTION_INCREMENT` (100).
- `PointsRedeemer.max_redeemable_points(available_points, minimum_redeemable_points: redemption_increment, redemption_increment: self.redemption_increment)`:
  1. `normalized_available_points = available_points.to_i`
  2. `normalized_increment = [redemption_increment.to_i, 1].max` (floor 1)
  3. `normalized_minimum_points = [minimum_redeemable_points.to_i, normalized_increment].max`
  4. `return 0 if normalized_available_points < normalized_minimum_points`
  5. else `(normalized_available_points / normalized_increment) * normalized_increment` (largest increment-multiple ≤ available).

**Instance**
- `initialize(phone_number:, points:)` → `@phone_number`, `@points`.

**Return value (success)**: `Result` struct with keys `customer`, `points_redeemed` (Integer), `cash_reward_amount` (= `ledger_entry.recorded_cash_reward_amount`).

**Algorithm (`#call`)** — order is load-bearing:
1. `customer = find_customer!` (see below).
2. `points_to_redeem = normalized_points` = `points.to_i`.
3. If `customer.rewards_paused?` → `invalid_redemption!` with `"cannot be redeemed while rewards are paused for this customer"`.
4. `minimum_redeemable_points = customer.minimum_redeemable_points`.
5. `redemption_increment = self.class.redemption_increment`.
6. `max_redeemable_points = self.class.max_redeemable_points(customer.total_points, minimum_redeemable_points:, redemption_increment:)`.
7. If `max_redeemable_points < minimum_redeemable_points` → error `"must have at least #{minimum_redeemable_points} available points to redeem"`.
8. If `points_to_redeem <= 0` → error `"must be greater than 0"`.
9. If `(points_to_redeem % redemption_increment) != 0` → error `"must be in multiples of #{redemption_increment}"`.
10. If `points_to_redeem < minimum_redeemable_points` → error `"must be at least #{minimum_redeemable_points} points"`.
11. If `points_to_redeem > max_redeemable_points` → error `"cannot exceed #{max_redeemable_points} redeemable points"`.
12. **DB write**: `customer.points_ledgers.create!(points: -points_to_redeem, entry_type: :redeem)` (note: points stored NEGATIVE).
13. Return `Result.new(customer:, points_redeemed: points_to_redeem, cash_reward_amount: ledger_entry.recorded_cash_reward_amount)`.

**Error mechanism** — all validation failures raise `ActiveRecord::RecordInvalid`:
- `invalid_redemption!(customer, points_to_redeem, message)` builds `customer.points_ledgers.build(points: -points_to_redeem, entry_type: :redeem)`, adds `message` under attribute `:points`, raises. Full message form: `"Points <message>"`.
- `find_customer!`:
  - Calls `validate_phone_number!` first.
  - `Customer.find_by!(phone_number: normalized_phone_number)`.
  - On `ActiveRecord::RecordNotFound` → raises `RecordInvalid` on `Customer.new(phone_number: phone_number)` with `:phone_number` error **`"was not found"`**.
- `validate_phone_number!`:
  - Returns if `Customer.valid_phone_number?(phone_number)`.
  - Else raises `RecordInvalid` on `Customer.new(phone_number: normalized_phone_number.presence || phone_number)` with `:phone_number` = `Customer::PHONE_NUMBER_ERROR_MESSAGE` (constant, exact string defined on Customer model — not in this file).
- `normalized_phone_number` = `Customer.normalize_phone_number(phone_number)` (memoized).
- `normalized_points` = `points.to_i`.

**External dependencies**: `RewardSetting.current.redemption_increment`; `Customer.valid_phone_number?`, `Customer.normalize_phone_number`, `Customer::PHONE_NUMBER_ERROR_MESSAGE`, `Customer.find_by!`; instance `customer.rewards_paused?`, `customer.minimum_redeemable_points`, `customer.total_points`, `customer.points_ledgers`; `points_ledger.recorded_cash_reward_amount`; enum value `entry_type: :redeem`.

**Transaction/locking**: NONE. The `create!` is a single insert with no surrounding `ActiveRecord::Base.transaction` and no row lock — concurrent redemptions are not guarded here.

---

### `TransactionCreator` — `app/services/transaction_creator.rb`

Creates a fuel `Transaction` and (unless paused) an `:earn` points ledger entry, atomically.

**Constant**
- `Result = Struct.new(:customer, :transaction, :points_earned, :rewards_paused, keyword_init: true)`

**Entry point**
- `TransactionCreator.call(...)` → `new(...).call`.
- `initialize(user:, fuel_amount:, vehicle_id:, fuel_pump_nozzle_id: nil, fuel_pump_id: nil, lookup_mode: "phone", phone_number: nil, vehicle_number: nil, payment_mode: "cash")`.
  - Defaults: `lookup_mode: "phone"`, `payment_mode: "cash"`, nozzle/pump ids and phone/vehicle_number `nil`.

**Return value (success)**: `Result` with `customer`, `transaction` (persisted `Transaction`), `points_earned` (Integer; `0` when paused), `rewards_paused` (Boolean).

**Algorithm (`#call`)** — entire body wrapped in `ActiveRecord::Base.transaction do ... end` (atomic; any raise rolls back):
1. `customer, vehicle = resolve_customer_and_vehicle!`
2. `fuel_pump, fuel_pump_nozzle = resolve_fuel_pump_and_nozzle!(vehicle)`
3. `validated_payment_mode = resolve_payment_mode!`
4. **DB write**: `transaction = customer.transactions.create!(user:, vehicle:, fuel_amount:, payment_mode: validated_payment_mode, fuel_pump:, fuel_pump_nozzle:)`
5. If `customer.rewards_paused?` → `points = 0` (NO ledger entry created).
6. Else → `points = PointsCalculator.call(fuel_amount, fuel_type: vehicle.fuel_type, vehicle_kind: vehicle.vehicle_kind)`; then **DB write** `customer.points_ledgers.create!(fuel_transaction: transaction, points: points, entry_type: :earn)`.
7. Return `Result.new(customer:, transaction:, points_earned: points, rewards_paused: customer.rewards_paused?)`.

**Customer/vehicle resolution**
- `resolve_customer_and_vehicle!`:
  - If `vehicle_lookup?` (`lookup_mode.to_s == "vehicle"`):
    - `vehicle = find_vehicle_by_lookup!`; `customer = vehicle.customer`; `ensure_customer_active!(customer)`; return `[customer, vehicle]`.
  - Else (phone mode):
    - `customer = find_customer!`; `vehicle = find_vehicle_for!(customer)`; return `[customer, vehicle]`.
- `find_customer!`: `validate_phone_number!`; `Customer.find_by!(phone_number: normalized_phone_number)`; `ensure_customer_active!(customer)`. On `RecordNotFound` → `RecordInvalid` on `Customer.new(phone_number: phone_number)` with `:phone_number` = **`"was not found"`**.
- `ensure_customer_active!(customer)`: returns customer if `customer.active?`; else `RecordInvalid` on the customer with `:base` = **`"Customer must be active to record transactions"`**.
- `validate_phone_number!`: returns if `Customer.valid_phone_number?(phone_number)`; else `RecordInvalid` on `Customer.new(phone_number: normalized_phone_number.presence || phone_number)` with `:phone_number` = `Customer::PHONE_NUMBER_ERROR_MESSAGE`.
- `normalized_phone_number` = `Customer.normalize_phone_number(phone_number)` (memoized).
- `validate_vehicle_number!`: returns if `Vehicle.valid_vehicle_number?(vehicle_number)`; else `RecordInvalid` on `Vehicle.new(vehicle_number: normalized_vehicle_number.presence || vehicle_number)` with `:vehicle_number` = **`"is invalid"`**.
- `normalized_vehicle_number` = `Vehicle.normalize_vehicle_number(vehicle_number)` (memoized).
- `find_vehicle_by_lookup!`: `validate_vehicle_number!`; `vehicle = Vehicle.includes(:customer).find(vehicle_id)`; if `vehicle.vehicle_number == normalized_vehicle_number` return it; else `RecordInvalid` on `Transaction.new` with `:vehicle` = **`"must match the entered vehicle number"`**. On `RecordNotFound` (from `.find`) → `RecordInvalid` on `Transaction.new` with `:vehicle` = **`"must be selected from the matched customer list"`**.
- `find_vehicle_for!(customer)`: `customer.vehicles.find(vehicle_id)`; on `RecordNotFound` → `RecordInvalid` on `Transaction.new` with `:vehicle` = **`"must belong to the selected customer"`**.

**Fuel pump / nozzle resolution** — `resolve_fuel_pump_and_nozzle!(vehicle)`:
- **Branch A — nozzle feature OFF** (`RewardSetting.current.nozzle_feature_enabled?` is false): return `resolve_selected_pump!`:
  - `fuel_pump = FuelPump.active.find_by(id: fuel_pump_id)`; if nil → `RecordInvalid` on `Transaction.new`, `:fuel_pump` = **`"must be selected from active pumps"`**. Returns `[fuel_pump, nil]` (no nozzle).
- **Branch B — nozzle feature ON**:
  1. `fuel_pump = user.transaction_fuel_pump`; if nil → `RecordInvalid` on `Transaction.new`, `:base` = **`"Set up My Pump with at least one active nozzle before recording a transaction"`**.
  2. `fuel_pump_nozzle = user.transaction_fuel_pump_nozzles.find_by(id: fuel_pump_nozzle_id)`; if nil → `RecordInvalid` on `Transaction.new`, `:fuel_pump_nozzle` = **`"must be selected from your assigned nozzles"`**.
  3. Fuel-type match: if `normalized_fuel_type_code(fuel_pump_nozzle.fuel_type_code) != normalized_fuel_type_code(vehicle.fuel_type)` → `RecordInvalid` on `Transaction.new`, `:fuel_pump_nozzle` = **`"must match the selected vehicle's fuel type"`**.
  4. Return `[fuel_pump, fuel_pump_nozzle]`.
- `normalized_fuel_type_code(value)` = `value.to_s.parameterize(separator: "_").presence` (lowercased, non-alnum → `_`, blank → `nil`).

**Payment mode** — `resolve_payment_mode!`:
- `normalized_payment_mode = payment_mode.to_s`; return it if `Transaction.payment_modes.key?(normalized_payment_mode)` (validates against the model's `payment_mode` enum keys).
- Else `RecordInvalid` on `Transaction.new`, `:payment_mode` = **`"must be cash or credit"`**.

**Transaction/locking**: entire `#call` runs inside `ActiveRecord::Base.transaction` → transaction insert + earn-ledger insert commit/rollback together. No explicit row locks.

**External dependencies**: `Customer` (`valid_phone_number?`, `normalize_phone_number`, `PHONE_NUMBER_ERROR_MESSAGE`, `find_by!`, instance `active?`, `rewards_paused?`, `transactions`, `points_ledgers`, `vehicles`); `Vehicle` (`valid_vehicle_number?`, `normalize_vehicle_number`, `includes(:customer).find`, instance `customer`, `vehicle_number`, `fuel_type`, `vehicle_kind`); `RewardSetting.current.nozzle_feature_enabled?`; `user.transaction_fuel_pump`, `user.transaction_fuel_pump_nozzles`; `FuelPump.active`; `fuel_pump_nozzle.fuel_type_code`; `Transaction.payment_modes` (enum), `entry_type: :earn` enum, ledger `fuel_transaction` association; `PointsCalculator.call`.

---

### Cross-service notes for the API layer
- **Error contract**: none of the three return error objects — failures raise `ActiveRecord::RecordInvalid`. The API layer must `rescue ActiveRecord::RecordInvalid => e` and serialize `e.record.errors` (`full_messages` or per-attribute). Attribute keys used: `:points`, `:phone_number`, `:vehicle`, `:vehicle_number`, `:fuel_pump`, `:fuel_pump_nozzle`, `:payment_mode`, `:base`.
- **Success contract**: `Result` structs (`keyword_init: true`) — `PointsRedeemer::Result{customer, points_redeemed, cash_reward_amount}`, `TransactionCreator::Result{customer, transaction, points_earned, rewards_paused}`. `PointsCalculator.call` returns a bare Integer.
- **Sign convention**: `:redeem` ledger `points` are stored **negative** (`-points_to_redeem`); `:earn` are positive.
- **Paused customer**: `PointsRedeemer` rejects redemption entirely (error); `TransactionCreator` still creates the transaction but awards `points_earned = 0` and creates NO earn ledger entry, `rewards_paused: true`.
- File paths: `/Users/achalindiresh/workspace/fuel-loyalty/app/services/points_calculator.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/services/points_redeemer.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/services/transaction_creator.rb`.