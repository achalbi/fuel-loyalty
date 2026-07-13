## controllers:staff

Rails MVC (Pundit auth) subsystem under `Staff::` namespace. All controllers subclass `Staff::BaseController`. Policies/services/models referenced but NOT in scope (not read): `TransactionPolicy`, `CustomerPolicy`, `PointsLedgerPolicy`, `TransactionCreator`, `PointsRedeemer`, `VehiclePlateRecognizer`, `Customer`, `Vehicle`, `RewardSetting`, `FuelPump`. Policy calls are noted so the API layer can reproduce authorization.

---

### `Staff::BaseController` (`app/controllers/staff/base_controller.rb`)
Abstract base; `< ApplicationController`.

**before_action (order, applies to ALL staff controllers):**
1. `authenticate_user!` (Devise) — 401/redirect to login if unauthenticated.
2. `ensure_staff_access`

**`ensure_staff_access` (private):** returns if `current_user&.admin? || current_user&.staff?`; else `raise Pundit::NotAuthorizedError, "not allowed"`. (i.e. only users where `admin?` OR `staff?` are true may reach ANY staff action.)

**`register_customer_prefill_path(phone_number: nil, vehicle_number: nil)` (private helper):** builds `new_staff_customer_path` (GET /staff/customers/new) with query `{ phone_number: Customer.normalize_phone_number(phone_number).presence, vehicle_number: Vehicle.normalize_vehicle_number(vehicle_number).presence }.compact_blank`. Used to seed "register" links in lookup 404 responses.

---

### `Staff::TransactionsController` (`app/controllers/staff/transactions_controller.rb`)

Inherits base before_actions. No CSRF exemption / no token auth declared (standard Rails form CSRF).

#### `new` — GET `/staff/transactions/new`
- Auth: `authorize Transaction` (→ `TransactionPolicy#new?`).
- Sets: `assign_prefill_values`; `@auto_open_plate_scanner = params[:plate_scanner].present? && @active_lookup_mode == "vehicle"`; `load_transaction_pump_state`; `prepare_registration_modal`.
- Renders HTML `:new`. No flash.

#### `lookup` — GET `/staff/transactions/lookup` (collection)
- Auth: `authorize Transaction, :new?`.
- Input: `params[:vehicle_number]` → `normalized = Vehicle.normalize_vehicle_number(...)`.
- Branch A — invalid: `unless Vehicle.valid_vehicle_number?(normalized)` → JSON `{ found: false, message: "Vehicle number is invalid." }`, status **422 unprocessable_entity**.
- Query: `Vehicle.includes(customer: :vehicles).where(vehicle_number: normalized)`, then Ruby-sorted by `[customer.display_name.downcase, customer.phone_number]`.
- Branch B — matches present: JSON **200**:
```
{ found: true,
  matches: [ { vehicle_id, vehicle_number, fuel_type_code: <vehicle.fuel_type>,
               fuel_type: <vehicle.display_fuel_type>, vehicle_kind_code: <vehicle.vehicle_kind>,
               vehicle_kind: <vehicle.display_vehicle_kind>,
               customer: <customer_payload> } , ... ] }
```
- Branch C — none: JSON **404 not_found** `{ found: false, message: "No customer was found for that vehicle number.", register_customer_path: <register_customer_prefill_path(vehicle_number: normalized)> }`.

`customer_payload(customer)` shape (also used elsewhere):
```
{ id, name: <display_name>, phone_number, active: <active?>, rewards_paused: <rewards_paused?>,
  rewards_status_label, status_label, total_points,
  vehicles: [ { id, vehicle_number, fuel_type_code: <fuel_type>, fuel_type: <display_fuel_type>,
                vehicle_kind_code: <vehicle_kind>, vehicle_kind: <display_vehicle_kind>, display_name } ] }
```

#### `create` — POST `/staff/transactions`
- Auth: `authorize Transaction` (→ `#new?`).
- Calls `TransactionCreator.call(user: current_user, **transaction_params.to_h.symbolize_keys)`.
- Success: builds `flash_payload`:
  - If `result.rewards_paused` truthy → `flash_payload[:notice] = "Transaction recorded. Rewards are paused for this customer, so no points were added."`
  - Else → `flash_payload[:transaction_summary] = { points_earned: result.points_earned, current_points: result.customer.total_points }` (a HASH flash, not a string).
  - `redirect_to customer_path(result.customer)` (→ GET `/customers/:id`, HTTP 302) with that flash.
