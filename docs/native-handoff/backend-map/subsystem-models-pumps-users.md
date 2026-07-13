## Subsystem: models:pumps-users

### MODEL: `FuelPump` (`app/models/fuel_pump.rb`, table `fuel_pumps`)

**Columns (DB):**
| column | type | null | default |
|---|---|---|---|
| id | bigint (PK) | no | — |
| active | boolean | no | `true` |
| sequence_number | integer | no | — |
| created_at | datetime | no | — |
| updated_at | datetime | no | — |

Indexes: unique on `sequence_number`; index on `active`.

**Associations:**
- `has_many :nozzles` → `FuelPumpNozzle`, scoped `-> { order(:sequence_number, :id) }`, `dependent: :destroy`, `inverse_of: :fuel_pump`.
- `has_many :assigned_users` → `User`, `foreign_key: :fuel_pump_id`, `inverse_of: :assigned_fuel_pump`, `dependent: :nullify` (unassigns users on pump delete).
- `has_many :transactions` (no dependent — blocked by `before_destroy`).
- `accepts_nested_attributes_for :nozzles`, `allow_destroy: true`, `reject_if: :reject_nozzle_attributes?`.

**reject_if rule (`reject_nozzle_attributes?`):** rejects a nested nozzle hash when `attributes["id"].blank? && attributes["fuel_type_code"].to_s.blank?` (i.e. new row with no fuel type is discarded).

**Callbacks (in order):**
1. `before_validation :assign_sequence_number, on: :create` — sets `self.sequence_number ||= next_sequence_number` (only if nil).
2. `before_validation :assign_missing_nozzle_sequence_numbers` (every validation) — see algorithm below.
3. `before_destroy :ensure_not_used_by_transactions` — if `transactions.exists?`, adds error on `:base` = `"cannot be removed while transactions still use it"` and `throw :abort`.

**`assign_missing_nozzle_sequence_numbers` algorithm:**
- `retained = nozzles.reject(&:marked_for_destruction?)`; return if empty.
- `reserved = nozzles.map(&:sequence_number).compact.max.to_i + 1`.
- For each nozzle marked for destruction: set its `sequence_number = reserved`, then `reserved += 1` (parks destroyed rows at high numbers to avoid unique-index collisions).
- `taken = retained.map(&:sequence_number).compact`.
- For each retained nozzle with blank `sequence_number`: assign lowest positive integer starting at 1 not already in `taken`; push assigned value into `taken`.

**Validations:**
- `validate :must_include_at_least_one_nozzle` — if no retained (non-destroyed) nozzle, error on `:nozzles` = `"must include at least one nozzle"`.
- `validates :sequence_number, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }`.
- `validates :active, inclusion: { in: [true, false] }`.

**Scopes:**
- `active` → `where(active: true)`.
- `ordered` → `order(:sequence_number, :id)`.

**Public methods (API-returnable):**
- `self.for_settings` → `includes(nozzles: :fuel_type_record).ordered.to_a`; rescues `ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid` → `[]`.
- `self.next_sequence_number` → `ordered.maximum(:sequence_number).to_i + 1`; rescue same errors → `1`.
- `self.next_display_name` → `"Pump #{next_sequence_number}"`.
- `display_name` → `sequence_number.present? ? "Pump #{sequence_number}" : self.class.next_display_name`.
- `active_nozzles_count` → if `nozzles` association loaded: `nozzles.count(&:active?)`; else `nozzles.active.count` (integer).
- `transaction_remove_error_message` → literal string `"cannot be removed while transactions still use it"`.

---

### MODEL: `FuelPumpNozzle` (`app/models/fuel_pump_nozzle.rb`, table `fuel_pump_nozzles`)

**Columns (DB):**
| column | type | null | default |
|---|---|---|---|
| id | bigint (PK) | no | — |
| active | boolean | no | `true` |
| fuel_pump_id | bigint (FK) | no | — |
| fuel_type_code | string | no | — |
| sequence_number | integer | no | — |
| created_at | datetime | no | — |
| updated_at | datetime | no | — |

