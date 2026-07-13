## Subsystem: services:platform

Reference for six platform-layer service objects. No models/controllers/policies in scope; all entries follow SERVICE format. External model/method dependencies noted inline where an API reimplementation must know the contract.

---

### `NotificationScheduleRunner`
File: `app/services/notification_schedule_runner.rb`
Purpose: singleton-leased cron runner that finds due `NotificationSchedule` rows and broadcasts them via `FirebasePushService`.

**Constants**
- `LEASE_KEY = "notification_schedule_runner"` — `SchedulerLease.key` used for the mutex row.
- `LEASE_TIMEOUT = 10.minutes` — a lease older than this (by heartbeat) is considered stale and stealable.

**`Result` struct** (`keyword_init`) — fields: `checked, due, sent, failed, details, acquired, skipped, message`. `#as_json` returns exactly those 8 keys (hash, same names/order).

**Constructor** — `new(push_service: FirebasePushService.new)`. Injects the push service (test seam).

**Class method `is_due?(schedule, current_time)` → Boolean** (public, load-bearing predicate):
1. `false` unless `schedule.active?`.
2. Coerce `current_time` to `Time.zone`.
3. `occurrence_time = occurrence_at(schedule, current_time)`; return `false` if blank.
4. Return `false` if `current_time < occurrence_time` (not yet due).
5. Return `true` if `schedule.last_sent_at` blank OR `last_sent_at.in_time_zone(Time.zone) < occurrence_time` (i.e. not already sent for this occurrence).

**Class method `occurrence_at(schedule, current_time)` → Time|nil** — computes the target send instant for the current period. `rescue ArgumentError → nil`. Branches on `schedule.frequency` (STRING values):
- `"once"`: `nil` if `scheduled_date` blank; else `schedule.scheduled_at_on(schedule.scheduled_date)`.
- `"daily"`: `schedule.scheduled_at_on(current_time.to_date)`.
- `"weekly"`: `nil` if `day_of_week` blank; else week start = `current_time.to_date.beginning_of_week(:sunday)`; occurrence at `scheduled_at_on(week_start + day_of_week.days)`. (`day_of_week`: 0=Sun … per Sunday-start offset.)
- `"monthly"`: `nil` if `day_of_month` blank; `day = min(day_of_month, current_time.to_date.end_of_month.day)` (clamps to month length); occurrence at `scheduled_at_on(Date.new(year, month, day))`.
- (any other frequency → implicit `nil`).
- Depends on `NotificationSchedule#scheduled_at_on(date)` returning the datetime combining that date with the schedule's time-of-day.

**Instance method `run(current_time: Time.current)` → Result** — public entry point:
1. Coerce `current_time` to `Time.zone`.
2. `lease = acquire_lease(current_time)`. If nil (another run active), return `Result` with `checked:0, due:0, sent:0, failed:0, details:[], acquired:false, skipped:true, message: "Scheduler run skipped because another run is already in progress."`.
3. `schedules = NotificationSchedule.active.recent_first.to_a`. Build `Result` with `checked: schedules.length`, zeros, `acquired:true, skipped:false, message: "Scheduler run completed."`.
4. For each schedule: `heartbeat_lease!(lease)`; `next unless is_due?(schedule, current_time)`; then `result.due += 1` and:
   - `delivery_result = @push_service.broadcast(title: schedule.title, message: schedule.message)`.
   - `schedule.update!(last_sent_at: current_time, active: schedule.frequency == "once" ? false : schedule.active)` — one-shot schedules self-deactivate after send.
   - `result.sent += 1`; append to `details`: `{ schedule_id:, title:, result: delivery_result.as_json }`.
   - On `StandardError`: `result.failed += 1`; append `{ schedule_id:, title:, error: error.message }`.
5. `ensure`: `release_lease(lease, Time.current.in_time_zone(Time.zone))` if a lease was held.
Returns the `Result`.