- Failure `rescue ActiveRecord::RecordInvalid => e`: `@errors = e.record.errors.full_messages`; `@transaction_error_step = transaction_error_step(e.record.errors)`; re-run `assign_prefill_values`, `load_transaction_pump_state`, `prepare_registration_modal`; render HTML `:new`, status **422**.

`transaction_error_step(errors)` (drives which UI step to show): map attribute_names→sym; returns `"fuel"` if any of `[:base, :fuel_amount, :fuel_pump, :fuel_pump_id, :fuel_pump_nozzle, :fuel_pump_nozzle_id, :payment_mode]`; else `"review"` if includes `:vehicle`; else `"lookup"`.

#### `recognize_plate` — POST `/staff/transactions/recognize_plate` (collection)
- Auth: `authorize Transaction, :new?`.
- Input: `image_data = params.dig(:plate_scan, :image_data).presence || params[:image_data]`.
- Calls `VehiclePlateRecognizer.call(image_data:)`.
- If `result.found` → JSON **200** `result.as_json` (shape defined by recognizer service).
- Else → JSON **422** `{ found: false, message: "No clear vehicle number could be recognized. Please retake the photo." }`.
- `rescue VehiclePlateRecognizer::ConfigurationError => error` → JSON **503 service_unavailable** `{ found: false, message: error.message }`.
- `rescue VehiclePlateRecognizer::RecognitionError => error` → JSON **502 bad_gateway** `{ found: false, message: error.message }`.

#### `register_customer` — POST `/staff/transactions/register_customer` (collection)
- Builds `customer = build_registration_customer`; `existing_customer = customer.persisted?`.
- Auth: `authorize customer, existing_customer ? :update? : :create?` (→ `CustomerPolicy#update?` or `#create?`).
- `registration_saved, saved_vehicle = persist_registration_customer_with_vehicle(customer, existing_customer:)`.
- Success: `redirect_to new_staff_transaction_path(transaction: <transaction_prefill_for_registered_customer>)` (GET `/staff/transactions/new`, 302) with `notice: registration_success_notice(...)`.
- Failure: `assign_prefill_values`; `load_transaction_pump_state`; `prepare_registration_modal(customer:, open: true)`; render HTML `:new`, status **422**.

**Strong params:**
- `transaction_params`: `params.require(:transaction).permit(:lookup_mode, :phone_number, :vehicle_number, :vehicle_id, :fuel_amount, :fuel_pump_id, :fuel_pump_nozzle_id, :payment_mode)`.
- `registration_customer_params`: `params.require(:customer).permit(:name, :phone_number, :vehicle_number, :fuel_type, :vehicle_kind, :commercial_company_name, :commercial_contact_name, :commercial_contact_phone_number, :commercial_address, :commercial_notes)`.
- `transaction_lookup_params`: `params.require(:transaction_lookup).permit(:lookup_mode, :phone_number, :vehicle_number, :fuel_amount, :fuel_pump_id, :fuel_pump_nozzle_id, :payment_mode, :lock_vehicle_details)`.

