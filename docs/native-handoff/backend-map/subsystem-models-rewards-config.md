## Subsystem: `models:rewards-config`

Five ActiveRecord models backing reward/vehicle/fuel/theme configuration. All use integer PK `id`. No STI. `active`/`nozzle_feature_enabled` etc. are Rails booleans (SQLite-backed). Enum note: none of these models use Rails `enum` — "codes" are plain STRING columns constrained by format regex + inclusion in curated constant lists (load-bearing string values below).

---

### MODEL: `VehicleType` (`vehicle_types`)

**Columns / types / DB defaults**

| Column | Type | Null | DB Default |
|---|---|---|---|
| id | integer (PK) | no | — |
| active | boolean | no | `true` |
| app_label_source | string | no | `"short_name"` |
| code | string | no | — (unique index) |
| icon_name | string | no | — |
| minimum_redeemable_points | integer | no | `100` |
| name | string | no | — |
| reward_points_per_100 | integer | yes | — (nil) |
| reward_points_per_rupee | decimal(8,2) | yes | — (nil; NOT referenced anywhere in model) |
| short_name | string | no | — |
| created_at / updated_at | datetime | no | — |

Indexes: `code` unique, `active`.

**Constants (load-bearing)**
- `DEFAULT_OPTIONS` = `[["Two-Wheeler","two_wheeler"],["Three-Wheeler","three_wheeler"],["LMV","lmv"],["LCV","lcv"],["MCV","mcv"],["HCV","hcv"]]`
- `DEFAULT_CODES` = `["two_wheeler","three_wheeler","lmv","lcv","mcv","hcv"]` (also the sort order)
- `APP_LABEL_SOURCES` = `["name","short_name"]`; `DEFAULT_APP_LABEL_SOURCE` = `"short_name"`
- `DEFAULT_ICON_NAME` = `"ti-car"`
- `DEFAULT_MINIMUM_REDEEMABLE_POINTS` = `100`; `MINIMUM_REDEEMABLE_POINTS_STEP` = `100`
- `CODE_FORMAT` = `/\A[a-z]+(?:_[a-z]+)*\z/` (lowercase letters + underscores; **no digits**)
- Icon constants: `AUTO_RICKSHAW_ICON_NAME="custom-tuk-tuk"`, `PICKUP_TRUCK_ICON_NAME="custom-pickup-truck"`, `BIG_TRUCK_ICON_NAME="custom-big-truck"`
- `ICON_NAMES` (valid `icon_name` set) = `["ti-bike","custom-tuk-tuk","ti-car","custom-pickup-truck","ti-truck","custom-big-truck","ti-bus","ti-tractor"]`
- `ICON_OPTIONS` (value→label): `ti-bike`→"Bike", `custom-tuk-tuk`→"Auto Rickshaw / 3 Wheeler", `ti-car`→"Car", `custom-pickup-truck`→"Pickup Truck", `ti-truck`→"Truck", `custom-big-truck`→"Big Truck", `ti-bus`→"Bus", `ti-tractor`→"Tractor"
- `REMOVED_ICON_REPLACEMENTS` = `{"ti-car-suv"=>"ti-car","ti-car-4wd"=>"ti-car","ti-truck-delivery"=>"custom-pickup-truck","ti-truck-loading"=>"custom-big-truck","ti-rv-truck"=>"ti-truck","ti-ambulance"=>"ti-truck","ti-firetruck"=>"ti-truck","ti-forklift"=>"ti-truck","ti-caravan"=>"ti-bus"}`
- `REMOVED_TWO_WHEELER_ICON_NAMES` = `["ti-motorbike","ti-scooter","ti-scooter-electric","ti-moped"]`

**Associations**
- `has_many :vehicles, foreign_key: :vehicle_kind, primary_key: :code, inverse_of: false` (no `dependent:`; guarded by `before_destroy`)

**Scopes**
- `active` → `where(active: true)`