**Locking / concurrency (private):**
- `acquire_lease(current_time)`: `token = SecureRandom.uuid`; `lease = scheduler_lease_record`. Inside `lease.with_lock` (row lock): if `lease.running? && last_heartbeat_at.present? && last_heartbeat_at > current_time - LEASE_TIMEOUT` → `next` (do not acquire). Else `lease.update!(running:true, lease_token: token, started_at: current_time, last_heartbeat_at: current_time)`, `acquired=true`. Returns `{ record: lease, token: token }` or `nil`.
- `heartbeat_lease!(lease)`: `SchedulerLease.where(id: <record.id>).update_all(last_heartbeat_at: Time.current.in_time_zone(Time.zone))`.
- `release_lease(lease, current_time)`: inside `record.with_lock`, `return unless record.lease_token == token` (only owner clears); else `update!(running:false, lease_token:nil, last_heartbeat_at: current_time, finished_at: current_time)`.
- `scheduler_lease_record`: `SchedulerLease.find_or_create_by!(key: LEASE_KEY)`; `rescue ActiveRecord::RecordNotUnique → retry`.
- Model contract: `SchedulerLease` needs columns `key`, `running`(bool), `lease_token`, `started_at`, `last_heartbeat_at`, `finished_at`, plus `#running?`. `NotificationSchedule` needs scopes `active`, `recent_first`; attrs `title, message, frequency, scheduled_date, day_of_week, day_of_month, last_sent_at, active`; `#active?`, `#scheduled_at_on`.

---

### `FirebasePushService`
File: `app/services/firebase_push_service.rb`
Purpose: batch-sends an FCM v1 push notification to all active `PushSubscription`s.

**Constants**
- `BATCH_SIZE = 500`; `DEFAULT_BATCH_DELAY_SECONDS = 0.05`; `DEFAULT_TIMEOUT_SECONDS = 15` (both open & read timeout).
- `INVALID_TOKEN_CODES = %w[UNREGISTERED INVALID_ARGUMENT]` — FCM error codes that trigger subscription deactivation.
- `NOTIFICATION_ICON_PATH = "/notification-pump-icon.svg"`; `NOTIFICATION_BADGE_PATH = "/notification-pump-badge.svg"`.

**`Result` struct** (`keyword_init`) — fields: `requested, sent, failed, invalidated, batches, errors`. `#as_json` returns exactly those 6 keys. `errors` is an array of `{ subscription_id:, status:(Integer|nil), error:(String) }`.

**Constructor** — `new(subscriptions: PushSubscription.active, batch_size: BATCH_SIZE, batch_delay: DEFAULT_BATCH_DELAY_SECONDS)`.

**`broadcast(title:, message:)` → Result** — public entry point:
1. `validate_configuration!` — raises `FirebaseAppConfig::ConfigurationError, "FIREBASE_PROJECT_ID or a Firebase service account must be configured."` unless `FirebaseAppConfig.push_delivery_ready?`.
2. `result = Result.new(requested: @subscriptions.active.count, sent:0, failed:0, invalidated:0, batches:0, errors:[])`.
3. `access_token = fetch_access_token` (see below).
4. `endpoint_uri = URI.parse(endpoint)` where `endpoint = "https://fcm.googleapis.com/v1/projects/#{FirebaseAppConfig.project_id}/messages:send"`.
5. `@subscriptions.active.order(:id).in_batches(of: @batch_size)`: skip empty batches; `result.batches += 1`; open one keep-alive TLS connection per batch (`Net::HTTP.start(host, port, use_ssl:true, open_timeout:15, read_timeout:15)`); for each subscription call `deliver_to_subscription`. After each batch, `sleep(@batch_delay)` if `@batch_delay.to_f.positive?`.
6. Returns `result`.

**`fetch_access_token` (private)** — `FirebaseAppConfig.credentials.fetch_access_token!` then `.fetch("access_token")`. On `KeyError`/`StandardError` raises `FirebaseAppConfig::ConfigurationError, "Could not fetch a Firebase access token: #{error.message}"`.

**`deliver_to_subscription(http:, endpoint_uri:, access_token:, subscription:, title:, message:, result:)` (private)** — per-token HTTP POST:
- Headers: `Authorization: "Bearer #{access_token}"`, `Content-Type: "application/json; charset=utf-8"`. Body = `build_payload(...).to_json`.
- On `Net::HTTPSuccess`: `subscription.touch_last_used!`; `result.sent += 1`; return.
- Else: `parsed_error = parse_json(response.body)`; `result.failed += 1`. If `invalid_token_error?(parsed_error)`: `subscription.deactivate!`; `result.invalidated += 1`. Append `{ subscription_id: subscription.id, status: response.code.to_i, error: error_message_for(parsed_error, response.message) }`.
- On `StandardError` (network/other): `result.failed += 1`; append `{ subscription_id:, status: nil, error: error.message }`.