**Private helpers (business logic the API must reproduce):**
- `assign_prefill_values`: defaults `@active_lookup_mode="vehicle"`, `@prefill_payment_mode="cash"`; source = `transaction_prefill_source`; if present sets `@active_lookup_mode = normalized_lookup_mode(source[:lookup_mode])`, `@prefill_phone_number`, `@prefill_vehicle_number`, `@prefill_vehicle_id`, `@prefill_fuel_amount`, `@prefill_fuel_pump_id`, `@prefill_fuel_pump_nozzle_id`, `@prefill_payment_mode = normalized_payment_mode(source[:payment_mode])`, `@transaction_registration_vehicle_details_locked = ActiveModel::Type::Boolean.new.cast(source[:lock_vehicle_details])`.
- `transaction_prefill_source`: `transaction_params` if `params[:transaction]` present; elsif `params[:transaction_lookup]` present → `transaction_lookup_params`; else `{}`.
- `normalized_lookup_mode(v)`: `%w[phone vehicle].include?(v.to_s) ? v.to_s : "vehicle"`.
- `normalized_payment_mode(v)`: `%w[cash credit].include?(v.to_s) ? v.to_s : "cash"`.
- `prepare_registration_modal(customer: Customer.new, open: false)`: sets `@registration_customer`, `@transaction_registration_modal_open`.
- `load_transaction_pump_state`: `@nozzle_feature_enabled = RewardSetting.current.nozzle_feature_enabled?`. If enabled: `@transaction_fuel_pump = current_user.transaction_fuel_pump`, `@transaction_fuel_pump_nozzles = current_user.transaction_fuel_pump_nozzles.to_a`, `@transaction_fuel_pumps = []`. Else: `@transaction_fuel_pump = nil`, `@transaction_fuel_pump_nozzles = []`, `@transaction_fuel_pumps = FuelPump.active.ordered.to_a`.
- `build_registration_customer`: normalize phone; if `Customer.find_by(phone_number:)` exists → return it (existing); else `Customer.new(phone_number:)` and set `name` (if present) and `vehicle_number` (normalized, if `respond_to?(:vehicle_number=)`).
- `save_registration_vehicle(customer)`: `customer.vehicles.find_or_initialize_by(vehicle_number: normalized)`; return vehicle if already persisted; else assign `fuel_type, vehicle_kind, commercial_company_name, commercial_contact_name, commercial_contact_phone_number, commercial_address, commercial_notes` from `registration_customer_params`; `return vehicle if vehicle.save`; on failure copy each vehicle error onto `customer.errors` and return `false`.
- `persist_registration_customer_with_vehicle(customer, existing_customer:)`: `return [false, nil] unless registration_fields_present?`. Inside `Customer.transaction do`: rollback unless `existing_customer || customer.save`; `saved_vehicle = save_registration_vehicle(customer)`; rollback if `saved_vehicle == false`; set `success = true`. Returns `[success, saved_vehicle]`. **DB transaction present.**
- `registration_fields_present?(customer, existing_customer:)`: runs `customer.valid?` unless existing; required = `{name, phone_number, vehicle_number, fuel_type, vehicle_kind}` from params; for each blank adds `customer.errors.add(field, "can't be blank")`; returns `customer.errors.none?`.
- `transaction_prefill_for_registered_customer(customer, vehicle)`: reads `fuel_amount, lookup_mode(normalized), fuel_pump_id, fuel_pump_nozzle_id, payment_mode(normalized)` from `transaction_lookup_params`. If `lookup_mode=="vehicle" && vehicle.present?` → `{lookup_mode:"vehicle", vehicle_number:, vehicle_id:, fuel_amount:, fuel_pump_id:, fuel_pump_nozzle_id:, payment_mode:}.compact_blank`; else `{lookup_mode:"phone", phone_number: customer.phone_number, vehicle_id: vehicle&.id, fuel_amount:, fuel_pump_id:, fuel_pump_nozzle_id:, payment_mode:}.compact_blank`.
- `registration_success_notice(existing_customer:, vehicle:)`: `"Customer created successfully. Continue recording the transaction."` if NOT existing; `"Vehicle added to the existing customer. Continue recording the transaction."` if `vehicle&.previously_new_record?`; else `"Existing customer details loaded. Continue recording the transaction."`.

---

### `Staff::CustomersController` (`app/controllers/staff/customers_controller.rb`)

Inherits base before_actions.

#### `index` — GET `/staff/customers`
- Auth: `authorize Customer, :lookup?` (→ `CustomerPolicy#lookup?`).
- `load_index_state` → sets `@query = params[:q].to_s.strip`, `@customers = customer_scope`, `@customer = Customer.new`. HTML render.

#### `new` — GET `/staff/customers/new`
- `@customer = Customer.new(new_customer_prefill_attributes)`; `authorize @customer` (→ `CustomerPolicy#new?`). HTML.
- `new_customer_prefill_attributes`: `{ phone_number: Customer.normalize_phone_number(params[:phone_number]).presence, vehicle_number: Vehicle.normalize_vehicle_number(params[:vehicle_number]).presence }.compact_blank`.

