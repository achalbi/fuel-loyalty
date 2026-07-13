## controllers:public-shared

Reference for the public/shared web controllers backing the loyalty PWA and authenticated staff/admin chrome. All are `ActionController::Base` subclasses via `ApplicationController` (HTML-first, Devise auth, Pundit authorization). External deps referenced but defined elsewhere: `ApplicationController#set_public_cache_headers`, Devise (`authenticate_user!`, `current_user`, `user_signed_in?`, `bypass_sign_in`), Pundit (`authorize`, `Pundit::NotAuthorizedError`). User-facing strings that use `t("...")` / `I18n.t(...)` are **i18n keys** (resolved at runtime, not literals) — flagged as such; hardcoded strings are quoted verbatim.

---

### LoyaltyController `app/controllers/loyalty_controller.rb`

Public, anonymous-facing. Phone lookup → signed token → read-only points page. Multi-locale.

**Constants**
- `PUBLIC_CACHE_FALLBACK_TIME = Time.utc(2024, 1, 1)` (frozen) — Last-Modified fallback.
- `LOYALTY_LANGUAGE_COOKIE = :loyalty_language`.
- `SUPPORTED_LOYALTY_LOCALES` (frozen, ordered hash, code→native label): `"en"=>"English"`, `"kn"=>"ಕನ್ನಡ"`, `"hi"=>"हिन्दी"`, `"ta"=>"தமிழ்"`, `"te"=>"తెలుగు"`, `"ml"=>"മലയാളം"`, `"or"=>"ଓଡ଼ିଆ"`, `"bn"=>"বাংলা"`, `"mr"=>"मराठी"`, `"gu"=>"ગુજરાતી"`, `"pa"=>"ਪੰਜਾਬੀ"`.

**CSRF**: `skip_forgery_protection only: :create` (POST /loyalty accepts no CSRF token — legacy cached shells).

**Filters (order)**:
1. `before_action :discard_devise_sign_out_notice` (all) — deletes `flash[:notice]` if it equals `I18n.t("devise.sessions.signed_out")` or `I18n.t("devise.sessions.already_signed_out")`.
2. `before_action :persist_selected_loyalty_language` (all) — see cookie logic below.
3. `before_action :redirect_to_remembered_loyalty_language, only: :new`.
4. `around_action :switch_loyalty_locale` (all) — wraps action in `I18n.with_locale(selected_loyalty_locale)`.

`helper_method :loyalty_language_options, :loyalty_language_param, :loyalty_language_params`.

**Locale resolution**
- `selected_loyalty_locale` = `normalized_loyalty_locale(params[:lang])` || `remembered_loyalty_locale` (cookie) || `I18n.default_locale.to_s`.
- `normalized_loyalty_locale(value)`: `value.to_s.tr("-","_")`; blank→nil; returns locale only if key present in `SUPPORTED_LOYALTY_LOCALES`, else nil.
- `persist_selected_loyalty_language`: computes `@updating_loyalty_language_cookie = selected_locale.present? && selected_locale != remembered_loyalty_locale`. If true, sets `cookies.permanent[:loyalty_language] = { value: selected_locale, same_site: :lax }`.
- `redirect_to_remembered_loyalty_language`: no-op if `params[:lang]` present; else if remembered cookie locale present AND != default → `redirect_to new_loyalty_path(lang: remembered_locale)`.

**Actions**

`new` → **GET /loyalty/new** (`new_loyalty_path`). Renders anonymous shell.
- If `public_loyalty_shell_cacheable?` is false → returns early (renders normally, no cache headers). Cacheable = `!user_signed_in? && flash.empty? && !updating_loyalty_language_cookie?`.
- Else: loads `ThemeSetting.current`; `cache_version = ENV.fetch("RELEASE_SHA", Rails.application.config.assets.version)`.
- Sets public cache headers: `max_age: 0, s_maxage: 60, stale_while_revalidate: 30, stale_if_error: 86_400`.
- `stale?(etag: [cache_version, theme_setting.primary_color, I18n.locale], last_modified: theme_setting.updated_at&.utc || PUBLIC_CACHE_FALLBACK_TIME, public: true)` → may respond **304 Not Modified**; otherwise renders `new` (200).