**`build_payload(subscription:, title:, message:)` (private)** — exact FCM v1 body:
```
{ message: {
    token: subscription.token,
    notification: { title:, body: message },
    data: { title:, message:, link: FirebaseAppConfig.notification_link, notification_id: SecureRandom.uuid },
    webpush: {
      headers: { Urgency: "high", TTL: "86400" },
      notification: { title:, body: message,
        icon: asset_url("/notification-pump-icon.svg"),
        badge: asset_url("/notification-pump-badge.svg"),
        tag: "fuel-loyalty-broadcast" },
      fcm_options: { link: asset_url(FirebaseAppConfig.notification_link) } } } }
```
Note: `data.link` is the raw `notification_link`; `webpush.fcm_options.link` is that same path run through `asset_url` (absolutized).

**Helpers (private):**
- `asset_url(path)`: returns `path` unchanged if `ENV["APP_URL"]` blank; else `URI.join("#{ENV['APP_URL'].chomp('/')}/", path.delete_prefix("/")).to_s`; `rescue URI::InvalidURIError → path`.
- `parse_json(value)`: `JSON.parse`, `rescue JSON::ParserError, TypeError → {}`.
- `invalid_token_error?(parsed_error)`: `details = parsed_error.dig("error","details")`; false unless Array; true if any detail has `"@type" == "type.googleapis.com/google.firebase.fcm.v1.FcmError"` AND `"errorCode"` ∈ `INVALID_TOKEN_CODES`.
- `error_message_for(parsed_error, fallback)`: `parsed_error.dig("error","message").presence || fallback`.
- Model contract: `PushSubscription` needs scope `active`, `#token`, `#touch_last_used!`, `#deactivate!`, `#id`.

---

### `FirebaseAppConfig`
File: `app/services/firebase_app_config.rb`
Purpose: ENV-driven Firebase configuration resolver + credential factory. All class methods.

**Constants**
- `FIREBASE_SDK_VERSION = "12.11.0"`.
- `FIREBASE_MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"`.
- `WEB_CONFIG_KEYS` (ordered map client_key → ENV var): `apiKey→FIREBASE_API_KEY`, `authDomain→FIREBASE_AUTH_DOMAIN`, `storageBucket→FIREBASE_STORAGE_BUCKET`, `messagingSenderId→FIREBASE_MESSAGING_SENDER_ID`, `appId→FIREBASE_APP_ID`, `measurementId→FIREBASE_MEASUREMENT_ID`.
- Nested error class `ConfigurationError < StandardError`.

**Class methods:**
- `project_id` → first present of: `ENV["FIREBASE_PROJECT_ID"]`, `service_account_payload["project_id"]`, `ENV["GOOGLE_CLOUD_PROJECT"]`, `ENV["GOOGLE_CLOUD_PROJECT_ID"]` (nil if all blank).
- `vapid_key` → `ENV["FIREBASE_WEB_VAPID_KEY"].presence`.
- `notification_link` → `ENV["PUSH_NOTIFICATION_LINK"].presence || "/loyalty"`.
- `web_config` → hash starting `{ projectId: project_id }` then adds each `WEB_CONFIG_KEYS` entry whose ENV var is present; `.compact` (drops nil `projectId`). Keys are the client_key symbols.
- `web_push_ready?` → `web_configured? && vapid_key.present?`.
- `web_configured?` → all of `web_config.slice(:apiKey, :messagingSenderId, :appId, :projectId)` values present.
- `push_delivery_ready?` → `project_id.present?`.
- `credentials` → if `service_account_json` present: `Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: StringIO.new(service_account_json), scope: FIREBASE_MESSAGING_SCOPE)`; else `Google::Auth.get_application_default([FIREBASE_MESSAGING_SCOPE])`. On any `StandardError` raises `ConfigurationError, "Firebase credentials are not configured: #{error.message}"`.
- `service_account_json` → `ENV["FIREBASE_SERVICE_ACCOUNT_JSON"].presence`.
- `service_account_payload` → `{}` if `service_account_json` blank; else `JSON.parse(service_account_json)`; `rescue JSON::ParserError → {}`.

---

### `AttendanceRosterBuilder`
File: `app/services/attendance_roster_builder.rb`
Purpose: resolves the active staff roster for a shift template at a given start time.

**Entry point** — `AttendanceRosterBuilder.call(shift_template:, starts_at:)` (delegates to `new(...).call`).
**Constructor** — `new(shift_template:, starts_at:)`.

