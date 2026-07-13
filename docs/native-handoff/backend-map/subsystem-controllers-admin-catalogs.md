## Subsystem: `controllers:admin-catalogs`

Five Pundit-authorized admin controllers under `module Admin`, all inheriting `Admin::BaseController` (auth/layout/CSRF defined there — NOT in these files; assume standard Rails session auth + CSRF protection, no `skip_forgery_protection` or token auth present here). All use Pundit `authorize`. All responses are HTML redirects/renders (NO JSON anywhere). Flash strings quoted verbatim. Routes below are the Rails RESTful conventions matching the `redirect_to` path helpers used.

---

### `Admin::FuelTypesController` (`app/controllers/admin/fuel_types_controller.rb`)

`before_action :set_fuel_type, only: %i[edit update destroy]` → `@fuel_type = FuelType.find(params[:id])` (raises `RecordNotFound` if missing).

| Action | HTTP + Path | authorize | Outcome → response |
|---|---|---|---|
| `index` | GET `/admin/fuel_types` | `authorize FuelType` | Renders index. Loads state (below). |
| `create` | POST `/admin/fuel_types` | `authorize FuelType` | Success: `redirect_to admin_fuel_types_path, notice: "Fuel type added successfully."`. Failure: `load_index_state(new_fuel_type: @fuel_type)`, `flash.now[:alert] = @fuel_type.errors.full_messages.to_sentence`, `render :index, status: :unprocessable_entity` (422). |
| `edit` | GET `/admin/fuel_types/:id/edit` | `authorize @fuel_type` | Renders edit. |
| `update` | PATCH/PUT `/admin/fuel_types/:id` | `authorize @fuel_type` | Success: `redirect_to admin_fuel_types_path, notice: "Fuel type updated successfully."`. Failure: `flash.now[:alert] = @fuel_type.errors.full_messages.to_sentence`, `render :edit, status: :unprocessable_entity` (422). |
| `destroy` | DELETE `/admin/fuel_types/:id` | `authorize @fuel_type` | Success: `redirect_to admin_fuel_types_path, notice: "Fuel type removed successfully."`. Failure: `redirect_to admin_fuel_types_path, alert: @fuel_type.errors.full_messages.to_sentence`. |

- **Strong params** `fuel_type_params`: `params.require(:fuel_type).permit(:name, :active)`.
- **`load_index_state(new_fuel_type: FuelType.new(active: true))`**: sets `@fuel_type = new_fuel_type`; `@fuel_types = FuelType.for_settings`. Default new record has `active: true`.

---

### `Admin::FuelPumpsController` (`app/controllers/admin/fuel_pumps_controller.rb`)

`before_action :set_fuel_pump, only: %i[edit update destroy]` → `@fuel_pump = FuelPump.includes(nozzles: :fuel_type_record).find(params[:id])` (eager-loads nozzles + their fuel type).

| Action | HTTP + Path | authorize | Outcome → response |
|---|---|---|---|
| `index` | GET `/admin/fuel_pumps` | `authorize FuelPump`; then `@reward_setting = RewardSetting.current`; `authorize @reward_setting, :show?` | Renders index; `load_index_state`. |
| `feature_settings` | non-REST member/collection route → `redirect_to admin_fuel_pumps_path` (helper `feature_settings...`). | `@reward_setting = RewardSetting.current`; `authorize @reward_setting, :update?` (NO `authorize FuelPump` here) | Calls `@reward_setting.update!(feature_setting_params)`. Success: `redirect_to admin_fuel_pumps_path, notice: "Pump transaction settings updated successfully."`. Rescue `ActiveRecord::RecordInvalid => e`: `@reward_setting = e.record`, `load_index_state`, `flash.now[:alert] = e.record.errors.full_messages.to_sentence`, `render :index, status: :unprocessable_entity` (422). |
| `create` | POST `/admin/fuel_pumps` | `authorize FuelPump` | Success: `redirect_to admin_fuel_pumps_path, notice: "#{@fuel_pump.display_name} added successfully."` (interpolates `display_name`). Failure: `load_index_state(new_fuel_pump: @fuel_pump)`, `flash.now[:alert] = ...to_sentence`, `render :index, status: :unprocessable_entity` (422). |
| `edit` | GET `/admin/fuel_pumps/:id/edit` | `authorize @fuel_pump` | `prepare_fuel_pump_form(@fuel_pump)`; renders edit. |
| `update` | PATCH/PUT `/admin/fuel_pumps/:id` | `authorize @fuel_pump` | Success: `redirect_to admin_fuel_pumps_path, notice: "#{@fuel_pump.display_name} updated successfully."`. Failure: `prepare_fuel_pump_form(@fuel_pump)`, `flash.now[:alert] = ...to_sentence`, `render :edit, status: :unprocessable_entity` (422). |
| `destroy` | DELETE `/admin/fuel_pumps/:id` | `authorize @fuel_pump` | Captures `pump_name = @fuel_pump.display_name` BEFORE destroy. Success: `redirect_to admin_fuel_pumps_path, notice: "#{pump_name} removed successfully."`. Failure: `redirect_to admin_fuel_pumps_path, alert: @fuel_pump.errors.full_messages.to_sentence`. |

