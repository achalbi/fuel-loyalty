## models:platform

Reference for `NotificationSchedule`, `PushSubscription`, `SchedulerLease`, `AnalyticsEvent`. All ActiveRecord (`< ApplicationRecord`). Schema from `db/schema.rb` (Postgres). Bare `< ApplicationRecord` (no STI). No enums use integer backing in these four models; `frequency`/`platform`/`name` are STRING-validated inclusion lists (load-bearing string values below).

---

### NotificationSchedule
File: `app/models/notification_schedule.rb`

**Table `notification_schedules`**

| Column | Type | Null | Default |
|---|---|---|---|
| id | bigint (PK) | no | — |
| active | boolean | no | `true` |
| title | string | no | — |
| message | text | no | — |
| frequency | string | no | — |
| scheduled_time | string | no | — (stored as `"HH:MM"` string, NOT time type) |
| scheduled_date | date | yes | — |
| day_of_week | integer | yes | — (0=Sun … 6=Sat) |
| day_of_month | integer | yes | — (1–31) |
| last_sent_at | datetime | yes | — |
| created_at | datetime | no | — |
| updated_at | datetime | no | — |

Indexes: `active`, `frequency`.

**Constants**
- `FREQUENCIES = %w[once daily weekly monthly]` (frozen)
- `TIME_FORMAT = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/` — 24h `HH:MM`, `00:00`–`23:59`
- `WEEKDAY_OPTIONS = [["Sunday",0],["Monday",1],["Tuesday",2],["Wednesday",3],["Thursday",4],["Friday",5],["Saturday",6]]` (frozen; label→value pairs)

**Scopes**
- `active` → `where(active: true)`
- `recent_first` → `order(active: :desc, created_at: :desc)`

**Callbacks** (run in this order, both `before_validation`)
1. `normalize_scheduled_time`: if `scheduled_time` blank → return (no change). Else parse `scheduled_time.to_s.strip` with `Time.zone.strptime(..., "%H:%M")`, then set `self.scheduled_time = parsed.strftime("%H:%M")` (zero-pads/normalizes to `HH:MM`). On `ArgumentError` (unparseable) → set `self.scheduled_time = scheduled_time.to_s.strip` (stripped raw value, left to fail format validation).
2. `normalize_schedule_fields`: nils out irrelevant fields — `scheduled_date = nil` unless `frequency == "once"`; `day_of_week = nil` unless `frequency == "weekly"`; `day_of_month = nil` unless `frequency == "monthly"`. (API note: sending `day_of_week` with `frequency: "daily"` silently drops it before validation.)

**Validations**
- `title` presence → default AR msg `"can't be blank"`
- `message` presence → `"can't be blank"`
- `frequency` presence → `"can't be blank"`; inclusion in `FREQUENCIES` → `"is not included in the list"`
- `scheduled_time` presence → `"can't be blank"`; format `TIME_FORMAT` → `"is invalid"`
- `day_of_week` inclusion `0..6`, `allow_nil: true` → `"is not included in the list"`
- `day_of_month` inclusion `1..31`, `allow_nil: true` → `"is not included in the list"`
- Custom `required_schedule_fields_for_frequency`: `frequency == "once"` → if `scheduled_date` blank, `errors.add(:scheduled_date, "can't be blank")`. `"weekly"` → if `day_of_week` blank, `errors.add(:day_of_week, "can't be blank")`. `"monthly"` → if `day_of_month` blank, `errors.add(:day_of_month, "can't be blank")`. (`"daily"` and unknown → no extra requirement.)

**Public value methods** (API-returnable)
- `scheduled_hour` → Integer. `scheduled_time.to_s.split(":").first.to_i` (hour part).
- `scheduled_minute` → Integer. `scheduled_time.to_s.split(":").last.to_i` (minute part).
- `scheduled_at_on(date, zone: Time.zone)` → `ActiveSupport::TimeWithZone`. `zone.local(date.year, date.month, date.day, scheduled_hour, scheduled_minute)` — combines given date + this schedule's time in `zone`.
- `frequency_label` → String. `frequency.to_s.titleize` (e.g. `"once"`→`"Once"`).
- `schedule_summary` → String, by frequency:
  - `"once"` → if `scheduled_date` blank: `"One time"`; else `"One time on #{scheduled_date.strftime('%d %b %Y')} at #{scheduled_time}"` (e.g. `"One time on 12 Jul 2026 at 09:30"`).
  - `"daily"` → `"Daily at #{scheduled_time}"`.
  - `"weekly"` → weekday label = `WEEKDAY_OPTIONS.find { |(_l,v)| v == day_of_week }&.first || "Selected day"`; then `"Weekly on #{weekday} at #{scheduled_time}"`.
  - `"monthly"` → `"Monthly on day #{day_of_month} at #{scheduled_time}"`.
  - else → `scheduled_time.to_s`.

No associations. No `dependent:`.

---

### PushSubscription
File: `app/models/push_subscription.rb`

**Table `push_subscriptions`**

| Column | Type | Null | Default |
|---|---|---|---|
| id | bigint (PK) | no | — |
| active | boolean | no | `true` |
| token | text | no | — |
| platform | string | no | — |
| last_used_at | datetime | no | — |
| created_at | datetime | no | — |
| updated_at | datetime | no | — |