**before_validation callbacks (EXACT ORDER)**
1. `assign_default_app_label_source` — `app_label_source = "short_name"` if blank
2. `normalize_name` — `name = name.to_s.squish.presence` (nil if blank)
3. `normalize_short_name` — `short_name = short_name.to_s.squish.presence`
4. `normalize_app_label_source` — `app_label_source = app_label_source.to_s.presence`
5. `assign_short_name_from_name` — `short_name = name` if short_name blank & name present
6. `assign_code_from_name` — `code = name` if code blank & name present
7. `normalize_code` — `code = normalize_code(code)` = `value.to_s.tr("-","_").parameterize(separator:"_").tr("-","_").presence`
8. `normalize_icon_name` — `icon_name = supported_icon_name_for(icon_name, code:, name:)` (see method; maps removed icons, may return nil if input blank)
9. `assign_icon_name` — `icon_name = suggested_icon_name_for(code:, name:)` if icon_name blank
10. `normalize_minimum_redeemable_points` — strip commas+squish → `.to_i` (nil if blank)
11. `normalize_reward_points_per_100` — strip commas+squish; blank→nil; else `Integer(v,10)`; on `ArgumentError` assign the raw string (forces numericality failure)
12. `assign_default_minimum_redeemable_points` — `= 100` if blank

**before_destroy**
- `ensure_not_used_by_vehicles` — if `vehicles.exists?` → `errors.add(:base, "cannot be removed while vehicles still use it")` + `throw :abort`

**Validations (exact messages)**
- `code`: presence; uniqueness case_insensitive; format `CODE_FORMAT` msg `"only allows lowercase letters and underscores"`
- `name`: presence; uniqueness case_insensitive
- `short_name`: presence
- `app_label_source`: inclusion in `["name","short_name"]`
- `icon_name`: presence + inclusion in `ICON_NAMES`
- `minimum_redeemable_points`: numericality only_integer, `>= 100`
- `reward_points_per_100`: numericality only_integer, `>= 0`, allow_nil
- `active`: inclusion in `[true,false]`
- custom `minimum_redeemable_points_must_match_redemption_step`: skip if blank; if `value % 100 != 0` → `errors.add(:minimum_redeemable_points, "must be in multiples of 100")`

**PUBLIC methods returning API values**

*Instance:*
- `app_label` → `preferred_app_label.presence || name`. `preferred_app_label` = `short_name` if `app_label_source == "short_name"` else `name`.
- `app_label_source_name?` → `app_label_source == "name"`
- `app_label_source_short_name?` → `app_label_source == "short_name"`
- `removable?` → `!vehicles.exists?`
- `remove_error_message` → `"cannot be removed while vehicles still use it"`

*Class:*
- `supported_codes` → `DEFAULT_CODES`
- `default_label_for(code)` → default label for `normalize_code(code)` (e.g. `"lmv"`→"LMV"), else nil
- `for_settings` → all records sorted by `[sort_index(code), name.downcase, code]`; on DB error → 6 in-memory unsaved `new(...)` from DEFAULT_OPTIONS with suggested icon, min points 100, active true
- `active_codes` → active records ordered `created_at,id`, pluck `code` as strings; DB error → `supported_codes`
- `active_options` → `options_for(active_codes)`
- `available_options(selected: nil)` → active codes + normalized `selected` (if present), deduped → `options_for`
- `active_code?(code)` → `active_codes.include?(normalize_code(code))`
- `icon_options` → `ICON_OPTIONS`
- `supported_icon_name_for(icon_name, code:, name:)` → squish/presence; nil if blank; if in `REMOVED_TWO_WHEELER_ICON_NAMES` → `suggested_icon_name_for`; else `REMOVED_ICON_REPLACEMENTS.fetch(name, name)`
- `icon_label_for(icon_name, code:, name:)` → label from ICON_OPTIONS for supported icon, else the supported icon string
- `icon_name_for(code)` → normalize; blank→`"ti-car"`; lookup record, `supported_icon_name_for(...).presence || suggested_icon_name_for(...)`; DB error → suggested
- `icon_map_for(codes)` → `{code => icon_name}` hash for each normalized code; DB error → suggested per code
- `label_for(code)` → `record.app_label.presence || record.name.presence || default_label_for || code.humanize`; DB error → default_label/humanize
- `minimum_redeemable_points_for_codes(codes)` → `MIN(minimum_redeemable_points)` over matching codes as int; empty/nil/DB-error → `100`
- `reward_points_per_100_for(code)` → `pick(:reward_points_per_100)` for code (integer or nil); blank code/DB error → nil
- `suggested_icon_name_for(code:, name:)` → regex classifier on `"#{code}_#{name}"` (normalized). Order: ambulance|firetruck|fire_truck|fire_engine|forklift→`ti-truck`; tractor→`ti-tractor`; bus|coach|caravan|camper|motorhome|rv→`ti-bus`; three_wheeler|three_wheel|rickshaw|auto|trike→`custom-tuk-tuk`; pickup→`custom-pickup-truck`; big_truck|big_trucks|heavy_truck|heavy_trucks|delivery|cargo|goods|lorry|hcv|mcv|lcv→`custom-big-truck`; truck→`ti-truck`; suv|jeep|4wd|four_wheel_drive→`ti-car`; motorbike|motor_cycle|motorcycle|moped|scooter|electric|ev|bike|bicycle|cycle|two_wheeler|two_wheel→`ti-bike`; else `ti-car`. Blank→`ti-car`.
- `normalize_code(value)` (public) → `value.to_s.tr("-","_").parameterize(separator:"_").tr("-","_").presence`

