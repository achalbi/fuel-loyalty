## Subsystem: auth:app-controller+policies

Replication spec for the authentication/authorization layer: Devise (session auth via Warden), Pundit (policy authorization), `ApplicationController` base behavior, the `User` model's auth surface, and every Pundit policy. All controllers inherit from `ApplicationController`; all authorization goes through Pundit policies with the convention `<PolicyClass>#<action>?` returning boolean. `Pundit::NotAuthorizedError` → redirect to `/` with alert.

---

### DEVISE CONFIG (`config/initializers/devise.rb`) — load-bearing for API auth

- `config.authentication_keys = [:login]` — **login is by a single virtual `:login` key**, NOT email. (User model resolves `login` against username OR email OR phone_number.)
- `config.case_insensitive_keys = [:email, :username]` — downcased on save & lookup.
- `config.strip_whitespace_keys = [:email, :username, :login]`.
- `config.skip_session_storage = [:http_auth]`.
- `config.stretches = Rails.env.test? ? 1 : 12` (bcrypt cost).
- `config.password_length = 6..128`.
- `config.email_regexp = /\A[^@\s]+@[^@\s]+\z/`.
- `config.reset_password_within = 6.hours`.
- `config.reconfirmable = true` (no confirmable module active though — see below).
- `config.expire_all_remember_me_on_sign_out = true`.
- `config.sign_out_via = :delete` — sign-out is `DELETE /users/sign_out`.
- `config.responder.error_status = :unprocessable_content` (422), `config.responder.redirect_status = :see_other` (303) — Turbo-style. **API layer should mirror these codes for Devise flows.**
- `config.mailer_sender = ENV.fetch("MAILER_FROM", "no-reply@fly.thoughtbasics.com")`.
- No OmniAuth, no `http_authenticatable` (commented → default false), no timeoutable/lockable/confirmable configured.

---

### MODEL: `User` (`app/models/user.rb`) — auth-relevant surface

**Devise modules:** `devise :database_authenticatable, :recoverable, :rememberable, :validatable`. (No `registerable`, `confirmable`, `trackable`, `lockable`, `timeoutable`.)

**Constants:** `PHONE_NUMBER_LENGTH = 10`; `PHONE_NUMBER_FORMAT = /\A\d{10}\z/`; `PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit mobile number"`; `USERNAME_FORMAT = /\A\S+\z/` (no whitespace); `INTERNAL_EMAIL_DOMAIN = "users.fuel-loyalty.local"`. `attr_writer :login`.

**Table `users` columns (type, default, null):**
| column | type | default | null |
|---|---|---|---|
| active | boolean | `true` | NOT NULL |
| created_at | datetime | — | NOT NULL |
| deleted_at | datetime | — | NULL (soft-delete marker) |
| email | string | `""` | NOT NULL |
| employee_code | string | — | NULL |
| encrypted_password | string | `""` | NOT NULL |
| fuel_pump_id | bigint | — | NULL |
| name | string | — | NOT NULL |
| phone_number | string | — | NULL |
| remember_created_at | datetime | — | NULL |
| reset_password_sent_at | datetime | — | NULL |
| reset_password_token | string | — | NULL |
| role | integer | `1` | NOT NULL |
| subtitle | string | — | NULL |
| updated_at | datetime | — | NOT NULL |
| username | string | — | NOT NULL |

Unique indexes: email, employee_code, phone_number, reset_password_token, username. Non-unique: active, deleted_at, fuel_pump_id.

**ENUM (INTEGER-backed, load-bearing):** `enum :role, { admin: 0, staff: 1 }, default: :staff, validate: true`. **admin=0, staff=1.** `validate: true` → invalid role value fails validation. Predicates `admin?`/`staff?` drive every policy.

**Validations (with exact messages):**
- `name`: presence (default msg "can't be blank").
- `username`: presence; uniqueness `case_sensitive: false`; format `USERNAME_FORMAT` (default "is invalid" if whitespace present).
- `role`: presence.
- `employee_code`: uniqueness `case_sensitive: false`, `allow_blank: true`, only `if has_attribute?(:employee_code)`.
- `subtitle`: length max 120, `allow_blank: true`, only `if has_attribute?(:subtitle)`.
- `phone_number`: uniqueness `allow_blank: true` (if attr available); format `PHONE_NUMBER_FORMAT` with message **"must be a 10 digit mobile number"**, `allow_blank: true`.
- Custom `phone_number_required` (if `phone_number_required?`): adds error `phone_number` → **"can't be blank"** when stored phone blank. Trigger: attr available AND (new_record OR phone changing OR phone present).
- Custom `must_keep_at_least_one_admin` (if `demoting_last_admin?`): adds `role` → **"must leave at least one admin user"**. Fires when persisted + role changing FROM admin + no other admin exists.
- On `:pump_assignment` context only: `assigned_fuel_pump_must_be_active` → `fuel_pump_id` **"must be active"**; `assigned_fuel_pump_nozzles_required_when_pump_selected` → `assigned_fuel_pump_nozzle_ids` **"must include at least one nozzle"**; `assigned_fuel_pump_nozzles_must_belong_to_selected_pump` → **"must belong to the selected pump"**; `assigned_fuel_pump_nozzles_must_be_active` → **"must all be active"**.
- Devise `:validatable` adds: email presence+format (`email_regexp`) UNLESS `email_required?` overridden to `false` (it is → email not required); password presence/length 6..128/confirmation.

