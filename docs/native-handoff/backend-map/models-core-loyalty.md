## models:core-loyalty

Replication reference for `Customer`, `Vehicle`, `Transaction`, `PointsLedger`, `ApplicationRecord`. All user-facing strings quoted verbatim; integer enum values are load-bearing. Column types/defaults from `db/schema.rb`.

External collaborators referenced (NOT in these files — the API layer must reuse them): `VehiclePlateText` (`STANDARD_REGEX`, `BH_REGEX`, `.normalize`, `.valid?`, `.normalize_detected`), `VehicleType` (`.normalize_code`, `.label_for`, `.exists?(code:)`, `.active_code?`, `.minimum_redeemable_points_for_codes`), `FuelType` (`.exists?(code:)`, `.active_code?`, `.label_for`), `RewardSetting` (`.current`, `#effective_minimum_redeemable_points`, `#redemption_increment`, `#cash_value_for_points`), `PointsRedeemer` (`.max_redeemable_points`).

---

### ApplicationRecord
- `class ApplicationRecord < ActiveRecord::Base` with `primary_abstract_class`. No shared behavior; abstract base only.

---

### Customer (`customers`)

**Columns / types / DB defaults**
| Column | Type | Default | Null |
|---|---|---|---|
| `id` | bigint PK | — | no |
| `active` | boolean | `true` | no |
| `created_at` | datetime | — | no |
| `name` | string | — | yes |
| `phone_number` | string | — | no |
| `rewards_paused` | boolean | `false` | no |
| `updated_at` | datetime | — | no |
| `vehicle_number` | string | — | yes |

Index: `index_customers_on_phone_number` UNIQUE on `phone_number`. (No `active`/`rewards_paused` enum declared — these are plain booleans; `active?`/`rewards_paused?` are Rails boolean attribute query methods.)

**Constants**
- `PHONE_NUMBER_LENGTH = 10`
- `PHONE_NUMBER_FORMAT = /\A\d{10}\z/`
- `PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit number"`

**Associations**
- `has_many :transactions, dependent: :restrict_with_exception` (raises `ActiveRecord::DeleteRestrictionError` if any transactions exist on destroy)
- `has_many :points_ledgers, dependent: :destroy`
- `has_many :vehicles, -> { order(:vehicle_number) }, dependent: :destroy` (default-ordered by `vehicle_number` asc)

**Callbacks (order)**
1. `before_validation :normalize_phone_number` → `self.phone_number = normalize_phone_number(phone_number)` = strips all non-digits: `phone_number.to_s.gsub(/\D/, "")`.

**Validations**
- `name`: presence → default message `"can't be blank"`
- `phone_number`: presence (`"can't be blank"`), uniqueness (`"has already been taken"`; DB-enforced case-sensitive via unique index)
- `phone_number`: format `PHONE_NUMBER_FORMAT` with message `"must be a 10 digit number"`

**Class methods**
- `self.normalize_phone_number(value)` → `value.to_s.gsub(/\D/, "")` (String of digits only)
- `self.valid_phone_number?(value)` → `normalize_phone_number(value).match?(/\A\d{10}\z/)` → Boolean

**Public instance methods (API-returnable values)**
- `status_label` → `active? ? "Active" : "Inactive"`
- `rewards_status_label` → `rewards_paused? ? "Rewards Paused" : "Rewards Active"`
- `rewards_enabled?` → `active? && !rewards_paused?` (Boolean)
- `total_points` → Integer. If the record carries a selected `total_points_sum` attribute (`has_attribute?(:total_points_sum)`), returns `self[:total_points_sum].to_i`; else `points_ledgers.sum(:points)` (SQL SUM of ledger `points`, signed). API must decide whether to eager-select `total_points_sum` or accept the aggregate query.
- `minimum_redeemable_points` → Integer. Computes `fallback = VehicleType.minimum_redeemable_points_for_codes(registered_vehicle_type_codes)`, then `RewardSetting.current.effective_minimum_redeemable_points(fallback: fallback)`.
- `max_redeemable_points` → Integer. Returns `0` if `rewards_paused?`. Else `PointsRedeemer.max_redeemable_points(total_points, minimum_redeemable_points:, redemption_increment: RewardSetting.current.redemption_increment)`.
- `points_until_redeemable` → `[minimum_redeemable_points - total_points.to_i, 0].max` (Integer, never negative)
- `recent_transactions(limit = 5)` → ActiveRecord relation of `transactions`, `includes(:points_ledger, :fuel_pump, :vehicle, :user, fuel_pump_nozzle: [:fuel_pump, :fuel_type_record])`, `order(created_at: :desc)`, `limit(limit)`.
- `loyalty_activities(limit: 5)` → relation of `points_ledgers`, `includes(fuel_transaction: :vehicle)`, `where(entry_type: [:earn, :redeem])`, `order(created_at: :desc)`; `.limit(limit)` applied only if `limit` truthy (pass `limit: nil` for unlimited).
- `loyalty_activities_count` → `points_ledgers.where(entry_type: [:earn, :redeem]).count` (Integer)
- `display_name` → `name.presence || "Customer"`