- **Strong params `fuel_pump_params`**: `params.require(:fuel_pump).permit(:active, nozzles_attributes: [:id, :fuel_type_code, :active, :_destroy])`. Nested `accepts_nested_attributes_for :nozzles` implied. Nozzle attrs permitted: `id`, `fuel_type_code` (business key, not FK id), `active`, `_destroy`.
- **Strong params `feature_setting_params`**: `params.require(:reward_setting).permit(:nozzle_feature_enabled)` (single boolean-ish flag on RewardSetting).
- **`load_index_state(new_fuel_pump: build_new_fuel_pump)`**: `@reward_setting ||= RewardSetting.current`; `@fuel_pump = prepare_fuel_pump_form(new_fuel_pump)`; `@fuel_pumps = FuelPump.for_settings`.
- **`build_new_fuel_pump`**: `FuelPump.new(active: true)` then builds one nozzle `nozzles.build(active: true)`.
- **`prepare_fuel_pump_form(fuel_pump)`**: returns pump unchanged if it has any nozzle not marked for destruction (`nozzles.reject(&:marked_for_destruction?).any?`); otherwise builds one blank `nozzles.build(active: true)` and returns pump. (Ensures the form always shows ≥1 nozzle row.)

**API note:** `feature_settings` and `index` authorize the `RewardSetting` policy with explicit `:show?`/`:update?`; `RewardSetting.current` is a singleton-style fetch. `create/edit/update/destroy` do NOT touch `RewardSetting`.

---

### `Admin::VehicleTypesController` (`app/controllers/admin/vehicle_types_controller.rb`)

`before_action :set_vehicle_type, only: %i[edit update destroy]` → `@vehicle_type = VehicleType.find(params[:id])`.

| Action | HTTP + Path | authorize | Outcome → response |
|---|---|---|---|
| `index` | GET `/admin/vehicle_types` | `authorize VehicleType` | Renders index; `load_index_state`. |
| `create` | POST `/admin/vehicle_types` | `authorize VehicleType` | Success: `redirect_to admin_vehicle_types_path, notice: "Vehicle type added successfully."`. Failure: `load_index_state(new_vehicle_type: @vehicle_type)`, `flash.now[:alert] = ...to_sentence`, `render :index, status: :unprocessable_entity` (422). |
| `edit` | GET `/admin/vehicle_types/:id/edit` | `authorize @vehicle_type` | Renders edit. |
| `update` | PATCH/PUT `/admin/vehicle_types/:id` | `authorize @vehicle_type` | Success: `redirect_to admin_vehicle_types_path, notice: "Vehicle type updated successfully."`. Failure: `flash.now[:alert] = ...to_sentence`, `render :edit, status: :unprocessable_entity` (422). |
| `destroy` | DELETE `/admin/vehicle_types/:id` | `authorize @vehicle_type` | Success: `redirect_to admin_vehicle_types_path, notice: "Vehicle type removed successfully."`. Failure: `redirect_to admin_vehicle_types_path, alert: @vehicle_type.errors.full_messages.to_sentence`. |