`create` → **POST /loyalty** (`loyalty_path`, CSRF-exempt).
- `@phone_number = Customer.normalize_phone_number(loyalty_params[:phone_number])`.
- If `!Customer.valid_phone_number?(@phone_number)` → `render_invalid_phone_number`: `flash.now[:alert] = t("loyalty.alerts.invalid_phone")` (i18n key), `render :new, status: :unprocessable_entity` (**422**).
- Else → `redirect_to loyalty_result_path(loyalty_language_params(lookup_token: LoyaltyLookupToken.generate(@phone_number)))` (**302**). `loyalty_language_params` merges `lang:` only when current locale != default; input compacted via `compact_blank`.

`show` → **GET /loyalty/result** (`loyalty_result_path`, reads `params[:lookup_token]`).
- `@phone_number = LoyaltyLookupToken.verified_phone_number(params[:lookup_token])`.
- If blank → `redirect_to new_loyalty_path(loyalty_language_params), alert: lookup_token_alert` (**302**). `lookup_token_alert`: `t("loyalty.alerts.expired_link")` if `params[:lookup_token].present?`, else `t("loyalty.alerts.enter_phone")` (both i18n keys).
- Else if `!Customer.valid_phone_number?(@phone_number)` → `render_invalid_phone_number` (**422**, `t("loyalty.alerts.invalid_phone")`).
- Else `@customer = Customer.find_by(phone_number: @phone_number)`:
  - **Found** → assigns for view (these are the API payload fields):
    - `@lookup_token = LoyaltyLookupToken.generate(@phone_number)` (token rotated each render).
    - `@total_points = @customer.total_points`
    - `@rewards_paused = @customer.rewards_paused?`
    - `@minimum_redeemable_points = @customer.minimum_redeemable_points`
    - `@redeemable_points = @customer.max_redeemable_points`
    - `@points_until_redeemable = @customer.points_until_redeemable`
    - `@full_history = (params[:full_history] == "1")`
    - `@activities = @customer.loyalty_activities(limit: @full_history ? nil : 5)`
    - `@show_full_history_button = !@full_history && @customer.loyalty_activities_count > 5`
    - Renders `show` (200).
  - **Not found** → `flash.now[:alert] = t("loyalty.alerts.not_found")` (i18n key); `render :new, status: :unprocessable_entity` (**422**).

**Strong params**: `loyalty_params = params.require(:loyalty).permit(:phone_number)`.

**Helper outputs (for API/locale UI)**:
- `loyalty_language_options` → array of `[label, code]` pairs from `SUPPORTED_LOYALTY_LOCALES`.
- `loyalty_language_param` → `I18n.locale.to_s`.
- `loyalty_language_params(extra={})` → `extra.compact_blank`, plus `lang: <locale>` unless current locale == default.

---

### CustomersController `app/controllers/customers_controller.rb`

Authenticated. Includes `CustomerPointsLedgerRendering`, `CustomerTransactionHistoryRendering` (concerns — provide `render_points_ledger_for`, `render_transaction_history_for`; not in scope files).

**Filters**: `before_action :authenticate_user!`; `before_action :set_customer, only: %i[show edit update points_ledger transaction_history]`.
- `set_customer`: `Customer.includes(:vehicles, transactions: %i[user vehicle]).find(params[:id])` (raises `RecordNotFound`→404 if missing).

**Authorization**: every action calls `authorize @customer` (Pundit `CustomerPolicy`; `update` uses default `update?`, `show`/`edit`→`show?`/`edit?`, ledger/history→same-named policy methods).

**Actions**

`show` → **GET /customers/:id**. `authorize @customer`; `prepare_show_state`; renders `show` (200).

`points_ledger` → **GET /customers/:id/points_ledger**. `authorize @customer`; delegates to `render_points_ledger_for(@customer)` (concern-defined response).

`transaction_history` → **GET /customers/:id/transaction_history**. `authorize @customer`; delegates to `render_transaction_history_for(@customer)` (concern-defined response).

