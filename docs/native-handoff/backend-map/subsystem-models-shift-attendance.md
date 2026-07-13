## Subsystem: models:shift-attendance

Rails models backing the shift/attendance domain. All string enums/messages quoted verbatim; integer enum values are load-bearing. DB defaults from `db/schema.rb`.

---

### ShiftTemplate (`shift_templates`)
A named shift with a start clock-time and a duration in minutes.

**Columns (DB)**
| column | type | null | default |
|---|---|---|---|
| id | bigint PK | no | |
| active | boolean | no | `true` |
| created_at | datetime | no | |
| duration_minutes | integer | no | |
| name | string | no | |
| start_time | string | no | |
| updated_at | datetime | no | |
Indexes: `active`; unique on `name`.

**Constant**: `START_TIME_FORMAT = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/` (HH:MM 24h).
**attr_writer**: `duration_hours` (virtual; not persisted — sets `duration_minutes`).

**Associations**
- `has_many :shift_assignments, dependent: :restrict_with_exception`
- `has_many :shift_cycle_steps, dependent: :restrict_with_exception`
- `has_many :shift_cycles, through: :shift_cycle_steps`
- `has_many :staff_members, through: :shift_assignments, source: :user`
- `has_many :attendance_runs, dependent: :restrict_with_exception`
- `has_many :shift_swaps_from, class_name: "ShiftSwap", foreign_key: :from_shift_template_id, dependent: :restrict_with_exception`
- `has_many :shift_swaps_to, class_name: "ShiftSwap", foreign_key: :to_shift_template_id, dependent: :restrict_with_exception`

**Scopes**: `active` → `where(active: true)`.

**Callbacks (order)**
1. `before_validation :normalize_start_time` — if `start_time` blank, no-op. Else parse `"2000-01-01 #{start_time}"` in Time.zone and set `start_time = parsed.strftime("%H:%M")`. On `ArgumentError`/`TypeError`: `start_time = start_time.to_s.strip`.
2. `before_validation :apply_duration_hours_input, if: :duration_hours_input_provided?` — runs only when `@duration_hours` was assigned. If `@duration_hours` blank → `duration_minutes = nil`. Else `duration_minutes = (BigDecimal(@duration_hours.to_s) * 60).round`; if result `<= 0` → `nil`. On `ArgumentError` → `nil`.

**Validations**
- `name`: presence; uniqueness `{ case_sensitive: false }`.
- `start_time`: presence; format `START_TIME_FORMAT`, message `"must use HH:MM"`.
- `duration_minutes`: presence; numericality `{ only_integer: true, greater_than: 0 }`.

**Public computed methods**
- `duration_hours` → returns `@duration_hours` if set; else `nil` if `duration_minutes` blank; else `format_duration_hours(duration_minutes / 60.0)`. Format: `"%.2f"` then strip trailing `.00` and trailing zero of one-decimal (e.g. `480→"8"`, `450→"7.5"`, `470→"7.83"`).
- `duration_label` → `divmod(60)`; parts: `"#{hours} hour#{'s' unless hours==1}"` if hours>0, `"#{minutes} min"` if minutes>0; joined by `" "`; blank → `"0 min"`. (e.g. `"8 hours"`, `"7 hours 30 min"`, `"45 min"`.)
- `start_time_input_value` → raw `start_time`.
- `start_time_label` → nil if blank; else `Time.zone.parse("2000-01-01 #{start_time}").strftime("%I:%M %p")` (e.g. `"09:00 AM"`); rescue → raw `start_time`.
- `schedule_label` → join by `" · "` of (`"Starts #{start_time_label}"` if start_time present) and `duration_label`.
- `current_shift_cycle(at: Time.current)` → active cycles ordered `(:starts_on, :name)`; nil if none; returns first cycle whose `shift_template_for(at) == self`, else first active cycle.
- `current_shift_cycle_label(at: Time.current)` → `current_shift_cycle(at:)&.name || "No linked cycle"`.

---

### ShiftCycle (`shift_cycles`)
An ordered rotation of shift templates that repeats from `starts_on`.