**`call` → Array<Hash>** — maps each assignment to `{ staff_member: assignment.user, assignment: assignment }`. Return is an array of hashes with keys `staff_member` (a `User`) and `assignment` (a `ShiftAssignment`).

**`assignments` (private) → ActiveRecord relation:**
```
ShiftAssignment
  .includes(:user, :shift_template)
  .active
  .effective_at(starts_at)
  .where(shift_template_id: shift_template.id)
  .joins(:user)
  .merge(User.active.where(role: :staff).order(:name, :username, :phone_number))
```
- Filters: `ShiftAssignment.active` scope, `.effective_at(starts_at)` scope, matching `shift_template_id`; joined `User` must be `User.active` with `role: :staff`.
- Ordering: by user `name`, then `username`, then `phone_number` (ascending).
- Contract: `ShiftAssignment` needs assocs `user`, `shift_template`; scopes `active`, `effective_at(time)`. `User` needs scope `active`, enum/attr `role` (`:staff`), columns `name, username, phone_number`.

---

### `Admin::Dashboard::OverviewReport`
File: `app/services/admin/dashboard/overview_report.rb`
Purpose: builds the admin analytics dashboard payload (summary cards, charts, rewards) over a date range, with segment + fuel-type filters and previous-period comparison.

**Constants**
- `DEFAULT_RANGE_DAYS = 30`.
- `QUICK_RANGES` (STRING→label, ordered): `"today"→"Today"`, `"this_week"→"This week"`, `"this_month"→"This month"`, `"last_month"→"Last month"`.
- `SEGMENTS`: `"all"→"All customers"`, `"new"→"New customers"`, `"repeat"→"Repeat customers"`.
- `WEEKDAY_ORDER` (int DOW→label, this exact order): `1→"Mon", 2→"Tue", 3→"Wed", 4→"Thu", 5→"Fri", 6→"Sat", 0→"Sun"`.
- `LEGACY_REDEMPTION_BUCKET = :legacy_other`.

**Constructor** — `new(start_date:, end_date:, segment:, preset: nil, fuel_type: nil)`:
1. `@preset` = `preset.to_s` if it's a `QUICK_RANGES` key, else `nil`.
2. `@segment` = `segment.to_s` if a `SEGMENTS` key, else `"all"`.
3. `@fuel_type_options = available_fuel_type_options` = `{ "all" => "Total" }` merged with `FuelType.for_settings` mapped `code → name`.
4. `@fuel_type` = `fuel_type.to_s` if in options, else `"all"`.
5. If preset present: `[@start_date, @end_date] = dates_for_preset(@preset)`. Else `@end_date = parse_date(end_date) || Time.zone.today`; `@start_date = parse_date(start_date) || (@end_date - 29.days)`.
6. Swap if inverted: `@start_date, @end_date = @end_date, @start_date if @start_date > @end_date`.
- `parse_date(value)`: nil if blank; `Date.iso8601(value)`; `rescue ArgumentError → nil`.
- `dates_for_preset(value)` (today = `Time.zone.today`): `"today"→[today,today]`; `"this_week"→[today.beginning_of_week, today]`; `"this_month"→[today.beginning_of_month, today]`; `"last_month"→[last_month.beginning_of_month, last_month.end_of_month]`; else `[today-29.days, today]`.

**`as_json(*)` → Hash** — top-level API shape:
```
{ filters:, summary: <summary_cards array>, charts: <chart_payload>, rewards: <rewards_summary>,
  meta: { range_label: "DD Mon YYYY - DD Mon YYYY",
          segment_label: SEGMENTS[segment], fuel_type_label: fuel_type_options[fuel_type],
          generated_at: <Time.current.iso8601> } }
```
`range_label` uses `strftime('%d %b %Y')` for both dates joined by `" - "`.

**`filters` (public) → Hash:**
```
{ start_date: <iso8601>, end_date: <iso8601>, preset:,
  presets: [ { value:, label:, start_date:<iso>, end_date:<iso> } for each QUICK_RANGE ],
  segment:, segments: [ {value:, label:} for each SEGMENTS ],
  fuel_type:, fuel_types: [ {value:, label:} for each fuel_type_options ] }
```