`edit` → **GET /customers/:id/edit**. `authorize @customer`; renders `edit` (200).

`update` → **PATCH/PUT /customers/:id**.
- `authorize @customer`.
- `@customer.assign_attributes(customer_params)`; then overwrites `@customer.phone_number = Customer.normalize_phone_number(customer_params[:phone_number])`.
- If `@customer.save` → `redirect_to customer_path(@customer), notice: "Customer updated successfully."` (**302**).
- Else → `prepare_show_state(open_edit_modal: true)`; `render :show, status: :unprocessable_entity` (**422**).

**Strong params**: `customer_params = params.require(:customer).permit(:name, :phone_number)`.

**View-state helper** `prepare_show_state(open_edit_modal: false)`: sets `@vehicle = Vehicle.new`, `@customer_update_path = customer_path(@customer)`, `@customer_edit_modal_open = open_edit_modal`.

---

### VehiclesController `app/controllers/vehicles_controller.rb`

Authenticated. Nested under customer. All write actions authorize against the **customer** (`:update?`), not the vehicle.

**Filters**: `before_action :authenticate_user!`; `before_action :set_customer`; `before_action :set_vehicle, only: %i[edit update destroy]`.
- `set_customer`: `Customer.includes(:vehicles, transactions: %i[user vehicle]).find(params[:customer_id])`.
- `set_vehicle`: `@customer.vehicles.find(params[:id])`.

**Authorization**: every action `authorize @customer, :update?` (Pundit `CustomerPolicy#update?`).

**Actions**

`create` → **POST /customers/:customer_id/vehicles**.
- `authorize @customer, :update?`; `@vehicle = @customer.vehicles.new(vehicle_params)`.
- If `@vehicle.save` → `redirect_to customer_path(@customer), notice: "Vehicle added successfully."` (**302**).
- Else → `@vehicle_modal_mode = :create`; `render "customers/show", status: :unprocessable_entity` (**422**).

`edit` → **GET /customers/:customer_id/vehicles/:id/edit**. `authorize @customer, :update?`; renders `edit` (200).

`update` → **PATCH/PUT /customers/:customer_id/vehicles/:id**.
- `authorize @customer, :update?`.
- If `@vehicle.update(vehicle_params)` → `redirect_to customer_path(@customer), notice: "Vehicle updated successfully."` (**302**).
- Elsif `params[:vehicle_form_context] == "modal"` → `@vehicle_modal_mode = :edit`; `render "customers/show", status: :unprocessable_entity` (**422**).
- Else → `render :edit, status: :unprocessable_entity` (**422**).

`destroy` → **DELETE /customers/:customer_id/vehicles/:id**.
- `authorize @customer, :update?`; `@vehicle.destroy!`.
- Success → `redirect_to customer_path(@customer), notice: "Vehicle removed successfully."` (**302**).
- `rescue ActiveRecord::DeleteRestrictionError` → `redirect_to customer_path(@customer), alert: "Vehicle cannot be removed because transaction history exists."` (**302**).

**Strong params**: `vehicle_params = params.require(:vehicle).permit(:vehicle_number, :fuel_type, :vehicle_kind, :commercial_company_name, :commercial_contact_name, :commercial_contact_phone_number, :commercial_address, :commercial_notes).to_h.merge(vehicle_number: Vehicle.normalize_vehicle_number(params.dig(:vehicle, :vehicle_number)))` — `vehicle_number` is always overwritten with the normalized value (commercial_* fields are the conditional-commercial vehicle attributes).

---

### MyPumpsController `app/controllers/my_pumps_controller.rb`

Authenticated staff/admin. Singular resource (no `:id`); operates on `current_user`'s pump/nozzle assignment.

**Filters**: `before_action :authenticate_user!`; `before_action :ensure_staff_or_admin!`.
- `ensure_staff_or_admin!`: returns if `current_user&.admin? || current_user&.staff?`; else `raise Pundit::NotAuthorizedError, "not allowed"`.

**Authorization**: both actions `authorize current_user, :manage_pump?` (Pundit `UserPolicy#manage_pump?`).

**Actions**

`show` → **GET /my_pump** (`my_pump_path`). `authorize current_user, :manage_pump?`; `load_form_state`; renders `show` (200).