**Private**
- `normalize_phone_number` (callback body, above).
- `registered_vehicle_type_codes` → if vehicles association loaded: `vehicles.map(&:vehicle_kind)`; else `vehicles.reorder(nil).distinct.pluck(:vehicle_kind)` (Array of kind codes, deduped when hitting DB).

---

### Vehicle (`vehicles`)

**Columns / types / DB defaults**
| Column | Type | Default | Null |
|---|---|---|---|
| `id` | bigint PK | — | no |
| `commercial_address` | text | — | yes |
| `commercial_company_name` | string | — | yes |
| `commercial_contact_name` | string | — | yes |
| `commercial_contact_phone_number` | string | — | yes |
| `commercial_notes` | text | — | yes |
| `created_at` | datetime | — | no |
| `customer_id` | bigint FK | — | no |
| `fuel_type` | string | — | no |
| `updated_at` | datetime | — | no |
| `vehicle_kind` | string | — | no |
| `vehicle_number` | string | — | no |

Indexes: `index_vehicles_on_customer_id_and_vehicle_number` UNIQUE on `(customer_id, vehicle_number)`; `index_vehicles_on_customer_id`. FK `vehicles → customers`.

**Constants**
- `STANDARD_VEHICLE_NUMBER_REGEX = VehiclePlateText::STANDARD_REGEX`
- `BH_VEHICLE_NUMBER_REGEX = VehiclePlateText::BH_REGEX`
- `COMMERCIAL_VEHICLE_KINDS = %w[lcv mcv hcv].freeze` (light/medium/heavy commercial vehicle codes)
- `COMMERCIAL_REGISTRATION_FIELDS = %w[commercial_company_name commercial_contact_name commercial_contact_phone_number commercial_address commercial_notes].freeze`

**Associations**
- `belongs_to :customer` (required by default)
- `has_many :transactions, dependent: :restrict_with_exception` (destroy raises if transactions exist)

**Callbacks (order — all `before_validation`)**
1. `normalize_fuel_type` → `self.fuel_type = fuel_type.to_s.parameterize(separator: "_").presence` (lowercased, non-alnum→`_`; empty→`nil`)
2. `normalize_vehicle_kind` → `self.vehicle_kind = VehicleType.normalize_code(vehicle_kind)`
3. `normalize_vehicle_number` → `self.vehicle_number = VehiclePlateText.normalize(vehicle_number)`
4. `normalize_commercial_registration_fields`:
   - `commercial_company_name = commercial_company_name.to_s.squish.presence`
   - `commercial_contact_name = commercial_contact_name.to_s.squish.presence`
   - `commercial_contact_phone_number = Customer.normalize_phone_number(commercial_contact_phone_number).presence` (digits only)
   - `commercial_address = commercial_address.to_s.strip.presence`
   - `commercial_notes = commercial_notes.to_s.strip.presence`
5. `clear_commercial_registration_fields_unless_commercial` → if NOT `commercial_vehicle?`, sets all five commercial fields to `nil`. (Runs AFTER normalization, so non-commercial vehicles always persist `nil` commercial fields.)

**Validations**
- `fuel_type`: presence → `"can't be blank"`
- `vehicle_kind`: presence → `"can't be blank"`
- `vehicle_number`: presence (`"can't be blank"`) + uniqueness `scope: :customer_id, case_sensitive: false` → `"has already been taken"` (unique per customer, case-insensitive)
- `commercial_company_name`: presence `if: :commercial_vehicle?` → `"can't be blank"`
- `commercial_contact_name`: presence `if: :commercial_vehicle?` → `"can't be blank"`
- `commercial_address`: presence `if: :commercial_vehicle?` → `"can't be blank"`
- (NOTE: `commercial_contact_phone_number` and `commercial_notes` are NOT presence-required even for commercial vehicles.)