**Callbacks — order matters:**
1. `before_validation :normalize_name` → `self[:name] = name.to_s.squish.titleize.presence` (collapse whitespace, Title Case, nil if empty).
2. `before_validation :normalize_username` → `self[:username] = username.to_s.strip.presence`.
3. `before_validation :normalize_email` → `self.email = email.to_s.strip.downcase.presence`.
4. `before_validation :normalize_phone_number` (if phone attr available) → `self[:phone_number] = normalize_phone_number(phone)` = strip all non-digits (`gsub(/\D/, "")`).
5. `before_validation :sync_internal_email_from_phone_number` (if phone attr available) → if phone present AND (email blank OR email is internal), set `email = "user-<digits>@users.fuel-loyalty.local"`.
6. `before_validation :clear_assigned_nozzles_without_pump, on: :pump_assignment` → clears `assigned_fuel_pump_nozzle_ids = []` if `fuel_pump_id` blank.
7. `after_validation :suppress_internal_email_uniqueness_error` → deletes `email` "has already been taken" error when email is an internal-domain email.

**Associations + dependent:**
- `has_many :transactions, dependent: :restrict_with_exception`.
- `belongs_to :assigned_fuel_pump, class_name: "FuelPump", foreign_key: :fuel_pump_id, inverse_of: :assigned_users, optional: true`.
- `has_many :pump_nozzle_assignments (UserPumpNozzleAssignment), dependent: :destroy`; `has_many :assigned_fuel_pump_nozzles, through:`.
- `has_many :shift_assignments, dependent: :restrict_with_exception`; through → `:shift_templates`, `:shift_cycles`.
- `has_many :recorded_attendance_runs` (AttendanceRun, recorded_by_id), `:scheduled_attendance_entries`/`:actual_attendance_entries`/`:replacement_attendance_entries` (AttendanceEntry via respective FKs), `:attendance_entry_changes` (changed_by_id), `:recorded_shift_swaps`/`:shift_swaps_from`/`:shift_swaps_to` (ShiftSwap) — **all `dependent: :restrict_with_exception`**.

**Scopes:** `kept -> { where(deleted_at: nil) }`; `soft_deleted -> { where.not(deleted_at: nil) }`.

**Class methods:**
- `self.find_for_database_authentication(warden_conditions)` — **auth entry point.** Strips `:login`; if present: lowercases, queries `LOWER(username)=:value OR LOWER(email)=:value` (+ `OR phone_number=:phone` where phone = normalized digits, if attr available), scoped to `kept` (deleted_at IS NULL). Else `kept.find_by(conditions)`.
- `self.phone_number_attribute_available?` → `attribute_names.include?("phone_number")`.
- `self.normalize_phone_number(value)` → `value.to_s.gsub(/\D/, "")`.
- `self.valid_phone_number?(value)` → normalized matches 10-digit format.
- `self.active` → `kept.where(active: true)`.
- `self.internal_email_for(phone)` → `"user-<digits>@users.fuel-loyalty.local"`.
- `self.internal_email?(value)` → matches `/\Auser-\d+@users\.fuel-loyalty\.local\z/i`.