`update` → **PATCH/PUT /my_pump**.
- `authorize current_user, :manage_pump?`.
- `current_user.assign_attributes(my_pump_params)`.
- If `current_user.save_pump_assignment` (custom model method) → `redirect_to my_pump_path, notice: "My pump updated successfully."` (**302**).
- Else → `load_form_state`; `render :show, status: :unprocessable_entity` (**422**).

**Strong params**: `my_pump_params = params.require(:user).permit(:fuel_pump_id, assigned_fuel_pump_nozzle_ids: [])` (nozzle ids as array).

**View-state helper** `load_form_state`:
- `@assignable_fuel_pumps = FuelPump.includes(nozzles: :fuel_type_record).ordered.to_a`.
- `@assignable_fuel_pump_nozzles = @assignable_fuel_pumps.index_with { |fp| fp.nozzles.active.ordered.to_a }`.

---

### PasswordsController `app/controllers/passwords_controller.rb`

Authenticated. Self-service password change (Devise `update_with_password`).

**Filters**: `before_action :authenticate_user!`. No Pundit (operates on `current_user`).

**Actions**

`edit` → **GET /password/edit** (or configured path). `@user = current_user`; renders `edit` (200).

`update` → **PATCH/PUT /password**.
- `@user = current_user`.
- If `@user.update_with_password(password_params)` → `bypass_sign_in(@user)` (keeps session valid after password change); `redirect_to after_password_update_path, notice: "Password updated successfully."` (**302**).
- Else → `render :edit, status: :unprocessable_entity` (**422**).
- `after_password_update_path`: `current_user.admin? ? admin_dashboard_path : new_staff_transaction_path`.

**Strong params**: `password_params = params.require(:user).permit(:current_password, :password, :password_confirmation)`.

---

### PwaController `app/controllers/pwa_controller.rb`

Public. Serves PWA manifest and service worker. `layout false` (no app layout).

**CSRF**: `skip_forgery_protection only: :service_worker`.

**Actions**

`manifest` → **GET** (PWA manifest route).
- `@theme_setting = ThemeSetting.current`.
- `set_public_cache_headers(max_age: 300, s_maxage: 300, stale_while_revalidate: 30)`.
- `response.set_header("Content-Type", "application/manifest+json")`.
- Renders manifest view (200).

`service_worker` → **GET** (service worker route, CSRF-exempt).
- `@cache_version = pwa_cache_buster` (helper defined elsewhere, likely `ApplicationController`).
- `response.set_header("Cache-Control", "no-cache")`.
- `response.set_header("Service-Worker-Allowed", "/")`.
- Renders SW view (200).

---

### PushSubscriptionsController `app/controllers/push_subscriptions_controller.rb`

**JSON API** (no HTML). No auth filters, no Pundit — public endpoint. Web-push subscription registry.

**Actions**

`create` → **POST** (push subscriptions route). Returns JSON.
- `token = PushSubscription.normalize_token(subscription_params.fetch(:token))`.
- `existing = PushSubscription.exists?(token: token)`.
- `subscription = PushSubscription.register!(token: token, platform: subscription_params.fetch(:platform), last_used_at: Time.current)`.
- Success JSON body: `{ id: subscription.id, active: subscription.active, platform: subscription.platform }`. Status: **200 OK** if `existing`, else **201 Created**.
- `rescue ActionController::ParameterMissing => error` → `render json: { error: error.message }, status: :unprocessable_entity` (**422**). (`.fetch(:token)`/`.fetch(:platform)` raise `KeyError`, not `ParameterMissing` — note: a missing key here would raise `KeyError` and NOT be caught, yielding 500; only genuinely missing `params` structures raise `ParameterMissing`.)
- `rescue ActiveRecord::RecordInvalid => error` → `render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity` (**422**).

`destroy` → **DELETE** (push subscription route).
- `subscription = PushSubscription.find_by(token: PushSubscription.normalize_token(params.require(:token)))`.
- `subscription&.deactivate!` (no-op if not found).
- Success → `head :no_content` (**204**, no body).
- `rescue ActionController::ParameterMissing => error` → `render json: { error: error.message }, status: :unprocessable_entity` (**422**).