**Range/period internals (private):**
- `period_length` = `(end_date - start_date).to_i + 1` (inclusive day count).
- `current_range` = `start_date.beginning_of_day..end_date.end_of_day`.
- `previous_range` = ends `start_date - 1.day`, starts `previous_end - (period_length-1).days`; as beginning_of_day..end_of_day (equal-length immediately-preceding window).
- `daily_labels` = each date in `start_date..end_date` as `strftime("%d %b")`.
- `previous_customer_cutoff` = `previous_range.end.to_date.end_of_day`.

**Scoping helpers (private):**
- `filtered_transactions_for(range)`: `Transaction.where(created_at: range)`; if `fuel_type != "all"` add `.joins(:vehicle).where(vehicles: { fuel_type: fuel_type })`.
- `transactions_for(range)`: `filtered_transactions_for`; if segment ≠ "all", restrict to `segment_customer_ids_for(range)` (or `.none` if empty).
- `point_entries_for(range)`: `PointsLedger.where(created_at: range)`; if `fuel_type != "all"` add `.joins(fuel_transaction: :vehicle).where(vehicles:{fuel_type:})`; segment restriction same as above (`.none` if empty ids).
- `segment_customer_ids_for(range)`: `"new"→new_customer_ids_for`, `"repeat"→repeat_customer_ids_for`, else `Customer.where(created_at: ..range.end).pluck(:id)`.
- `new_customer_ids_for(range)`: transactions grouped by `customer_id` HAVING the in-range MIN(created_at) equals the customer's all-time first transaction (SQL: `MIN(transactions.created_at) = (SELECT MIN(t2.created_at) FROM transactions t2 WHERE t2.customer_id = transactions.customer_id)`); plucks `customer_id`.
- `repeat_customer_ids_for(range)`: in-range distinct customer_ids; then `Transaction.where(customer_id: those).group(:customer_id).minimum(:created_at)`; keep customer_ids whose first visit `< range.begin`.
- `distinct_customers_count(scope)` = `scope.distinct.count(:customer_id)`.

**Customer totals (private):**
- `customers_total_for_range`: new→count of new ids; repeat→count of repeat ids; else `fuel_type=="all" ? Customer.where(created_at: ..current_range.end).count : distinct_customers_count(filtered_transactions_for(current_range))`.
- `customers_total_for_previous_range`: analogous over `previous_range`; "all"+"all fuel" uses `Customer.where(created_at: ..previous_customer_cutoff).count`.
- `active_customer_count`: range = last 30 days ending `end_date` (`(end_date - 29.days).beginning_of_day..end_date.end_of_day`); `filtered_transactions_for`; if segment≠"all" restrict to `segment_customer_ids_for(current_range)`; distinct customer count.
- `previous_active_customer_count`: same window shape anchored on `previous_range.end.to_date`, segment ids from `previous_range`.

**Metric math (private):**
- `transactions_count(scope)` = `scope.count`.
- `revenue_total(scope)` = `scope.sum(:fuel_amount).to_f`.
- `revenue_breakdown(scope)`: group `vehicles.fuel_type` sum `fuel_amount`; ordered codes = `FuelType.for_settings.map(&:code)` + grouped keys (uniq); skip zero amounts; each → `{ key: code, label: FuelType.label_for(code), value: amount.round(2), display_value: display_metric(amount, format: :currency) }`.
- `issued_points_total(scope)` = `scope.where(entry_type: :earn).sum(:points).to_i`.
- `redeemed_points_total(scope)` = `scope.where(entry_type: :redeem).sum("ABS(points)").to_i`.
- `avg_spend(rev, txns)` = `0` if txns zero else `rev/txns`.
- `visits_per_customer(txns, distinct)` = `0` if distinct zero else `txns.to_f/distinct`.

**`summary_cards` → Array of metric payloads** (this exact order): `total_customers`, `active_customers`, `total_transactions`, `total_revenue` (with `breakdown: current_revenue_breakdown`), `points_issued`, `points_redeemed`, `avg_spend_per_visit`, `visits_per_customer`. Each via `metric_payload`.
- `metric_payload(key, current, previous, format:, breakdown: nil)` → `{ key:, value: current.round(2), display_value: display_metric(current, format:), change_pct: percentage_change(current, previous), previous_value: previous.round(2), direction: metric_direction(current, previous), breakdown: }`.
- `display_metric(value, format:)`: `:currency` → `number_to_currency(value, unit: "₹", precision: value < 100 ? 2 : 0)`; `:decimal` → `number_with_precision(value, precision:1, strip_insignificant_zeros:true)`; else → `number_with_delimiter(value.to_i)`. (Uses `ApplicationController.helpers`.)
- `percentage_change(cur, prev)`: `nil` if `prev.to_f.zero?`; else `(((cur-prev)/prev.to_f)*100).round(1)`.
- `metric_direction(cur, prev)`: `"neutral"` if `prev.to_f.zero?` or `cur == prev`; else `cur > prev ? "up" : "down"`.