Indexes: unique on `[fuel_pump_id, sequence_number]`; index on `active`, `fuel_pump_id`, `fuel_type_code`.

**Associations:**
- `belongs_to :fuel_pump`, `inverse_of: :nozzles` (required by default).
- `belongs_to :fuel_type_record` → `class_name: "FuelType"`, `foreign_key: :fuel_type_code`, `primary_key: :code`, `inverse_of: false`, `optional: true`.
- `has_many :user_pump_nozzle_assignments`, `dependent: :destroy`, `inverse_of: :fuel_pump_nozzle`.
- `has_many :assigned_users, through: :user_pump_nozzle_assignments, source: :user`.
- `has_many :transactions` (blocked by `before_destroy`).

**Callbacks (in order):**
1. `before_destroy :ensure_not_used_by_transactions` — if `transactions.exists?`: error on `:base` = `"cannot be removed while transactions still use it"`, `throw :abort`.
2. `before_validation :normalize_fuel_type_code` — `self.fuel_type_code = fuel_type_code.to_s.parameterize(separator: "_").presence` (lowercases, replaces non-alnum with `_`; blank → `nil`).

> Note: `before_destroy` is declared before `before_validation` in source, but they fire in different lifecycles; both run in declaration order within their own hook.

**Validations:**
- `validates :sequence_number, presence: true, numericality: { only_integer: true, greater_than: 0 }`.
- `validates :fuel_type_code, presence: true`.
- `validates :active, inclusion: { in: [true, false] }`.
- `validate :sequence_number_must_be_unique_within_pump` — skip if `sequence_number.blank? || fuel_pump.blank?`; compares against in-memory sibling nozzles (excluding self and destroyed); if any sibling shares `sequence_number`, error on `:sequence_number` = `"has already been taken"`.
- `validate :fuel_type_must_exist_for_new_selection` — skip if blank; pass if `FuelType.exists?(code: fuel_type_code)`; pass if `persisted? && fuel_type_code == fuel_type_code_in_database`; else error on `:fuel_type_code` = `"is not available"`.
- `validate :fuel_type_must_be_active_for_new_selection` — skip if blank; skip unless `FuelType.exists?(code:)`; pass if `FuelType.active_code?(fuel_type_code)`; pass if unchanged persisted value; else error on `:fuel_type_code` = `"is not currently active"`.

**Scopes:** `active` → `where(active: true)`; `ordered` → `order(:sequence_number, :id)`.

**Public methods (API-returnable):**
- `display_name` → `sequence_number.present? ? "Nozzle #{sequence_number}" : "New Nozzle"`.
- `fuel_type_name` → first non-blank of: `fuel_type_record&.name.presence` → `FuelType.default_label_for(fuel_type_code)` → `FuelType.label_for(fuel_type_code).presence` → `fuel_type_code.to_s.humanize`.

---

### MODEL: `UserPumpNozzleAssignment` (`app/models/user_pump_nozzle_assignment.rb`, table `user_pump_nozzle_assignments`)

**Columns (DB):**
| column | type | null | default |
|---|---|---|---|
| id | bigint (PK) | no | — |
| fuel_pump_nozzle_id | bigint (FK) | no | — |
| user_id | bigint (FK) | no | — |
| created_at | datetime | no | — |
| updated_at | datetime | no | — |

Indexes: unique on `[user_id, fuel_pump_nozzle_id]`; index on `fuel_pump_nozzle_id`, `user_id`.

**Associations:** `belongs_to :user, inverse_of: :pump_nozzle_assignments`; `belongs_to :fuel_pump_nozzle, inverse_of: :user_pump_nozzle_assignments` (both required).

**Validations:** `validates :fuel_pump_nozzle_id, uniqueness: { scope: :user_id }` — default message `"has already been taken"`.

---

### MODEL: `User` (`app/models/user.rb`, table `users`) — Devise model

**Constants:** `PHONE_NUMBER_LENGTH = 10`; `PHONE_NUMBER_FORMAT = /\A\d{10}\z/`; `PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit mobile number"`; `USERNAME_FORMAT = /\A\S+\z/` (no whitespace); `INTERNAL_EMAIL_DOMAIN = "users.fuel-loyalty.local"`.