**Public instance methods (API-returnable computed values):**
- `login` → `@login || username || stored_phone_number || email` (virtual auth id).
- `display_name` → `name.presence || username.presence || display_phone_number || "User"`.
- `display_contact` → `display_phone_number || explicit_email || username.presence`.
- `display_phone_number` → nil if phone blank else `"+91 <phone>"`.
- `explicit_email` → nil if email blank or internal; else email.
- `avatar_initial` → first char of display_name upcased, else `"U"`.
- `email_required?` → `false` (overrides Devise).
- `active_for_authentication?` → `super && active? && !soft_deleted?` — **inactive or soft-deleted users cannot authenticate.**
- `inactive_message` → `:inactive` when inactive/soft-deleted, else super.
- `soft_deleted?` → `deleted_at.present?`.
- `soft_delete!(at: Time.current)` — raises `ActiveRecord::RecordInvalid` with base error **"Only staff accounts can be soft deleted"** if admin; **"User is in active state. Deactivate before soft deleting"** if still active; else `update!(active: false, deleted_at: at)`.
- `current_shift_assignment(on:)`, `current_shift_template(on:)`, `current_shift_cycle(on:)` — shift resolution.
- `transaction_fuel_pump` → assigned pump if active, else nil.
- `transaction_fuel_pump_nozzles` → `FuelPumpNozzle.none` if no active pump; else active nozzles for that pump among assigned ids, `.ordered`.
- `transaction_pump_ready?` → pump present AND has ≥1 nozzle.
- `save_pump_assignment` → clears nozzles-without-pump, clears errors, runs the 4 pump-assignment validators manually; returns false if errors; else `save(validate: false)`.

---

### CONTROLLER: `ApplicationController` (`app/controllers/application_controller.rb`)

`ActionController::Base` (cookie/session, CSRF protection ON by default — no `protect_from_forgery` exemption present; **API layer must supply its own token auth / CSRF exemption**). `include Pundit::Authorization`.

**helper_methods exposed:** `pwa_cache_buster`, `customer_points_ledger_path_for`, `customer_transaction_history_path_for`, `firebase_browser_sdk_enabled?`, `firebase_web_push_enabled?`, `firebase_web_push_settings`.

**Constants:** `SUPPORTED_BROWSER_VERSIONS = { safari: 16.4, chrome: 120, firefox: 121, opera: 106, ie: false }`; `SUPPORTED_SAMSUNG_INTERNET_VERSION = 24.0`.

**before_action filters (global, run in order):**
1. `stale_when_importmap_changes` — only if `config/importmap.rb` exists.
2. `set_private_cache_headers` → sets `Cache-Control: private, no-store` on every response.
3. `block_unsupported_browser` → if `unsupported_browser?`, instruments `browser_block.action_controller` and renders `public/406-unsupported-browser.html`, `layout: false`, **status `:not_acceptable` (406)**. IE always blocked; safari/firefox/opera/chrome checked against min versions; Samsung Internet (UA contains `SamsungBrowser/`) checked against 24.0; bots and blank-version UAs pass.

**rescue_from:** `Pundit::NotAuthorizedError → user_not_authorized` → `redirect_to root_path, alert: "You are not authorized to perform that action."` (HTML redirect to `/`). **This is the single authorization-failure response for the whole app.** No auth on ApplicationController itself declares `authenticate_user!` — individual controllers handle it; but note Devise's default behavior redirects unauthenticated HTML to sign-in (`/users/sign_in`), and per Devise config returns 401 for non-navigational formats.

**Other private helpers:** cache-header setter `set_public_cache_headers(max_age:, s_maxage:, stale_while_revalidate:, stale_if_error:, immutable:)`; `pwa_cache_buster` (ENV RELEASE_SHA → dev mtime hash → assets.version); `customer_points_ledger_path_for` / `customer_transaction_history_path_for` (switch admin vs non-admin route by `controller_path.start_with?("admin/")`); `firebase_web_push_settings` returns `{ firebaseConfig:, vapidKey:, subscriptionEndpoint: push_subscriptions_path, defaultLink: }` or `{}`.

No strong-params, no actions of its own (base class).

---

### ROUTES (`config/routes.rb`) — auth + policy-guarded surface

- `devise_for :users` → generates `GET/POST /users/sign_in`, `DELETE /users/sign_out`, password-reset routes (`:recoverable`), remember (`:rememberable`). No registration route usable (no `:registerable` module). **The `:login` field is the credential param under `user[login]` + `user[password]`.**
- `resource :password, only: %i[edit update]` — app's own password change (`PasswordsController`, distinct from Devise recoverable), `GET /password/edit`, `PATCH/PUT /password`.
- `resource :my_pump → my_pumps#show/update` (`GET/PATCH /my_pump`) — self pump-assignment (guarded by `UserPolicy#manage_pump?`).
- `root "dashboard#show"` → `/` (also the `user_not_authorized` redirect target).
- Public loyalty flow: `GET /loyalty`, `POST /loyalty`, `GET /loyalty/result`.
- `namespace :staff` (staff+admin policies): customers (index/new/create + collection `lookup`, member `activate`/`deactivate`/`pause_rewards`/`resume_rewards`), redemptions, transactions (+ collection `lookup`/`recognize_plate`/`register_customer`), notifications.
- `namespace :admin` (admin-only policies): dashboard(+`data`), notifications(+`notifications/send`), staff_members (index/update/destroy, nested shift_assignments create), shift_templates, shift_cycles(+activate/deactivate), attendance_runs(+invalidate/mark_valid), users (index/new/create/show/edit/update — **no destroy route**), fuel_types, fuel_pumps(+collection `feature_settings`), vehicle_types, fuel_reward_rates (show/update), theme_settings (show/update), schedules(+send_now, `schedules/run`), customers (full CRUD + member points_ledger/transaction_history), transactions (index), points_adjustments (new/create).
- Top-level (any signed-in): `resources :customers, only: %i[show edit update]` (+ member points_ledger/transaction_history, nested vehicles create/edit/update/destroy).