- **`vehicle_type_create_params`** (create only): `params.require(:vehicle_type).permit(:name, :short_name, :app_label_source, :code, :icon_name, :minimum_redeemable_points, :active)`. **Includes `:code`.**
- **`vehicle_type_update_params`** (update only): `params.require(:vehicle_type).permit(:name, :short_name, :app_label_source, :icon_name, :minimum_redeemable_points, :active)`. **Excludes `:code`** — `code` is immutable after creation. (Note: `reward_points_per_100` is NOT permitted here; it is updated only via `FuelRewardRatesController`.)
- **`load_index_state(new_vehicle_type: VehicleType.new(active: true))`**: `@vehicle_type = new_vehicle_type`; `@vehicle_types = VehicleType.for_settings`.

---

### `Admin::FuelRewardRatesController` (`app/controllers/admin/fuel_reward_rates_controller.rb`)

Singular-resource style (`show`/`update`). No `before_action`. This is a MULTI-FORM update endpoint dispatching on which param group is present.

| Action | HTTP + Path | authorize (in order) |
|---|---|---|
| `show` | GET `/admin/fuel_reward_rates` | `authorize FuelRewardRate`; `authorize VehicleType, :index?`; `@reward_setting = RewardSetting.current`; `authorize @reward_setting` (default `show?`) → `load_settings`; renders show. |
| `update` | PATCH/PUT `/admin/fuel_reward_rates` | `authorize FuelRewardRate`; `authorize VehicleType, :update?`; `@reward_setting = RewardSetting.current`; `authorize @reward_setting` (default `update?`). |

**`update` dispatch algorithm (order matters — first non-blank param group wins):**
1. If `reward_setting_params.present?` → `@reward_setting.update!(reward_setting_params)` → `redirect_to admin_fuel_reward_rates_path, notice: "Reward settings updated successfully."` and `return`.
2. Else if `permitted_vehicle_type_rate_params.present?` → `update_vehicle_type_reward_rates!` → `redirect_to admin_fuel_reward_rates_path, notice: "Vehicle-type reward rates updated successfully."` and `return`.
3. Else (fallthrough) → `update_fuel_reward_rates!` → `redirect_to admin_fuel_reward_rates_path, notice: "Fuel reward rates updated successfully."`.
- **Rescue `ActiveRecord::RecordInvalid => e`** (any branch): `load_settings`, `attach_record_errors(e.record)`, `flash.now[:alert] = e.record.errors.full_messages.to_sentence`, `render :show, status: :unprocessable_entity` (422).

**Private helpers:**
- **`load_settings`**: `@reward_setting ||= RewardSetting.current`; `@vehicle_types = VehicleType.for_settings`; `@fuel_reward_rates = FuelRewardRate.for_settings`.
- **`update_vehicle_type_reward_rates!`**: wrapped in `ActiveRecord::Base.transaction`. For each `vehicle_type_code, attributes` in `permitted_vehicle_type_rate_params`: `vehicle_type = VehicleType.find_by!(code: vehicle_type_code)` (raises `RecordNotFound` if code invalid — NOT rescued, would 404/500), then `vehicle_type.update!(reward_points_per_100: attributes[:reward_points_per_100])`. Any invalid record rolls back the whole transaction.
- **`update_fuel_reward_rates!`**: wrapped in `ActiveRecord::Base.transaction`. For each `fuel_type, attributes` in `permitted_rate_params`: `rate = FuelRewardRate.find_or_initialize_by(fuel_type: fuel_type)` (upsert), `rate.points_per_100 = attributes[:points_per_100]`, `rate.save!`.
- **`attach_record_errors(record)`**: on failure, re-maps the failed record's errors onto the matching in-memory collection object so the form re-renders errors inline. If `record.is_a?(VehicleType)` → find `@vehicle_types` element with matching `.code`; else → find `@fuel_reward_rates` element with matching `.fuel_type`. If no match (`target.blank?`) returns without doing anything. Otherwise copies each `record.errors` entry via `target.errors.add(error.attribute, error.message)`.