**Strong params**: `subscription_params = params.permit(:token, :platform)`. `destroy` reads `params.require(:token)` directly.

---

### Analytics::EventsController `app/controllers/analytics/events_controller.rb`

**JSON API**, namespaced `Analytics`. No auth filter (records `current_user` if present, else nil — anonymous allowed). Fire-and-forget analytics ingestion.

**CSRF**: `skip_forgery_protection only: :create`.

**Actions**

`create` → **POST /analytics/events** (namespaced). Returns JSON/head.
- Builds `AnalyticsEvent.new(name: analytics_event_params[:name], page_path: analytics_event_params[:page_path], properties: analytics_event_properties, user_agent: request.user_agent, user: current_user)`.
- If `save` → `head :accepted` (**202**, no body).
- Else → `render json: { errors: analytics_event.errors.full_messages }, status: :unprocessable_entity` (**422**).

**Strong params**: `analytics_event_params = params.permit(:name, :page_path)`.
- `analytics_event_properties`: reads `params[:properties]`; blank → `{}`; else `raw.to_unsafe_h` (if responds) else `raw.to_h` (permits arbitrary nested properties hash).

---

### DashboardController `app/controllers/dashboard_controller.rb`

Public entry/router. No filters.

**Actions**

`show` → **GET /** (root dashboard). Redirect-only (**302**), never renders:
- If `user_signed_in?` → `redirect_to(current_user.admin? ? admin_dashboard_path : new_staff_transaction_path)`.
- Else → `redirect_to new_loyalty_path`.

---

### Cross-cutting notes for the /api/v1 layer

- **Auth model**: `authenticate_user!` (Devise session/cookie) gates Customers, Vehicles, MyPumps, Passwords. Loyalty, Pwa, PushSubscriptions, Analytics::Events, Dashboard are **unauthenticated**. An API layer replacing session auth must substitute token auth on the gated controllers.
- **Authorization**: Pundit `authorize` on Customers (`@customer`), Vehicles (`@customer, :update?`), MyPumps (`current_user, :manage_pump?`). MyPumps additionally hard-gates on `admin?||staff?` before Pundit (raises `Pundit::NotAuthorizedError, "not allowed"`). Unauthorized → Pundit rescue (typically 403/redirect, handled in `ApplicationController`).
- **CSRF exemptions**: `LoyaltyController#create`, `PwaController#service_worker`, `Analytics::EventsController#create`. PushSubscriptions is JSON but not explicitly exempt (relies on JSON request handling / no token-verification failure for API format).
- **Normalization applied in controllers** (must replicate exactly): `Customer.normalize_phone_number` (Loyalty create, Customers update), `Vehicle.normalize_vehicle_number` (Vehicles create/update, always overwrites permitted value), `PushSubscription.normalize_token` (PushSubscriptions create/destroy).
- **Hardcoded flash strings (verbatim)**: `"Customer updated successfully."`, `"Vehicle added successfully."`, `"Vehicle updated successfully."`, `"Vehicle removed successfully."`, `"Vehicle cannot be removed because transaction history exists."`, `"My pump updated successfully."`, `"Password updated successfully."`, and the auth-guard exception message `"not allowed"`.
- **i18n keys (resolve for API error payloads)**: `loyalty.alerts.invalid_phone`, `loyalty.alerts.expired_link`, `loyalty.alerts.enter_phone`, `loyalty.alerts.not_found`; plus `devise.sessions.signed_out`, `devise.sessions.already_signed_out` (matched-and-discarded, not surfaced).
- **Standard status codes**: success writes → 302 (HTML) or 202/204/201/200 (JSON); validation failure → 422; caching → 304 (Loyalty#new).

Files (absolute): `/Users/achalindiresh/workspace/fuel-loyalty/app/controllers/{loyalty,customers,vehicles,my_pumps,passwords,pwa,push_subscriptions,dashboard}_controller.rb` and `/Users/achalindiresh/workspace/fuel-loyalty/app/controllers/analytics/events_controller.rb`.