---

### POLICIES (`app/policies/`)

**Base `ApplicationPolicy`** — `initialize(user, record)` → `@user`, `@record`. Defaults ALL DENY: `index? show? create? update? destroy? = false`; `new? => create?`; `edit? => update?`. Nested `Scope(user, scope)` with `#resolve` that raises `NoMethodError "You must define #resolve in <class>"` (no policy below overrides Scope).

Convention across policies: `staff_access?` (private) = `user&.admin? || user&.staff?`. Note `user&.` — nil user (unauthenticated) always denied.

| Policy | Method | Rule (who is allowed) |
|---|---|---|
| **CustomerPolicy** | `index?` | admin only |
| | `show?` | any authenticated user (`user.present?`) |
| | `points_ledger?` / `transaction_history?` | = `show?` → any authenticated user |
| | `new?` / `create?` / `update?` | staff OR admin |
| | `destroy?` | admin only |
| | `lookup?` / `activate?` / `deactivate?` / `pause_rewards?` / `resume_rewards?` | staff OR admin |
| **TransactionPolicy** | `index?` | admin only |
| | `new?` / `create?` | staff OR admin |
| **UserPolicy** | `index?` / `show?` / `create?` / `update?` | admin only |
| | `destroy?` | admin AND `record.is_a?(User)` AND `record.staff?` (admins can only delete staff users) |
| | `manage_pump?` | user present AND `record == user` (self) AND (admin OR staff) — self-service pump assignment |
| **DashboardPolicy** | `show?` | admin only |
| **AttendanceRunPolicy** | `index?` `new?` `create?` `show?` `invalidate?` `mark_valid?` `destroy?` | admin only (every action) |
| **FuelPumpPolicy** | `index?` `create?` `show?` `edit?` `update?` `destroy?` | admin only |
| **FuelRewardRatePolicy** | `show?` / `update?` | admin only |
| **FuelTypePolicy** | `index?` `create?` `show?` `edit?` `update?` `destroy?` | admin only |
| **PointsLedgerPolicy** | `new?` / `create?` | admin only |
| | `redeem?` | admin OR staff |
| **RewardSettingPolicy** | `show?` / `update?` | admin only |
| **ShiftAssignmentPolicy** | `create?` | admin only |
| **ShiftCyclePolicy** | `index?` `create?` `update?` `destroy?` | admin only |
| **ShiftTemplatePolicy** | `index?` `create?` `update?` | admin only |
| **ThemeSettingPolicy** | `show?` / `update?` | admin only |
| **VehicleTypePolicy** | `index?` `create?` `show?` `edit?` `update?` `destroy?` | admin only |

**Notes for API layer:**
- Any policy method not explicitly overridden inherits the DENY-by-default from `ApplicationPolicy` (e.g. `CustomerPolicy` has no `edit?` override → falls back to `update?`=staff/admin via `edit? => update?`; but `DashboardPolicy` defines only `show?`, all others deny).
- No policy defines a working `Scope#resolve` — Pundit `policy_scope` would raise. API must not rely on scoping.
- Authorization failure everywhere surfaces as `Pundit::NotAuthorizedError` → the single HTML redirect+alert in `ApplicationController`. A JSON `/api/v1` layer must add its own `rescue_from Pundit::NotAuthorizedError` returning JSON (e.g. 403) rather than the root redirect, and must add authentication (Devise session redirects to `/users/sign_in` for HTML; for JSON formats returns 401 per navigational-formats default).

**Files (absolute):** `/Users/achalindiresh/workspace/fuel-loyalty/app/controllers/application_controller.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/config/routes.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/config/initializers/devise.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/models/user.rb`, and all 17 policies under `/Users/achalindiresh/workspace/fuel-loyalty/app/policies/`.