**Columns (DB):**
| column | type | null | default |
|---|---|---|---|
| id | bigint (PK) | no | — |
| active | boolean | no | `true` |
| deleted_at | datetime | yes | — |
| email | string | no | `""` |
| employee_code | string | yes | — |
| encrypted_password | string | no | `""` |
| fuel_pump_id | bigint (FK) | yes | — |
| name | string | no | — |
| phone_number | string | yes | — |
| remember_created_at | datetime | yes | — |
| reset_password_sent_at | datetime | yes | — |
| reset_password_token | string | yes | — |
| role | integer | no | `1` |
| subtitle | string | yes | — |
| username | string | no | — |
| created_at / updated_at | datetime | no | — |

Unique indexes: `email`, `employee_code`, `phone_number`, `reset_password_token`, `username`. Index on `active`, `deleted_at`, `fuel_pump_id`.

**Enum (INTEGER-backed, load-bearing):** `enum :role, { admin: 0, staff: 1 }, default: :staff, validate: true`. → `admin = 0`, `staff = 1`. DB default `1` (staff).

**Devise modules:** `:database_authenticatable, :recoverable, :rememberable, :validatable`. `attr_writer :login` (virtual login field).

**Associations:**
- `has_many :transactions, dependent: :restrict_with_exception`.
- `belongs_to :assigned_fuel_pump, class_name: "FuelPump", foreign_key: :fuel_pump_id, inverse_of: :assigned_users, optional: true`.
- `has_many :pump_nozzle_assignments, class_name: "UserPumpNozzleAssignment", dependent: :destroy, inverse_of: :user`.
- `has_many :assigned_fuel_pump_nozzles, through: :pump_nozzle_assignments, source: :fuel_pump_nozzle`.
- `has_many :shift_assignments, dependent: :restrict_with_exception`; `has_many :shift_templates, through: :shift_assignments`; `has_many :shift_cycles, through: :shift_assignments`.
- `has_many :recorded_attendance_runs` (`AttendanceRun`, fk `recorded_by_id`, `restrict_with_exception`).
- `has_many :scheduled_attendance_entries` / `:actual_attendance_entries` / `:replacement_attendance_entries` (`AttendanceEntry`, fks `scheduled_user_id` / `actual_user_id` / `replacement_user_id`, `restrict_with_exception`).
- `has_many :attendance_entry_changes` (`AttendanceEntryChange`, fk `changed_by_id`, `restrict_with_exception`).
- `has_many :recorded_shift_swaps` / `:shift_swaps_from` / `:shift_swaps_to` (`ShiftSwap`, fks `recorded_by_id` / `from_user_id` / `to_user_id`, `restrict_with_exception`).

**Callbacks (in exact declaration order):**
1. `before_validation :normalize_name` → `self[:name] = name.to_s.squish.titleize.presence` (collapse whitespace, title-case; blank → nil).
2. `before_validation :normalize_username` → `self[:username] = username.to_s.strip.presence`.
3. `before_validation :normalize_email` → `self.email = email.to_s.strip.downcase.presence`.
4. `before_validation :normalize_phone_number, if: :phone_number_attribute_available?` → `self[:phone_number] = normalize_phone_number(stored_phone_number)` (strips all non-digits via `gsub(/\D/, "")`).
5. `before_validation :sync_internal_email_from_phone_number, if: :phone_number_attribute_available?` → if phone present AND (email blank OR email is internal-format), set `self.email = "user-#{digits}@users.fuel-loyalty.local"`.
6. `before_validation :clear_assigned_nozzles_without_pump, on: :pump_assignment` → if `fuel_pump_id.blank?` set `self.assigned_fuel_pump_nozzle_ids = []`.
7. `after_validation :suppress_internal_email_uniqueness_error` → if email present AND internal-format AND `errors[:email]` includes `"has already been taken"`, delete `:email` errors.