**Columns (DB)**
| column | type | null | default |
|---|---|---|---|
| id | bigint PK | no | |
| active | boolean | no | `true` |
| created_at | datetime | no | |
| name | string | no | |
| period_days | integer | no | `1` |
| starts_on | date | no | |
| updated_at | datetime | no | |
Indexes: `active`; unique on `name`. NOTE: `period_days` exists in DB but is **not referenced by model logic** (cycle length is computed from step durations, not this column).

**Associations**
- `has_many :shift_cycle_steps, -> { order(:position) }, dependent: :destroy, inverse_of: :shift_cycle`
- `has_many :shift_templates, through: :shift_cycle_steps`
- `has_many :shift_assignments, dependent: :restrict_with_exception`

**Scopes**: `active` → `where(active: true)`.

**Validations**
- `name`: presence; uniqueness `{ case_sensitive: false }`.
- `starts_on`: presence.
- `validate :must_have_shift_cycle_steps` → adds to `:base` `"Choose at least one shift in the cycle."` when `shift_cycle_steps.empty?`.

**Public computed methods**
- `first_shift_template` → `shift_cycle_steps.first&.shift_template`.
- `effective_starts_at` → nil if `starts_on` or `first_shift_template` blank; else `Time.zone.parse("#{starts_on} #{first_shift_template.start_time_input_value}")`; rescue → nil. (Cycle anchor = date + first template's start clock-time.)
- `shift_template_for(moment)` → `window_for(moment)&.fetch(:shift_template, nil) || first_shift_template`.
- `window_for(moment)` → the core rotation resolver. Returns `nil` if: no steps; `effective_starts_at` blank; normalized `moment` < `cycle_start_at`; `cycle_duration_minutes <= 0`. Algorithm:
  - `point_in_time = ShiftAssignment.normalize_effective_point(moment)`
  - `cycle_duration = cycle_duration_minutes` (sum of step template `duration_minutes`)
  - `elapsed_minutes = ((point_in_time - cycle_start_at)/60).floor`
  - `cycle_offset_minutes = elapsed_minutes - (elapsed_minutes % cycle_duration)` (start of current cycle iteration)
  - `position_in_cycle = elapsed_minutes % cycle_duration`
  - Iterate steps accumulating `step_offset_minutes`; first step where `position_in_cycle < step_offset+step_duration` returns hash:
    - `{ shift_template:, starts_at: cycle_start_at + (cycle_offset_minutes + step_offset_minutes).minutes, ends_at: starts_at + step_duration.minutes, position: step.position }`
- `valid_window_for?(shift_template:, starts_at:, ends_at:)` → false if `window_for(starts_at)` blank; else compares (sec zeroed) window `shift_template`, `starts_at`, `ends_at` against args normalized via `ShiftAssignment.normalize_effective_point(...).change(sec:0)`. All three must match.
- `sequence_label` → step template names joined `" -> "`.
- `schedule_label` → literal `"Each shift uses its saved duration"`.
- `cycle_duration_minutes` → `sum` of each step's `shift_template.duration_minutes.to_i`.
- `cycle_duration_label` → same divmod formatting as ShiftTemplate#duration_label; blank → `"0 min"`.
- `starts_at_label` → nil if `effective_starts_at` blank; else `I18n.l(effective_starts_at, format: "%d %b %Y %I:%M %p")`.
- `deletable?` → `shift_assignments.none?`.

---

### ShiftCycleStep (`shift_cycle_steps`)
Join/order row linking a cycle to a template at a position.

**Columns (DB)**
| column | type | null | default |
|---|---|---|---|
| id | bigint PK | no | |
| created_at | datetime | no | |
| position | integer | no | |
| shift_cycle_id | bigint FK | no | |
| shift_template_id | bigint FK | no | |
| updated_at | datetime | no | |
Indexes: unique `(shift_cycle_id, position)`; `(shift_cycle_id, shift_template_id)`.

**Associations**: `belongs_to :shift_cycle`; `belongs_to :shift_template` (both required by default).

**Validations**
- `position`: numericality `{ only_integer: true, greater_than: 0 }`.
- `position`: uniqueness `{ scope: :shift_cycle_id }` (default msg `"has already been taken"`).

No callbacks/scopes/computed methods.

---

### ShiftAssignment (`shift_assignments`)
Assigns a user to a template (optionally within a cycle) over an effective time range.

**Columns (DB)**
| column | type | null | default |
|---|---|---|---|
| id | bigint PK | no | |
| active | boolean | no | `true` |
| created_at | datetime | no | |
| effective_from | datetime | no | |
| effective_to | datetime | yes | |
| notes | text | yes | |
| shift_cycle_id | bigint FK | yes | |
| shift_template_id | bigint FK | no | |
| updated_at | datetime | no | |
| user_id | bigint FK | no | |
Indexes: `active`, `shift_cycle_id`, `(shift_template_id, effective_from)`, `shift_template_id`, `(user_id, effective_from)`, `user_id`.

**Associations**: `belongs_to :user`; `belongs_to :shift_template`; `belongs_to :shift_cycle, optional: true`.

**Virtual attrs**: `@effective_from_date`, `@effective_from_time` (composed into `effective_from`).

**Scopes**
- `active` → `where(active: true)`.
- `effective_at` (lambda(moment)) → `where("effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)", point, point)` where `point = normalize_effective_point(moment)`.
- `effective_on` → alias of `effective_at`.

**Callbacks**
- `before_validation :apply_effective_from_parts, if: :effective_from_parts_provided?` — runs `assign_effective_from_if_ready(force: true)` when `@effective_from_date` or `@effective_from_time` was set.

**Setters** (each triggers `assign_effective_from_if_ready` non-forced):
- `effective_from_date=` sets `@effective_from_date`.
- `effective_from_time=` sets `@effective_from_time`.
- Getters `effective_from_date`/`effective_from_time` return the ivar if defined, else derived from `effective_from` (`.to_date` / `strftime("%H:%M")`).

**`assign_effective_from_if_ready(force:false)`**: returns unless `force` or both ivars defined. `effective_time = @effective_from_time.presence || shift_template&.start_time_input_value`. If `@effective_from_date` blank or `effective_time` blank → `effective_from = nil`. Else `effective_from = Time.zone.parse("#{@effective_from_date} #{effective_time}")`; rescue → nil.

**Validations**
- `shift_template`: presence.
- `effective_from`: presence.
- `validate :effective_to_must_follow_effective_from` → skip if either blank; if `effective_to < effective_from`, add `:effective_to` → `"must be on or after the effective from date and time"` (equal allowed).
- `validate :shift_cycle_must_have_steps, if: shift_cycle.present?` → if `shift_cycle.shift_cycle_steps.empty?`, add `:shift_cycle` → `"must contain at least one shift."`.

**Class method**: `self.normalize_effective_point(value)` — the canonical time normalizer used across the subsystem:
- blank → `Time.zone.now.change(sec: 0)`
- responds to `in_time_zone` and not a Date → `value.in_time_zone`
- Date → `value.in_time_zone.end_of_day`
- else → `Time.zone.parse(value.to_s)`; rescue `ArgumentError`/`TypeError` → `Time.zone.now.change(sec: 0)`.

**Public method**: `resolved_shift_template(at: Time.current)` → returns `shift_template` (arg ignored; placeholder).

---

### AttendanceRun (`attendance_runs`)
A recorded attendance session for one template + time window, with immutable snapshots.

**Columns (DB)**
| column | type | null | default |
|---|---|---|---|
| id | bigint PK | no | |
| created_at | datetime | no | |
| duration_snapshot_minutes | integer | no | |
| ends_at | datetime | no | |
| notes | text | yes | |
| recorded_by_id | bigint FK | no | |
| shift_name_snapshot | string | no | |
| shift_template_id | bigint FK | no | |
| stale | boolean | no | `false` |
| starts_at | datetime | no | |
| updated_at | datetime | no | |
Indexes: `recorded_by_id`, `(shift_template_id, starts_at)`, `shift_template_id`, `stale`.

**Associations**
- `belongs_to :shift_template`; `belongs_to :recorded_by, class_name: "User"`.
- `has_many :attendance_entries, dependent: :destroy, inverse_of: :attendance_run`.
- `accepts_nested_attributes_for :attendance_entries` (no reject_if/allow_destroy set → destroy via `_destroy` **not** enabled by allow_destroy; but `marked_for_destruction?` checked in validation).

**Scopes**
- `invalid_records` → `where(stale: true)`.
- `valid_records` → `where(stale: false)`.

**Callback**: `before_validation :capture_shift_snapshot` — if `shift_template` present: `shift_name_snapshot = shift_template.name`; `duration_snapshot_minutes = shift_template.duration_minutes`.

**Validations**
- presence: `starts_at`, `ends_at`, `shift_name_snapshot`, `duration_snapshot_minutes`.
- `validate :ends_at_must_follow_starts_at` → skip if either blank; if `ends_at <= starts_at`, add `:ends_at` → `"must be after the start time"` (strict >).
- `validate :must_include_attendance_entries` → if all entries `marked_for_destruction?` (or none), add `:attendance_entries` → `"must include at least one staff member"`.
- `validate :shift_window_must_be_unique` → if `conflicting_shift_window_exists?`, add `:base` → `"Attendance has already been recorded for this shift and time window."`.

**Public computed methods**
- `status_counts` → entries grouped by `status`, each value = count. Shape: `{ "present" => n, "absent" => m, ... }` (string enum keys).
- `record_state_label` → `stale?` ? `"Invalid"` : `"Valid"`.
- `conflicting_shift_window_exists?` → false if `exact_shift_window_scope.none?`; if `stale?` → `exact_shift_window_scope.exists?`, else → `exact_shift_window_scope.valid_records.exists?`.
- `can_mark_valid?` → `stale? && !exact_shift_window_scope.exists?`.

**Private**: `exact_shift_window_scope` → `none` if template/starts_at/ends_at blank; else `where(shift_template_id:, starts_at:, ends_at:)`, excluding own `id` when persisted.

---

### AttendanceEntry (`attendance_entries`)
Per-person attendance record within a run.

**Columns (DB)**
| column | type | null | default |
|---|---|---|---|
| id | bigint PK | no | |
| actual_user_id | bigint FK | yes | |
| attendance_run_id | bigint FK | no | |
| check_in_at | datetime | yes | |
| check_out_at | datetime | yes | |
| created_at | datetime | no | |
| external_replacement_name | string | yes | |
| last_overridden_at | datetime | yes | |
| last_overridden_by_id | bigint FK | yes | |
| notes | text | yes | |
| overridden | boolean | no | `false` |
| replacement_user_id | bigint FK | yes | |
| scheduled_user_id | bigint FK | no | |
| status | integer | no | `0` |
| updated_at | datetime | no | |
Indexes: `actual_user_id`, unique `(attendance_run_id, scheduled_user_id)`, `attendance_run_id`, `last_overridden_by_id`, `replacement_user_id`, `scheduled_user_id`, `status`.

**Enum (INTEGER-backed, load-bearing)**: `status`, `default: :present`, `validate: true`
`present: 0, absent: 1, late: 2, half_day: 3, leave: 4, off: 5`.

**Associations**
- `belongs_to :attendance_run`
- `belongs_to :scheduled_user, class_name: "User"`
- `belongs_to :actual_user, class_name: "User", optional: true`
- `belongs_to :replacement_user, class_name: "User", optional: true`
- `belongs_to :last_overridden_by, class_name: "User", optional: true`
- `has_many :attendance_entry_changes, dependent: :destroy`

**Callback**: `before_validation :sync_actual_user` — `actual_user = replacement_user` if replacement present; then return if `actual_user` present OR `external_replacement_name` present OR `absent?`; else `actual_user = scheduled_user`.

**Validations**
- `scheduled_user`: presence.
- `validate :check_out_must_follow_check_in` → skip if either blank; if `check_out_at < check_in_at`, add `:check_out_at` → `"must be after check in"` (equal allowed, strict `<` fails).

**Public computed method**
- `worker_name` → `actual_user.display_name` if actual present; else `external_replacement_name` if present; else `"Not covered"` if `absent?`; else `scheduled_user.display_name`.

---

### AttendanceEntryChange (`attendance_entry_changes`)
Audit record of an override to an entry, with before/after JSON snapshots.

**Columns (DB)**
| column | type | null | default |
|---|---|---|---|
| id | bigint PK | no | |
| after_payload | jsonb | no | `{}` |
| attendance_entry_id | bigint FK | no | |
| before_payload | jsonb | no | `{}` |
| change_reason | string | no | |
| changed_by_id | bigint FK | no | |
| created_at | datetime | no | |
| updated_at | datetime | no | |
Indexes: `attendance_entry_id`, `changed_by_id`.

**Associations**: `belongs_to :attendance_entry`; `belongs_to :changed_by, class_name: "User"`.

**Validations**: `change_reason`: presence.

No callbacks/scopes/computed methods.

---

### ShiftSwap (`shift_swaps`)
Records swapping one user's shift to another user (one-off, temporary, or permanent).

**Columns (DB)**
| column | type | null | default |
|---|---|---|---|
| id | bigint PK | no | |
| created_at | datetime | no | |
| ends_at | datetime | yes | |
| from_shift_template_id | bigint FK | no | |
| from_user_id | bigint FK | no | |
| reason | text | no | |
| recorded_by_id | bigint FK | no | |
| starts_at | datetime | no | |
| swap_kind | integer | no | `0` |
| to_shift_template_id | bigint FK | yes | |
| to_user_id | bigint FK | no | |
| updated_at | datetime | no | |
Indexes: `from_shift_template_id`, `(from_user_id, starts_at)`, `from_user_id`, `recorded_by_id`, `to_shift_template_id`, `(to_user_id, starts_at)`, `to_user_id`.

**Enum (INTEGER-backed, load-bearing)**: `swap_kind`, `default: :this_shift_only`, `validate: true`
`this_shift_only: 0, temporary: 1, permanent: 2`.

**Associations**
- `belongs_to :from_user, class_name: "User"`
- `belongs_to :to_user, class_name: "User"`
- `belongs_to :from_shift_template, class_name: "ShiftTemplate"`
- `belongs_to :to_shift_template, class_name: "ShiftTemplate", optional: true`
- `belongs_to :recorded_by, class_name: "User"`

**Validations**
- presence: `starts_at`, `reason`.
- `validate :users_must_be_different` → skip if either user id blank; if `from_user_id == to_user_id`, add `:to_user` → `"must be different from the original staff member"`.
- `validate :ends_at_must_follow_starts_at` → skip if either blank; if `ends_at <= starts_at`, add `:ends_at` → `"must be after the start time"` (strict >).

No callbacks/scopes/computed methods.

---

### Cross-cutting notes for the API layer
- **Time normalization is centralized** in `ShiftAssignment.normalize_effective_point` and reused by `ShiftCycle#window_for`/`#valid_window_for?`. Any API date/time input should pass through it for parity. Date → `end_of_day`; blank/unparseable → now with seconds zeroed.
- **Snapshots**: `AttendanceRun` copies `shift_name_snapshot`/`duration_snapshot_minutes` from the template on every `before_validation`; API responses should read the snapshot columns, not the live template.
- **Uniqueness guards**: `attendance_runs` has no DB unique index on the window — uniqueness is enforced only in Ruby (`shift_window_must_be_unique`), and its behavior depends on the `stale` flag (stale runs collide against ALL runs; non-stale only against `valid_records`). `attendance_entries` has a DB unique index `(attendance_run_id, scheduled_user_id)`.
- **`restrict_with_exception`** on ShiftTemplate/ShiftCycle associations: deleting a template/cycle with dependent assignments/steps/runs/swaps raises `ActiveRecord::DeleteRestrictionError` — API delete endpoints must handle this (ShiftCycle exposes `deletable?` as a pre-check; ShiftTemplate has none).
- **Virtual write attributes** the API must accept but that aren't columns: `ShiftTemplate#duration_hours=`, `ShiftAssignment#effective_from_date=`/`effective_from_time=`. These drive `duration_minutes` / `effective_from`.
- **`period_days`** on `shift_cycles` is persisted (default `1`) but unused by model logic; cycle length derives from summed step durations.

**File paths**: `/Users/achalindiresh/workspace/fuel-loyalty/app/models/{shift_template,shift_cycle,shift_cycle_step,shift_assignment,attendance_run,attendance_entry,attendance_entry_change,shift_swap}.rb`; schema `/Users/achalindiresh/workspace/fuel-loyalty/db/schema.rb`.