#### `create` — POST `/staff/customers`
- `normalized_phone = Customer.normalize_phone_number(customer_params[:phone_number])`; `@customer = Customer.new(phone_number: normalized_phone)`; `authorize @customer` (→ `#create?`); set `@customer.name` if `customer_params[:name]` present.
- If `persist_customer_with_vehicle` → `redirect_to customer_path(@customer)` (GET `/customers/:id`, 302), `notice: "Customer created successfully."`.
- Else → `load_index_state(form_customer: @customer)`; render HTML `:index`, status **422**.

#### `lookup` — GET `/staff/customers/lookup` (collection)
- Auth: `authorize Customer, :lookup?`.
- `reward_setting = RewardSetting.current`; `normalized_phone = Customer.normalize_phone_number(params[:phone_number])`.
- Invalid: `unless Customer.valid_phone_number?(normalized_phone)` → JSON **422** `{ found: false, message: "Phone number must be a 10 digit number." }`.
- `customer = Customer.includes(:vehicles).find_by(phone_number: normalized_phone)`.
- Found → JSON **200**:
```
{ found: true,
  customer: {
    id, name: <display_name>, phone_number, active: <active?>, rewards_paused: <rewards_paused?>,
    rewards_status_label, status_label, total_points,
    cash_value_per_point: <reward_setting.cash_value_per_point&.to_f>,
    total_points_cash_reward: <reward_setting.cash_value_for_points(total_points)&.to_f>,
    minimum_redeemable_points: <customer.minimum_redeemable_points>,
    redemption_increment: <reward_setting.redemption_increment>,
    max_redeemable_points: <customer.max_redeemable_points>,
    max_redeemable_cash_reward: <reward_setting.cash_value_for_points(max_redeemable_points)&.to_f>,
    vehicles: [ { id, vehicle_number, fuel_type_code: <fuel_type>, fuel_type: <display_fuel_type>,
                  vehicle_kind: <display_vehicle_kind>, display_name } ] } }
```
(NOTE: this vehicles sub-shape omits `vehicle_kind_code`, unlike the transactions `customer_payload`.)
- Not found → JSON **404** `{ found: false, message: "Customer not found for that phone number.", register_customer_path: <register_customer_prefill_path(phone_number: normalized_phone)> }`.

#### `activate` — PATCH `/staff/customers/:id/activate` (member)
- `update_status!(true, "Customer activated successfully.")`.

#### `deactivate` — PATCH `/staff/customers/:id/deactivate` (member)
- `update_status!(false, "Customer marked as inactive.")`.

`update_status!(active, notice_message)`: `customer = Customer.find(params[:id])`; `authorize customer, active ? :activate? : :deactivate?` (→ `CustomerPolicy#activate?`/`#deactivate?`); `customer.update!(active: active)`; `redirect_to customer_path(customer)` (302) with `notice: notice_message`. (`find`/`update!` raise → 404/422 via Rails default handling.)

#### `pause_rewards` — PATCH `/staff/customers/:id/pause_rewards` (member)
- `update_rewards_paused!(true, "Rewards paused for this customer.")`.

#### `resume_rewards` — PATCH `/staff/customers/:id/resume_rewards` (member)
- `update_rewards_paused!(false, "Rewards resumed for this customer.")`.

`update_rewards_paused!(paused, notice_message)`: `Customer.find(params[:id])`; `authorize customer, paused ? :pause_rewards? : :resume_rewards?`; `customer.update!(rewards_paused: paused)`; `redirect_back fallback_location: customer_path(customer)` (302) with `notice: notice_message`. (NOTE: `redirect_back`, not `redirect_to`.)

**Strong params — `customer_params`:** `params.require(:customer).permit(:name, :phone_number, :vehicle_number, :fuel_type, :vehicle_kind, :commercial_company_name, :commercial_contact_name, :commercial_contact_phone_number, :commercial_address, :commercial_notes)`.