**Validations:**
- `validates :name, presence: true` → `"can't be blank"`.
- `validates :username, presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A\S+\z/ }` → presence/uniqueness/`"is invalid"`.
- `validates :role, presence: true` (+ enum `validate: true` → adds `"is not included in the list"` for bad values).
- `validates :employee_code, uniqueness: { case_sensitive: false }, allow_blank: true, if: -> { has_attribute?(:employee_code) }`.
- `validates :subtitle, length: { maximum: 120 }, allow_blank: true, if: -> { has_attribute?(:subtitle) }` → `"is too long (maximum is 120 characters)"`.
- `validates :phone_number, uniqueness: true, allow_blank: true, if: :phone_number_attribute_available?` → `"has already been taken"`.
- `validates :phone_number, format: { with: /\A\d{10}\z/, message: "must be a 10 digit mobile number" }, allow_blank: true, if: :phone_number_attribute_available?`.
- `validate :phone_number_required, if: :phone_number_required?` → adds `:phone_number` `"can't be blank"` when `stored_phone_number.blank?`.
- `validate :must_keep_at_least_one_admin, if: :demoting_last_admin?` → if no other admin exists, error `:role` = `"must leave at least one admin user"`.
- `validate :assigned_fuel_pump_must_be_active, on: :pump_assignment` → if `fuel_pump_id` present and pump not active, error `:fuel_pump_id` = `"must be active"`.
- `validate :assigned_fuel_pump_nozzles_required_when_pump_selected, on: :pump_assignment` → if pump present and no nozzles assigned, error `:assigned_fuel_pump_nozzle_ids` = `"must include at least one nozzle"`.
- `validate :assigned_fuel_pump_nozzles_must_belong_to_selected_pump, on: :pump_assignment` → if any assigned nozzle's `fuel_pump_id != fuel_pump_id`, error `:assigned_fuel_pump_nozzle_ids` = `"must belong to the selected pump"`.
- `validate :assigned_fuel_pump_nozzles_must_be_active, on: :pump_assignment` → if any assigned nozzle not active, error `:assigned_fuel_pump_nozzle_ids` = `"must all be active"`.

> **`:pump_assignment` is a custom validation context** — callbacks/validations tagged `on: :pump_assignment` fire ONLY when saved in that context (e.g. `save(context: :pump_assignment)`) or when replicated manually (see `save_pump_assignment`). They do NOT run on ordinary create/update.

**Conditional-attribute guards:**
- `phone_number_attribute_available?` (instance, private) → `self.class.phone_number_attribute_available? && has_attribute?(:phone_number)`.
- `self.phone_number_attribute_available?` → `attribute_names.include?("phone_number")`.
- `demoting_last_admin?` → `persisted? && will_save_change_to_role? && role_change_to_be_saved&.first == "admin" && role != "admin"`.
- `phone_number_required?` → `phone_number_attribute_available? && (new_record? || will_save_change_to_phone_number? || stored_phone_number.present?)`.

**Scopes:** `kept` → `where(deleted_at: nil)`; `soft_deleted` → `where.not(deleted_at: nil)`.