**Custom `validate` methods (in declared order)** — each early-returns when the attribute is blank:
- `fuel_type_must_exist_for_new_selection`: skip if blank; skip if `FuelType.exists?(code: fuel_type)`; skip if `persisted? && fuel_type == fuel_type_in_database` (grandfathering existing value). Else `errors.add(:fuel_type, "is not available")`.
- `fuel_type_must_be_active_for_new_selection`: skip if blank; skip unless `FuelType.exists?(code:)`; skip if `FuelType.active_code?(fuel_type)`; skip if persisted && unchanged from DB. Else `errors.add(:fuel_type, "is not currently active")`.
- `vehicle_kind_must_exist_for_new_selection`: analogous → `errors.add(:vehicle_kind, "is not available")`.
- `vehicle_kind_must_be_active_for_new_selection`: analogous → `errors.add(:vehicle_kind, "is not currently active")`.
- `vehicle_number_format`: skip if blank; valid if matches `STANDARD_VEHICLE_NUMBER_REGEX` OR `BH_VEHICLE_NUMBER_REGEX`. Else `errors.add(:vehicle_number, "is invalid")`.
- `commercial_contact_phone_number_format`: skip if blank; valid if `Customer.valid_phone_number?(...)`. Else `errors.add(:commercial_contact_phone_number, Customer::PHONE_NUMBER_ERROR_MESSAGE)` = `"must be a 10 digit number"`.

**Class methods**
- `self.normalize_vehicle_number(value)` → `VehiclePlateText.normalize(value)`
- `self.commercial_vehicle_kind?(value)` → `COMMERCIAL_VEHICLE_KINDS.include?(VehicleType.normalize_code(value))` → Boolean
- `self.valid_vehicle_number?(value)` → `VehiclePlateText.valid?(value)` → Boolean
- `self.normalize_detected_vehicle_number(value)` → `VehiclePlateText.normalize_detected(value)` (OCR/detected-plate normalization variant)

**Public instance methods**
- `display_fuel_type` → `FuelType.label_for(fuel_type).presence || fuel_type.to_s.humanize`
- `display_vehicle_kind` → `VehicleType.label_for(vehicle_kind).presence || vehicle_kind.to_s.humanize`
- `display_name` → `"#{vehicle_number} | #{display_fuel_type} | #{display_vehicle_kind}"` (pipe-separated, spaces around `|`)
- `commercial_vehicle?` → `self.class.commercial_vehicle_kind?(vehicle_kind)` → Boolean
- Dynamically defined getters/setters for each of the 5 `COMMERCIAL_REGISTRATION_FIELDS` (override the AR accessors):
  - getter `field` → returns `self[field]` only if `commercial_registration_fields_supported?`, else `nil`.
  - setter `field=` → sets `self[field] = value` only if supported; else returns `value` without writing (no-op).
- `commercial_registration_present?` → `true` if ANY of the 5 commercial fields is present (`.any?(&:present?)`)
- `commercial_contact_summary` → `nil` if both company and contact name blank; else `[commercial_company_name, commercial_contact_name].compact.join(" · ")` (joined by `" · "`, middle-dot U+00B7 with surrounding spaces)

**Private**
- The five normalization + clear callbacks (above), the six `validate` methods (above), and:
- `commercial_registration_fields_supported?` → `COMMERCIAL_REGISTRATION_FIELDS.all? { |f| self.class.attribute_names.include?(f) }` (schema-presence guard; true given current schema). This gates the dynamic accessors — commercial fields are only readable/writable when all 5 columns exist.

---

### Transaction (`transactions`)

**Columns / types / DB defaults**
| Column | Type | Default | Null |
|---|---|---|---|
| `id` | bigint PK | — | no |
| `created_at` | datetime | — | no |
| `customer_id` | bigint FK | — | no |
| `fuel_amount` | decimal(10,2) | — | no |
| `fuel_pump_id` | bigint FK | — | yes |
| `fuel_pump_nozzle_id` | bigint FK | — | yes |
| `payment_mode` | string | `"cash"` | no |
| `updated_at` | datetime | — | no |
| `user_id` | bigint FK | — | no |
| `vehicle_id` | bigint FK | — | yes |

Indexes on `customer_id`, `fuel_pump_id`, `fuel_pump_nozzle_id`, `user_id`, `vehicle_id`. FKs → `customers`, `fuel_pump_nozzles`, `fuel_pumps`, `users`, `vehicles`.

**Associations**
- `belongs_to :customer` (required)
- `belongs_to :user` (required)
- `belongs_to :vehicle` (required — NOTE: model declares required, but DB column `vehicle_id` is nullable; the `presence: true` validation is the enforcement)
- `belongs_to :fuel_pump, optional: true`
- `belongs_to :fuel_pump_nozzle, optional: true`
- `has_one :points_ledger, foreign_key: :transaction_id, dependent: :restrict_with_exception` (destroy raises if a ledger row references it)