Private class methods: `options_for(codes)` (builds `[label, code]` pairs sorted by sort_index/name/code); `sort_index(code)` = index in DEFAULT_CODES else `6`.

---

### MODEL: `RewardSetting` (`reward_settings`) — singleton config row

**Columns**

| Column | Type | Null | DB Default |
|---|---|---|---|
| id | integer PK | no | — |
| cash_value_per_point | decimal(10,2) | yes | — (nil) |
| minimum_redeemable_points | integer | yes | — (nil) |
| nozzle_feature_enabled | boolean | no | `true` |
| rupees_per_reward_unit | integer | no | `100` |
| created_at / updated_at | datetime | no | — |

**Constants:** `DEFAULT_MINIMUM_REDEEMABLE_POINTS=100`, `DEFAULT_RUPEES_PER_REWARD_UNIT=100`

**No associations, no scopes.**

**before_validation (ORDER)**
1. `normalize_cash_value_per_point` — nil→nil; strip commas+squish; blank→nil; else `BigDecimal(v)`; on `ArgumentError` keep raw value (fails numericality)
2. `normalize_minimum_redeemable_points` — strip commas+squish → `.to_i` (nil if blank)
3. `normalize_rupees_per_reward_unit` — strip commas+squish → `.to_i` (nil if blank)
4. `assign_default_cash_value_per_point` — `= nil` if blank
5. `assign_default_nozzle_feature_enabled` — `= true` if nil
6. `assign_default_rupees_per_reward_unit` — `||= 100`

**Validations (no custom messages — Rails defaults)**
- `nozzle_feature_enabled`: inclusion `[true,false]`
- `cash_value_per_point`: numericality `>= 0`, allow_nil
- `minimum_redeemable_points`: numericality only_integer, `> 0`, allow_nil
- `rupees_per_reward_unit`: numericality only_integer, `> 0` (required)

**PUBLIC methods**
- `self.current` → `first_or_initialize` then: `nozzle_feature_enabled=true` if nil; `cash_value_per_point=nil` if blank; `minimum_redeemable_points=nil` if blank; `rupees_per_reward_unit ||= 100`. DB error → in-memory `new(cash_value_per_point: nil, minimum_redeemable_points: nil, rupees_per_reward_unit: 100, nozzle_feature_enabled: true)`
- `cash_reward_configured?` → `cash_value_per_point.present? && .positive?`
- `nozzle_feature_enabled?` → `self[:nozzle_feature_enabled] != false` (nil counts as enabled)
- `minimum_redeemable_points_configured?` → `present? && positive?`
- `cash_value_for_points(points)` → nil unless `cash_reward_configured?`; else `BigDecimal(points) * BigDecimal(cash_value_per_point)` (BigDecimal)
- `effective_minimum_redeemable_points(fallback: 100)` → configured ? `minimum_redeemable_points.to_i` : `fallback.to_i`
- `redemption_increment` → `effective_minimum_redeemable_points`

---

### MODEL: `FuelType` (`fuel_types`)

**Columns**

| Column | Type | Null | DB Default |
|---|---|---|---|
| id | integer PK | no | — |
| active | boolean | no | `true` |
| code | string | no | — (unique index) |
| name | string | no | — |
| created_at / updated_at | datetime | no | — |

Indexes: `code` unique, `active`.