**`chart_payload` → Hash** (keys in order): `transactions_trend`, `revenue_trend`, `points_trend`, `active_users_trend`, `repeat_vs_new`, `visits_distribution`, `top_customers_by_transactions`, `top_customers_by_revenue`, `top_rewards_redeemed`, `transactions_by_hour`, `transactions_by_day`.
- `line_series_for(scope, value_type:)`: `:count`→group `DATE(transactions.created_at)` count; `:revenue`→same sum `fuel_amount`. Returns `{ labels: daily_labels, datasets: [ { data: <daily series>, value_type: value_type.to_s } ] }`.
- `points_series_for(scope)`: issued (earn, group DATE sum points), redeemed (redeem, group DATE sum ABS(points)). `{ labels:, datasets: [ {label:"Issued", data:, value_type:"number"}, {label:"Redeemed", data:, value_type:"number"} ] }`.
- `active_users_series_for(scope)`: group DATE distinct count customer_id → `{ labels:, datasets: [ { data:, value_type:"number" } ] }`.
- `repeat_vs_new_payload`: `new_count`/`repeat_count` from id lists; if segment "new"→repeat=0; if "repeat"→new=0. `{ labels: ["New","Repeat"], values: [new_count, repeat_count] }`.
- `visits_distribution_payload`: per-customer txn counts → `{ labels: ["1 visit","2-5 visits","6+ visits"], values: [count==1, between 2..5, >=6] }`.
- `top_customer_chart_payload(metric:)` (used by `top_customers_by_transactions` metric `:count`, `top_customers_by_revenue` metric `:revenue`): returns `{ labels: [top5 labels], values: [top5 values], value_type: metric==:revenue ? "currency" : "number", items: [<build_top_customer_item> per entry], comparison: <chart_comparison_payload of current-sum vs previous-sum> }`.
  - `top_customers_for(scope, metric:)`: group `customer_id` (revenue→sum fuel_amount, else count); join Customer by id; each `{ customer_id:, label: customer_chart_label(customer), value: revenue ? .round(2) : .to_i }`; sort by `[-value, label.downcase]`; first 5.
  - `top_customer_previous_values` / `top_customer_trend_values`: previous-range grouped values / per-date trend arrays keyed by customer.
  - `build_top_customer_item(entry:, rank:, metric:, previous_value:, trend_values:)` → `{ rank:, label:, value:, display_value: top_customer_display_value(value, metric:), change_label: top_customer_change_label(cur,prev), direction: top_customer_direction(cur,prev), trend_values: Array(trend_values) }`.
  - `top_customer_display_value`: revenue→currency; else `"#{number} visit"`/`"visits"` (singular iff count==1).
  - `top_customer_change_label`: `"New"` if change_pct nil and current positive; `"0%"` if change_pct==0; else `"#{'+' if positive}#{display_percentage}%"`.
  - `top_customer_direction`: `"neutral"` if prev zero; else `metric_direction`.
  - `customer_chart_label(customer)`: `name = customer.name.squish.truncate(18)`; `phone_suffix = phone_number.last(4)`; if suffix blank→name; if name blank→full phone_number; else `"#{name} - #{phone_suffix}"`.
- `transactions_by_hour_payload`: group `EXTRACT(HOUR FROM transactions.created_at)` count; labels `"%02d:00"` for 0..23; values `grouped.fetch(hour.to_d, 0)`. (Keys are BigDecimal — must fetch with `.to_d`.)
- `transactions_by_day_payload`: group `EXTRACT(DOW FROM transactions.created_at)` count; labels = `WEEKDAY_ORDER.values` (Mon..Sun); values `grouped.fetch(dow.to_d, 0)` for `WEEKDAY_ORDER.keys`.
- `values_for_daily_series(grouped_values)`: rekey by `to_date`; for each date in range fetch (default 0); BigDecimal→`.to_f.round(2)` else raw.