**Private helpers:**
- `customer_scope`: if `@query` blank → `top_customers_scope`. Else: `Customer.includes(:vehicles).order(created_at: :desc)`; `escaped = ActiveRecord::Base.sanitize_sql_like(@query)`; `normalized_phone = Customer.normalize_phone_number(@query)`; conditions `["customers.name ILIKE :name"]`, values `{name: "%#{escaped}%"}`; if `normalized_phone.present?` append `"customers.phone_number LIKE :phone"` with `phone: "%#{normalized_phone}%"`; `scope.where(conditions.join(" OR "), values).limit(50)`.
- `top_customers_scope`: `Customer.left_joins(:points_ledgers).includes(:vehicles).select("customers.*, COALESCE(SUM(points_ledgers.points), 0) AS total_points_sum").group("customers.id").order(Arel.sql("COALESCE(SUM(points_ledgers.points), 0) DESC, customers.created_at DESC")).limit(3)` (top-3 by points).
- `save_vehicle`: same pattern as transactions `save_registration_vehicle` but operates on `@customer` and `customer_params`; `find_or_initialize_by(vehicle_number: normalized)`; return if persisted; assign commercial+fuel fields; `vehicle.save.tap {…}` copying errors onto `@customer.errors` on failure (returns the boolean from `save`).
- `persist_customer_with_vehicle`: `return false unless initial_vehicle_fields_present?`; `Customer.transaction do; rollback unless @customer.save && save_vehicle; success=true; end`; returns `success`. **DB transaction.**
- `initial_vehicle_fields_present?`: runs `@customer.valid?`; required `{vehicle_number, fuel_type, vehicle_kind}` from `customer_params`; adds `@customer.errors.add(field, "can't be blank")` for each blank; returns `@customer.errors.none?`. (Unlike registration, does NOT require `name`.)

---

### `Staff::RedemptionsController` (`app/controllers/staff/redemptions_controller.rb`)

Inherits base before_actions.

#### `new` — GET `/staff/redemptions/new`
- Auth: `authorize PointsLedger, :redeem?` (→ `PointsLedgerPolicy#redeem?`).
- `assign_prefill_values`. HTML.

#### `create` — POST `/staff/redemptions`
- Auth: `authorize PointsLedger, :redeem?`.
- `result = PointsRedeemer.call(**redemption_params.to_h.symbolize_keys)`.
- Notice built: `"#{result.points_redeemed} points redeemed successfully."`; if `result.cash_reward_amount.present?` append `" Cash reward: #{helpers.number_to_currency(result.cash_reward_amount, unit: "₹")}."` → full example: `"50 points redeemed successfully. Cash reward: ₹25.00."`.
- `redirect_to customer_path(result.customer)` (302) with `notice:`.
- Failure `rescue ActiveRecord::RecordInvalid => e`: `@errors = e.record.errors.full_messages`; `assign_prefill_values`; render HTML `:new`, status **422**.

**Strong params — `redemption_params`:** `params.require(:redemption).permit(:phone_number, :points)`.

**Private helpers:**
- `assign_prefill_values`: `return unless params[:redemption].present?`; sets `@prefill_phone_number = redemption_params[:phone_number]`, `@prefill_points = redemption_params[:points]`.

---

### `Staff::NotificationsController` (`app/controllers/staff/notifications_controller.rb`)

Inherits base before_actions.

#### `show` — GET `/staff/notifications`
- Empty action body (`def show; end`) → renders HTML `show` view. No auth beyond base filters, no data assigned, no flash.

---

### Cross-cutting notes for the API layer
- **All staff endpoints require** authenticated user AND (`admin?` OR `staff?`); otherwise `Pundit::NotAuthorizedError` (`"not allowed"`).
- Every action additionally runs a per-record/-class Pundit `authorize` (policies listed above but not read here — get exact rules from `TransactionPolicy`, `CustomerPolicy`, `PointsLedgerPolicy`).
- HTML actions render Rails views on 422; JSON actions (`transactions#lookup`, `transactions#recognize_plate`, `customers#lookup`) return JSON with the exact key shapes above. No `respond_to`/format negotiation — JSON actions always render JSON, others always HTML. An `/api/v1` layer must translate the HTML redirect-with-flash flows (create/activate/deactivate/pause/resume/redeem/register_customer) into JSON responses itself; the two lookup JSON shapes and the recognizer JSON are the only existing machine-readable contracts.
- Phone/vehicle normalization is delegated to `Customer.normalize_phone_number` / `Vehicle.normalize_vehicle_number`; validity to `Customer.valid_phone_number?` / `Vehicle.valid_vehicle_number?` (definitions in models, not in scope).
- No CSRF exemptions or token-auth declarations in any of these controllers.