**Constants**
- `DEFAULT_OPTIONS` = `[["Petrol","petrol"],["Diesel","diesel"],["CNG / LPG","cng_lpg"]]`
- `DEFAULT_CODES` = `["petrol","diesel","cng_lpg"]` (sort order)
- `CODE_FORMAT` = `/\A[a-z0-9]+(?:_[a-z0-9]+)*\z/` (lowercase alnum + underscores; **digits allowed**, unlike VehicleType)

**Associations (all `inverse_of: false`, no `dependent:` — destroy guarded/cascaded by callbacks)**
- `has_many :vehicles, foreign_key: :fuel_type, primary_key: :code`
- `has_many :fuel_reward_rates, foreign_key: :fuel_type, primary_key: :code`
- `has_many :fuel_pump_nozzles, foreign_key: :fuel_type_code, primary_key: :code`

**Scopes:** `active` → `where(active: true)`

**before_validation (ORDER)**
1. `normalize_name` — `name = name.to_s.squish.presence`
2. `assign_code_from_name` — `code = name` if code blank & name present
3. `normalize_code` — `code = code.to_s.parameterize(separator:"_").presence`

**before_destroy (ORDER)**
1. `ensure_not_used_by_vehicles` — if `vehicles.exists?` → `errors.add(:base, "cannot be removed while vehicles still use it")` + `throw :abort`
2. `ensure_not_used_by_nozzles` — if `fuel_pump_nozzles.exists?` → `errors.add(:base, "cannot be removed while pump nozzles still use it")` + `throw :abort`
3. `destroy_reward_rates` — `FuelRewardRate.where(fuel_type: code).delete_all` (hard delete, no callbacks)

**Validations (Rails default messages)**
- `code`: presence; uniqueness case_insensitive; format `CODE_FORMAT` (no custom message)
- `name`: presence; uniqueness case_insensitive
- `active`: inclusion `[true,false]`

**PUBLIC methods**
- `self.supported_codes` → `DEFAULT_CODES`
- `self.default_label_for(code)` → label for `code.to_s` (e.g. `"cng_lpg"`→"CNG / LPG"), else nil
- `self.for_settings` → all sorted `[sort_index, name.downcase, code]`; DB error → 3 in-memory `new(code:, name:, active: true)`
- `self.active_codes` → active ordered `created_at,id` pluck code strings; DB error → supported_codes
- `self.active_options` → `options_for(active_codes)`
- `self.active_for_settings` → `for_settings.select(&:active?)`
- `self.available_options(selected: nil)` → active + normalized selected, deduped → options_for
- `self.active_code?(code)` → include? normalized
- `self.label_for(code)` → `record.name.presence || default_label_for || code.humanize`; DB error → default/humanize; blank→nil
- `removable?` → `!vehicles.exists?`
- `remove_error_message` → `"cannot be removed while vehicles still use it"`
- `nozzle_remove_error_message` → `"cannot be removed while pump nozzles still use it"`
- Private: `options_for` (→ `[label,code]` pairs), `sort_index` (index in DEFAULT_CODES else `3`), `normalize_code_value(value)` = `value.to_s.parameterize(separator:"_").presence`

---

### MODEL: `FuelRewardRate` (`fuel_reward_rates`)

**Columns**

| Column | Type | Null | DB Default |
|---|---|---|---|
| id | integer PK | no | — |
| fuel_type | string | no | — (unique index) |
| points_per_100 | integer | no | — |
| created_at / updated_at | datetime | no | — |

**Constants:** `DEFAULT_POINTS_PER_100` = `{"petrol"=>2, "diesel"=>1, "cng_lpg"=>1}`

**No AR associations declared** (linked to FuelType logically via `fuel_type` string). No scopes.

**before_validation:** `normalize_fuel_type` — `fuel_type = fuel_type.to_s.parameterize(separator:"_").presence`

**Validations**
- `fuel_type`: presence; uniqueness (default message)
- `points_per_100`: numericality only_integer, `>= 0`
- custom `fuel_type_must_exist`: skip if `fuel_type` blank; skip if `FuelType.exists?(code: fuel_type)`; else `errors.add(:fuel_type, "is not available")`

**PUBLIC methods**
- `self.points_per_100_for(fuel_type)` → normalize (parameterize); blank→`0`; `find_by(fuel_type:)&.points_per_100 || DEFAULT_POINTS_PER_100.fetch(code, 0)`; DB error → default fetch(code,0). Returns integer.
- `self.label_for(fuel_type)` → delegates to `FuelType.label_for`
- `self.for_settings` → for each `FuelType.active_for_settings`, `find_or_initialize_by(fuel_type: code)` with `points_per_100 ||= DEFAULT_POINTS_PER_100.fetch(code, 0)`
- `self.setting_fuel_type_values` → `FuelType.active_for_settings.map(&:code)`
- `display_name` (instance) → `label_for(fuel_type)`