**Enums**
- `enum :payment_mode, { cash: "cash", credit: "credit" }, default: :cash` — **STRING-backed** (DB stores `"cash"`/`"credit"`). Default `:cash`. Generates `cash?`/`credit?`, `cash!`/`credit!` bang methods, and scopes `Transaction.cash`/`Transaction.credit`.

**Validations**
- `vehicle`: presence → `"must exist"` (belongs_to presence uses association message; effectively `"can't be blank"`/`"must exist"`)
- `fuel_amount`: numericality `greater_than: 0` → `"must be greater than 0"`
- `payment_mode`: presence → `"can't be blank"`

No custom callbacks, scopes (beyond enum-generated), or computed public methods defined.

---

### PointsLedger (`points_ledgers`)

**Columns / types / DB defaults**
| Column | Type | Default | Null |
|---|---|---|---|
| `id` | bigint PK | — | no |
| `cash_reward_amount` | decimal(12,2) | — | yes |
| `created_at` | datetime | — | no |
| `customer_id` | bigint FK | — | no |
| `entry_type` | integer | — | no |
| `points` | integer | — | no |
| `transaction_id` | bigint FK | — | yes |
| `updated_at` | datetime | — | no |

Indexes on `customer_id`, `transaction_id`. FKs → `customers`, `transactions`.

**Associations**
- `belongs_to :customer` (required)
- `belongs_to :fuel_transaction, class_name: "Transaction", foreign_key: :transaction_id, optional: true` (aliased association name; API relates a ledger to its transaction via `fuel_transaction`)

**Enums**
- `enum :entry_type, { earn: 0, redeem: 1, expire: 2, adjust: 3 }, validate: true` — **INTEGER-backed** (load-bearing values): `earn=0`, `redeem=1`, `expire=2`, `adjust=3`. `validate: true` adds inclusion validation → invalid value message `"is not included in the list"`. Generates `earn?`…`adjust?`, bang methods, scopes `PointsLedger.earn` etc.

**Callbacks**
- `before_validation :snapshot_cash_reward_amount, on: :create` (create only): returns early unless `supports_cash_reward_amount?`; returns early if `self[:cash_reward_amount]` already present (does not overwrite a provided value); else sets `self[:cash_reward_amount] = RewardSetting.current.cash_value_for_points(points.to_i.abs)` (uses absolute points → cash conversion). Rescues `ActiveRecord::NoDatabaseError` / `ActiveRecord::StatementInvalid` by setting `cash_reward_amount = nil` (when supported). So on create, cash reward is snapshotted from current reward settings unless explicitly supplied.

**Validations**
- `cash_reward_amount`: numericality `greater_than_or_equal_to: 0`, `allow_nil: true`, `if: :supports_cash_reward_amount?` → message `"must be greater than or equal to 0"`
- `points`: numericality `only_integer: true` → `"must be an integer"`
- `entry_type`: presence → `"can't be blank"` (plus enum inclusion from `validate: true`)

**Public instance methods**
- `recorded_cash_reward?` → `recorded_cash_reward_amount.present?` (Boolean)
- `recorded_cash_reward_amount` → `nil` unless `supports_cash_reward_amount?`; else `self[:cash_reward_amount]` (BigDecimal or nil). This is the raw stored snapshot the API should surface for reward value.

**Private**
- `snapshot_cash_reward_amount` (callback, above)
- `supports_cash_reward_amount?` → `self.class.attribute_names.include?("cash_reward_amount")` (schema guard; true in current schema)

---

### Cross-model notes for the API layer
- **`points` sign convention**: `earn` positive, `redeem` negative (implied — `Customer#total_points` sums raw `points`; `snapshot_cash_reward_amount` uses `.abs`). API must preserve sign when writing ledgers.
- **Destroy restrictions**: Customer with transactions → blocked (`restrict_with_exception`); Vehicle with transactions → blocked; Transaction with a points_ledger → blocked. Customer destroy cascades vehicles + points_ledgers. Handle `ActiveRecord::DeleteRestrictionError` in API delete endpoints.
- **Phone normalization is shared**: `Customer.normalize_phone_number` is reused by `Vehicle` for `commercial_contact_phone_number`. Both strip to digits and validate `/\A\d{10}\z/`.
- **Commercial fields are conditional**: only meaningful/persisted when `vehicle_kind ∈ {lcv,mcv,hcv}`; otherwise force-nulled before save. API responses should treat them as null for non-commercial vehicles regardless of input.
- **Grandfathering**: existing vehicles keep an unavailable/inactive `fuel_type`/`vehicle_kind` on update as long as the value is unchanged from DB; a *new* selection must be an existing + active code.