**`rewards_summary` → Hash:**
```
{ redemption_rate: issued.zero? ? 0.0 : ((redeemed.to_f/issued)*100).round(1),
  issued_points: <int>, redeemed_points: <int>,
  note: "Redemptions are tracked in #{PointsRedeemer.redemption_increment}-point slabs. Legacy non-standard entries are grouped under Other." }
```

**`top_rewards_payload`**: redeem entries grouped by `points`, counted, bucketed via `redemption_bucket_for`, summed per bucket, sorted by `redemption_bucket_sort`, first 5. `{ labels: [redemption_bucket_label per bucket], values: [counts] }`.
- `redemption_bucket_for(points)`: `abs = points.to_i.abs`; `LEGACY_REDEMPTION_BUCKET` if zero; return `abs` if `abs % PointsRedeemer.redemption_increment == 0`; else `LEGACY_REDEMPTION_BUCKET`.
- `redemption_bucket_label(bucket)`: `"Other / Legacy"` if legacy; else `"#{bucket} pts"`.
- `redemption_bucket_sort(bucket, count)`: legacy → `[1, -count, Float::INFINITY]`; else `[0, -count, bucket]` (real slabs first, by descending count then slab size).

**`chart_comparison_payload(current, previous)`**: `nil` if both zero. If `change_pct` nil → `{ change_pct: nil, direction: "neutral", label: "New baseline" }`; else `{ change_pct:, direction: metric_direction, label: "#{'+' if positive}#{display_percentage}% vs previous #{period_length}-day period" }`.
- `display_percentage(value)` = `number_with_precision(value, precision:1, strip_insignificant_zeros:true)`.
- `previous_period_label` = `"#{period_length}-day period"`.

**Model contracts:** `FuelType.for_settings` (records with `code`,`name`), `FuelType.label_for(code)`. `Transaction`: `created_at`, `fuel_amount`, `customer_id`, assoc `vehicle` (col `fuel_type`). `PointsLedger`: `created_at`, `entry_type` enum (`:earn`,`:redeem`), `points`, `customer_id`, assoc `fuel_transaction`→`vehicle`. `Customer`: `id`, `created_at`, `name`, `phone_number`. `PointsRedeemer.redemption_increment` (integer slab size).

---

### `Cdn::Purger`
File: `app/services/cdn/purger.rb`
Purpose: purges specific public URLs from Cloudflare's cache via the zone `purge_cache` API.

**Constants**
- `PUBLIC_CACHE_PATHS = ["/loyalty", "/loyalty?source=pwa", "/manifest.json"]` — default paths purged.

**Entry point** — `Cdn::Purger.call(paths: PUBLIC_CACHE_PATHS)` (→ `new(paths:).call`).
**Constructor** — `new(paths:, public_base_url: ENV["PUBLIC_BASE_URL"], zone_id: ENV["CLOUDFLARE_ZONE_ID"], api_token: ENV["CLOUDFLARE_API_TOKEN"], logger: Rails.logger)`. `@paths = Array(paths)`.

**`call` → Symbol** — returns one of `:skipped`, `:ok`, `:failed`:
1. `:skipped` unless `configured?` (`public_base_url`, `zone_id`, `api_token` all present).
2. `:skipped` if `files.empty?`.
3. `response = perform_request`; `:ok` if `successful_response?`; else log `warn "Cloudflare purge failed (#{response.code}): #{response.body}"` and return `:failed`.
4. `rescue StandardError => error`: log `warn "Cloudflare purge error: #{error.class}: #{error.message}"`; return `:failed`.

**`files` (private, memoized)** — for each path: strip; skip if empty; prepend `/` if not present; build `"#{public_base_url.sub(%r{/*\z}, "")}#{normalized_path}"` (strips trailing slashes from base); `.uniq`. Absolute URLs.

**`perform_request` (private)** — HTTP call:
- URL: `https://api.cloudflare.com/client/v4/zones/#{zone_id}/purge_cache` (POST).
- Headers: `Authorization: "Bearer #{api_token}"`, `Content-Type: "application/json"`.
- Body: `JSON.generate(files: files)`.
- `Net::HTTP.start(host, port, use_ssl: true, open_timeout: 5, read_timeout: 10)`.

**`successful_response?(response)` (private)** — `false` unless `response.code.to_i` in 200..299; then `JSON.parse(response.body)["success"] == true`; `rescue JSON::ParserError → false`.