---

### MODEL: `ThemeSetting` (`theme_settings`) — singleton config row

**Columns**

| Column | Type | Null | DB Default |
|---|---|---|---|
| id | integer PK | no | — |
| primary_color | string | no | `"#43B05C"` |
| created_at / updated_at | datetime | no | — |

**Constants:** `DEFAULT_PRIMARY_COLOR="#43B05C"`, `DARK_TEXT_COLOR="#081E0F"`, `LIGHT_TEXT_COLOR="#F7FFF8"`

**before_validation:** `normalize_primary_color` — strip `#`, upcase; if matches `/\A[0-9A-F]{6}\z/` → `"##{hex}"` else keep original (fails format validation).

**Validations**
- `primary_color`: presence; format `/\A#[0-9A-F]{6}\z/` msg `"must be a valid hex color"` (uppercase hex only, exactly 6 digits with leading `#`)

**PUBLIC methods (API-relevant)**
- `self.current` → `first_or_initialize`, set `primary_color = "#43B05C"` if blank; DB error → `new(primary_color: "#43B05C")`
- `light_css_variables` → hash keyed:
  - `--fl-primary` = color
  - `--fl-primary-strong` = `adjust_color(color, -0.14)`
  - `--fl-primary-accent` = `adjust_color(color, 0.18)`
  - `--fl-primary-soft` = `rgba_color(color, 0.14)`
  - `--fl-primary-contrast` = `contrast_color_for(color)`
  - `--fl-primary-contrast-rgb` = `rgb_string(contrast_color_for(color))`
  - `--bs-primary-rgb` = `rgb_string(color)`
  - (`color = primary_color.presence || "#43B05C"`)
- `dark_css_variables` → same keys, but base `color = adjust_color(primary_color||default, 0.16)`; `--fl-primary-strong` uses `+0.12`, `--fl-primary-accent` `+0.18`, `--fl-primary-soft` alpha `0.18`.

**Color math (private, exact formulas)**
- `rgb_components(hex)` → strip leading `#`, scan 2-char pairs, `to_i(16)` → `[r,g,b]`
- `adjust_color(hex, amount)` per component: if `amount > 0` → `c + (255-c)*amount` (lighten); else → `c * (1+amount)` (darken); then `.round.clamp(0,255)`; formatted `"#%02X%02X%02X"` (uppercase)
- `contrast_color_for(hex)` → brightness `= (r*299 + g*587 + b*114)/1000.0`; `>= 150` → `"#081E0F"` (dark text) else `"#F7FFF8"` (light text)
- `rgba_color(hex, alpha)` → `"rgba(r, g, b, alpha)"`
- `rgb_string(hex)` → `"r, g, b"` (comma-space joined)

---

### Cross-cutting notes for the API layer
- Config singletons (`RewardSetting`, `ThemeSetting`) are accessed via `.current` — always returns a usable (possibly unsaved) instance even with no DB row / DB error. API GET should use `.current`.
- `VehicleType`/`FuelType` "code" is the join key to `vehicles` etc. (not id). Codes are normalized via `parameterize` — API must expect/return normalized codes.
- Monetary/points computations use `BigDecimal` (`cash_value_for_points`) — serialize as string to preserve precision, not float.
- Destroy is guarded (`throw :abort` with `errors[:base]`) not `dependent:` — deletion via API must check `removable?`/rescue and surface base errors: `"cannot be removed while vehicles still use it"` / `"cannot be removed while pump nozzles still use it"`.
- `VehicleType#reward_points_per_rupee` (decimal 8,2) exists in DB but is unused by the model — treat as inert unless a controller touches it.

Files: `/Users/achalindiresh/workspace/fuel-loyalty/app/models/vehicle_type.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/models/reward_setting.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/models/fuel_type.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/models/fuel_reward_rate.rb`, `/Users/achalindiresh/workspace/fuel-loyalty/app/models/theme_setting.rb`; schema: `/Users/achalindiresh/workspace/fuel-loyalty/db/schema.rb`.