**Strong params (all use `params.fetch(key, ActionController::Parameters.new)` — safe when absent):**
- **`permitted_vehicle_type_rate_params`**: dynamically permits keys = each `VehicleType.for_settings.map(&:code)`, each mapping to `[:reward_points_per_100]`. Fetched from `params[:vehicle_type_reward_rates]`, `.permit(...).to_h.deep_symbolize_keys`. Shape: `{ <code> => { reward_points_per_100: value }, ... }`.
- **`permitted_rate_params`**: dynamically permits keys = `FuelRewardRate.setting_fuel_type_values`, each mapping to `[:points_per_100]`. Fetched from `params[:fuel_reward_rates]`. Shape: `{ <fuel_type> => { points_per_100: value }, ... }`.
- **`reward_setting_params`**: from `params[:reward_setting]`, `.permit(:rupees_per_reward_unit, :cash_value_per_point, :minimum_redeemable_points)`.

**API note:** three distinct payload shapes hit the SAME PATCH endpoint. A JSON layer must either split these into separate endpoints or replicate the exact precedence (reward_setting > vehicle_type_reward_rates > fuel_reward_rates). Top-level param keys are `reward_setting`, `vehicle_type_reward_rates`, `fuel_reward_rates` (NOT `require`d — all optional).

---

### `Admin::ThemeSettingsController` (`app/controllers/admin/theme_settings_controller.rb`)

Singular-resource style. No `before_action`. Operates on `ThemeSetting.current` (singleton).

| Action | HTTP + Path | authorize | Outcome → response |
|---|---|---|---|
| `show` | GET `/admin/theme_settings` | `@theme_setting = ThemeSetting.current`; `authorize @theme_setting` (`show?`) | Renders show. |
| `update` | PATCH/PUT `/admin/theme_settings` | `@theme_setting = ThemeSetting.current`; `authorize @theme_setting` (`update?`) | Success: `@theme_setting.update(theme_setting_params)` true → **side effect:** `Cdn::Purger.call if @theme_setting.saved_change_to_primary_color?` (only purges CDN when `primary_color` actually changed), then `redirect_to admin_theme_settings_path, notice: "Theme color updated successfully."`. Failure: `flash.now[:alert] = @theme_setting.errors.full_messages.to_sentence`, `render :show, status: :unprocessable_entity` (422). |

- **Strong params `theme_setting_params`**: `params.require(:theme_setting).permit(:primary_color)`.
- **External side effect:** `Cdn::Purger.call` (service, arg-less) invoked post-save iff `saved_change_to_primary_color?` — a JSON layer must replicate this conditional purge.

---

### Cross-cutting notes for the API layer
- **No JSON responses exist** — every action redirects (303/302 on success) or `render ... status: :unprocessable_entity` (422) with HTML. The API must synthesize JSON equivalents; the load-bearing artifacts to reuse are the exact **notice/alert strings**, the **status codes** (422 on validation failure), and the **`authorize` calls** (Pundit).
- **Error message source:** all failure alerts are `record.errors.full_messages.to_sentence` — the API should surface `errors.full_messages` (or per-attribute `errors`) instead.
- **Pundit policy methods referenced** (rules defined in policy classes NOT in these files — must be read separately for the "who is allowed" spec): `FuelTypePolicy` (default index/create/edit/update/destroy via `authorize FuelType`/instance); `FuelPumpPolicy`; `VehicleTypePolicy` (incl. explicit `:index?`, `:update?`); `FuelRewardRatePolicy`; `RewardSettingPolicy` (explicit `:show?`, `:update?`, default `show?`/`update?`); `ThemeSettingPolicy` (`show?`, `update?`).
- **Singleton fetches:** `RewardSetting.current`, `ThemeSetting.current` — API must resolve the same current record.
- **`.for_settings`** scope is used on `FuelType`, `FuelPump`, `VehicleType`, `FuelRewardRate` for list rendering; **`FuelRewardRate.setting_fuel_type_values`** and **`VehicleType.for_settings.map(&:code)`** drive dynamic param whitelists — these model methods are load-bearing and must be read from the models to replicate exact permitted keys.
- **Immutability:** `VehicleType#code` permitted on create only, never on update. Nozzle `fuel_type_code` (business key) is the nested-attribute key, not the FK id.

_(Files read in full: only the five controllers above. Models, policies, `Cdn::Purger`, and `Admin::BaseController` are referenced but out of scope — read them for the model/policy/service specs.)_