**Public instance methods (API-returnable):**
- `login` → `@login || username || stored_phone_number || email`.
- `display_name` → `name.presence || username.presence || display_phone_number || "User"`.
- `display_contact` → `display_phone_number || explicit_email || username.presence`.
- `display_phone_number` → `nil` if `stored_phone_number` blank; else `"+91 #{stored_phone_number}"`.
- `explicit_email` → `nil` if email blank or internal-format; else `email`.
- `avatar_initial` → `display_name.to_s.first.to_s.upcase.presence || "U"` (first letter, upper).
- `email_required?` → always `false` (Devise override).
- `active_for_authentication?` → `super && active? && !soft_deleted?`.
- `inactive_message` → `:inactive` unless (`active?` and not soft-deleted); else `super`.
- `soft_deleted?` → `deleted_at.present?`.
- `soft_delete!(at: Time.current)` → if `admin?`: add `:base` = `"Only staff accounts can be soft deleted"`, raise `ActiveRecord::RecordInvalid`. If `active?`: add `:base` = `"User is in active state. Deactivate before soft deleting"`, raise `ActiveRecord::RecordInvalid`. Else `update!(active: false, deleted_at: at)`.
- `current_shift_assignment(on: Time.current)` → `shift_assignments.active.effective_at(on).order(effective_from: :desc).first`.
- `current_shift_template(on: Time.current)` → `current_shift_assignment(on:)&.resolved_shift_template(at: on)`.
- `current_shift_cycle(on: Time.current)` → `assignment&.shift_cycle || assignment&.shift_template&.current_shift_cycle(at: on)`.
- `transaction_fuel_pump` → `assigned_fuel_pump` only if `pump&.active?`, else `nil`.
- `transaction_fuel_pump_nozzles` → `FuelPumpNozzle.none` if no active pump; else `FuelPumpNozzle.includes(:fuel_type_record).where(id: assigned_fuel_pump_nozzle_ids, fuel_pump_id: pump.id, active: true).ordered`.
- `transaction_pump_ready?` → `transaction_fuel_pump.present? && transaction_fuel_pump_nozzles.exists?`.
- `save_pump_assignment` → **manual pump-assignment save** (does NOT use `on: :pump_assignment` context): runs `clear_assigned_nozzles_without_pump`, then `errors.clear`, then runs the 4 pump validators (`assigned_fuel_pump_must_be_active`, `..._required_when_pump_selected`, `..._must_belong_to_selected_pump`, `..._must_be_active`); returns `false` if `errors.any?`, else `save(validate: false)`. Returns boolean.

**Public class methods (API-relevant):**
- `self.find_for_database_authentication(warden_conditions)` — Devise auth lookup. Dups conditions, extracts+strips `:login`. If login present: query `"LOWER(username) = :value OR LOWER(email) = :value"` with `value: login.downcase`; if phone attr available, appends `" OR phone_number = :phone"` with `phone: normalize_phone_number(login)`; runs `kept.where(conditions).find_by(query, bindings)`. Else `kept.find_by(conditions)`.
- `self.normalize_phone_number(value)` → `value.to_s.gsub(/\D/, "")`.
- `self.valid_phone_number?(value)` → `normalize_phone_number(value).match?(/\A\d{10}\z/)`.
- `self.active` → `kept.where(active: true)` (note: overrides default; both `deleted_at IS NULL` and `active = true`).
- `self.internal_email_for(phone_number)` → `"user-#{digits}@users.fuel-loyalty.local"`.
- `self.internal_email?(value)` → `value.to_s.downcase.match?(/\Auser-\d+@users\.fuel-loyalty\.local\z/)`.

**Private helpers of note:** `stored_phone_number` → `self[:phone_number]` (nil if attr unavailable); `must_keep_at_least_one_admin` guards last-admin demotion; normalization writers as listed in callbacks.

---

### Cross-model rules relevant to `/api/v1`
- **Deletion protection:** `FuelPump` and `FuelPumpNozzle` both block destroy while `transactions.exists?` (`throw :abort`, error `:base` = `"cannot be removed while transactions still use it"`). `User#transactions` and most `User` associations use `dependent: :restrict_with_exception` (raises `ActiveRecord::DeleteRestrictionError` on destroy). Prefer soft-delete for staff (`soft_delete!`).
- **Pump assignment on User must use context `:pump_assignment`** (via `save(context: :pump_assignment)`) OR call `save_pump_assignment` which replays the four validators manually and saves with `validate: false`. Ordinary save skips all pump-related validations.
- **Internal email synthesis:** when `phone_number` present and email blank/internal, email is auto-set to `user-<digits>@users.fuel-loyalty.local`; `explicit_email` and `display_contact` hide internal emails; uniqueness error on internal emails is suppressed post-validation.
- **Nozzle sequence numbers are auto-assigned** by the parent pump's `before_validation` when blank; unique per pump (`[fuel_pump_id, sequence_number]`). Pump `sequence_number` is globally unique, auto-assigned on create.
- **No enum on `active` fields** — plain booleans, DB default `true`.

Files: `/Users/achalindiresh/workspace/fuel-loyalty/app/models/fuel_pump.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/models/fuel_pump_nozzle.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/models/user_pump_nozzle_assignment.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/models/user.rb`; schema `/Users/achalindiresh/workspace/fuel-loyalty/db/schema.rb`.