Indexes: `active`, `last_used_at`, `platform`, `token` (**unique**).

**Constants**
- `PLATFORMS = %w[android ios web desktop unknown]` (frozen)

**Scopes**
- `active` → `where(active: true)`

**Callbacks** (order, both `before_validation`)
1. `normalize_token`: `self.token = self.class.normalize_token(token)` → `value.to_s.strip` (strips whitespace).
2. `normalize_platform`: `normalized = platform.to_s.strip.downcase`; `self.platform = normalized.presence_in(PLATFORMS) || "unknown"` (any value not exactly in `PLATFORMS` after downcase/strip becomes `"unknown"` — so platform inclusion validation effectively never fails via user input, but blank normalizes to `"unknown"` too, not blank).

**Validations**
- `token` presence → `"can't be blank"`; uniqueness → `"has already been taken"` (case-sensitive; enforced by unique index too).
- `platform` presence → `"can't be blank"`; inclusion in `PLATFORMS` → `"is not included in the list"` (unreachable in practice due to normalization fallback).
- `last_used_at` presence → `"can't be blank"`.

**Class methods**
- `self.normalize_token(value)` → String. `value.to_s.strip`.
- `self.register!(token:, platform:, last_used_at: Time.current)` → returns the `PushSubscription`. Algorithm: `find_or_initialize_by(token: normalize_token(token))` (dedupes on normalized token); `assign_attributes(platform:, last_used_at:, active: true)`; `save!` (raises `ActiveRecord::RecordInvalid` on failure); return subscription. Idempotent upsert-by-token that reactivates existing rows.

**Instance methods**
- `deactivate!(timestamp: Time.current)` → `update!(active: false, last_used_at: timestamp)`. Raises on invalid.
- `touch_last_used!(timestamp: Time.current)` → `update!(last_used_at: timestamp, active: true)` (also reactivates). Raises on invalid.

No associations. No `dependent:`.

---

### SchedulerLease
File: `app/models/scheduler_lease.rb`

**Table `scheduler_leases`**

| Column | Type | Null | Default |
|---|---|---|---|
| id | bigint (PK) | no | — |
| key | string | no | — |
| running | boolean | no | `false` |
| lease_token | string | yes | — |
| started_at | datetime | yes | — |
| finished_at | datetime | yes | — |
| last_heartbeat_at | datetime | yes | — |
| created_at | datetime | no | — |
| updated_at | datetime | no | — |

Indexes: `key` (**unique**), `running`.

**Validations**
- `key` presence → `"can't be blank"`; uniqueness → `"has already been taken"` (unique index backs it).

**Scopes**
- `running` → `where(running: true)`

No callbacks, no associations, no enums, no public compute methods. Lease-state fields (`running`, `lease_token`, `started_at`, `finished_at`, `last_heartbeat_at`) are managed externally (not in this model).

---

### AnalyticsEvent
File: `app/models/analytics_event.rb`

**Table `analytics_events`**

| Column | Type | Null | Default |
|---|---|---|---|
| id | bigint (PK) | no | — |
| name | string | no | — |
| page_path | string | no | — |
| properties | jsonb | no | `{}` |
| user_agent | text | yes | — |
| user_id | bigint | yes | — (FK, optional) |
| created_at | datetime | no | — |
| updated_at | datetime | no | — |

Indexes: `created_at`, `name`, `user_id`.

**Constants**
- `INSTALL_EVENT_NAMES` (frozen) — the only allowed `name` values, in this order:
  `pwa_install_cta_viewed`, `pwa_install_prompt_available`, `pwa_install_cta_clicked`, `pwa_install_manual_instructions_shown`, `pwa_install_prompt_shown`, `pwa_install_prompt_accepted`, `pwa_install_prompt_dismissed`, `pwa_install_completed`, `pwa_install_prompt_error`.

**Associations**
- `belongs_to :user, optional: true` (nullable FK; no `dependent:`).

**Callbacks**
- `before_validation :normalize_properties`: `self.properties = {} unless properties.is_a?(Hash)` (coerces non-Hash/nil to empty hash before validation/save).

**Validations**
- `name` presence → `"can't be blank"`; inclusion in `INSTALL_EVENT_NAMES` → `"is not included in the list"`.
- `page_path` presence → `"can't be blank"`.
- (`user` optional — no presence validation on association.)

No scopes, no enums (name is a STRING inclusion list), no public compute methods.

---

**Cross-model API notes**
- Timestamps: `NotificationSchedule.scheduled_time` is a **string** `"HH:MM"`, not a time column — serialize as-is.
- `PushSubscription` and `NotificationSchedule` both expose `scope :active`; `PushSubscription.register!`/`touch_last_used!`/`deactivate!` and `NotificationSchedule` bang-free readers are the API-relevant surface.
- Only `AnalyticsEvent` has an association (`user`, optional). None of the four declare `dependent:` or `restrict` rules.
- Default AR error strings above assume the standard `en` locale; no custom `:message` overrides exist except the custom-validator `errors.add(..., "can't be blank")` calls, which are quoted verbatim.