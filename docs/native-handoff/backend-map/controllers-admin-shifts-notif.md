## controllers:admin-shifts-notif

Replication-grade reference for admin shift-management and push-notification controllers + shared concerns. Scope = the 11 listed files only. Routes/verbs marked *(inferred from Rails REST + custom member/collection actions; not read from routes.rb)*. Models/services/policies referenced but NOT in the read set are annotated `[external]`.

---

### Two controller base stacks (load-bearing distinction)

- **`Admin::BaseController`** `[external]` — parent of ShiftTemplates, ShiftCycles, ShiftAssignments, AttendanceRuns, Notifications. Provides `current_user`, Pundit `authorize`, session auth, HTML flash, `block_unsupported_browser` before_action (default CSRF ON). Every action in these controllers calls Pundit `authorize` explicitly.
- **`ApplicationController` + `AdminApiAuthenticatable`** — parent of Schedules, NotificationDeliveries. Token/session dual auth, CSRF disabled (`null_session`), JSON-first. These controllers do NOT call Pundit `authorize`.

---

## Concern: `AdminApiAuthenticatable`

`extend ActiveSupport::Concern`. `included do` block runs:
1. `skip_before_action :block_unsupported_browser`
2. `protect_from_forgery with: :null_session` (CSRF token absence → empty session instead of raising; API-safe)
3. `before_action :authenticate_admin_request!`

**`authenticate_admin_request!`** — passes (returns, no render) if EITHER:
- `current_user&.admin?` is truthy (session-authenticated admin), OR
- `valid_bearer_token?` is true.

Otherwise renders 401 `:unauthorized` by format:
- `format.json` → `render json: { error: "Unauthorized" }, status: :unauthorized`
- `format.html` → `head :unauthorized`
- `format.any` → `head :unauthorized`

**`valid_bearer_token?`** — `expected = ENV["ADMIN_NOTIFICATION_API_TOKEN"]`, `provided = bearer_token`. Returns false if either blank. Compares `ActiveSupport::SecurityUtils.secure_compare(SHA256(provided), SHA256(expected))` (constant-time, SHA256-hashed to equalize length).

**`bearer_token`** — extracts group 1 from `request.authorization` matching regex `/\ABearer (.+)\z/i` (case-insensitive scheme). nil if no match.

API-layer note: `/api/v1` must accept `Authorization: Bearer <token>` where token equals `ENV["ADMIN_NOTIFICATION_API_TOKEN"]`, OR a logged-in admin session.

---

## Concern: `AdminNotificationsPageState`

`extend ActiveSupport::Concern`. Private method only.

**`load_notifications_page_state(schedule: NotificationSchedule.new, edit_schedule: nil)`** sets ivars:
- `@schedule` = `schedule`
- `@edit_schedule` = `edit_schedule`
- `@notification_schedules` = `NotificationSchedule.recent_first` `[external scope]`
- `@push_subscription_count` = `PushSubscription.active.count` `[external]`
- `@push_subscription_total_count` = `PushSubscription.count`
- `@push_subscription_platforms` = `PushSubscription.active.group(:platform).count.sort.to_h` (Hash platform→count, sorted by key)

---

## Concern: `CustomerPointsLedgerRendering`

Constants: `POINTS_LEDGER_PREVIEW_LIMIT = 3`, `POINTS_LEDGER_PER_PAGE = 5`.

**`render_points_ledger_for(customer)`** (private, renders HTML partial — API layer must replicate pagination math to return JSON):
1. `total_entries = customer.points_ledgers.count`
2. `total_pages = total_entries.zero? ? 1 : (total_entries.to_f / 5).ceil`
3. `current_page = params[:page].to_i`; clamp `< 1 → 1`; `> total_pages → total_pages`
4. `points_ledger_entries = customer.points_ledgers.order(created_at: :desc).offset((current_page - 1) * 5).limit(5)`
5. Renders partial `"customers/points_ledger"` with locals `customer, points_ledger_entries, current_page, total_pages, total_entries`.

Note: `PREVIEW_LIMIT = 3` is defined but NOT used in this method (preview handled elsewhere). Ledger is NOT preview-offset (unlike transactions below).

---

## Concern: `CustomerTransactionHistoryRendering`

Constants: `TRANSACTION_PREVIEW_LIMIT = 3`, `TRANSACTION_HISTORY_PER_PAGE = 5`.

**`render_transaction_history_for(customer)`** (private, HTML partial):
1. `total_remaining_entries = [customer.transactions.count - 3, 0].max` (excludes the first 3 preview rows)
2. `total_pages = total_remaining_entries.zero? ? 1 : (total_remaining_entries.to_f / 5).ceil`
3. `current_page = params[:page].to_i`; clamp `<1→1`, `>total_pages→total_pages`
4. `transaction_history_entries = customer.transactions.includes(:points_ledger, :fuel_pump, :vehicle, :user, fuel_pump_nozzle: [:fuel_pump, :fuel_type_record]).order(created_at: :desc).offset(3 + ((current_page - 1) * 5)).limit(5)` — **offset starts at 3** to skip preview rows.
5. Renders partial `"customers/transaction_history"` with locals `customer, transaction_history_entries, current_page, total_pages, total_remaining_entries`.

---

## Controller: `Admin::ShiftTemplatesController < BaseController`

Every action: `authorize <target>` (Pundit `ShiftTemplatePolicy` `[external]`). HTML-only.

### `index` — GET `/admin/shift_templates` *(inferred)*
- `authorize ShiftTemplate`
- Calls `load_index_state`. Renders `:index`. 200.

### `create` — POST `/admin/shift_templates` *(inferred)*
- `@shift_template = ShiftTemplate.new`; `authorize @shift_template`; `assign_attributes(shift_template_params)`
- Success (`save`): `redirect_to admin_shift_templates_path, notice: "Shift template created successfully."` (302)
- Failure: `load_index_state(new_shift_template: @shift_template)`; `render :index, status: :unprocessable_entity` (422)

### `update` — PATCH/PUT `/admin/shift_templates/:id` *(inferred)*
- `@shift_template = ShiftTemplate.find(params[:id])` (404 on miss); `authorize @shift_template`
- Success (`update(shift_template_params)`): `redirect_to admin_shift_templates_path, notice: "Shift template updated successfully."` (302)
- Failure: `load_index_state(edit_shift_template: @shift_template)`; `render :index, status: :unprocessable_entity` (422)

**`load_index_state(new_shift_template: ShiftTemplate.new(active: true), edit_shift_template: nil)`**:
- `@shift_templates = ShiftTemplate.order(:name, :duration_minutes)`
- `@shift_template = new_shift_template` (default new record has `active: true`)
- `@edit_shift_template = edit_shift_template`

**Strong params `shift_template_params`**: `params.require(:shift_template).permit(:name, :start_time, :duration_hours, :duration_minutes, :active)`
- Note: `duration_hours` + `duration_minutes` both permitted — model `[external]` combines into total `duration_minutes` (a virtual-attribute pattern; `@shift_templates` orders by real `duration_minutes` column).

---

## Controller: `Admin::ShiftCyclesController < BaseController`

Constant `MAX_STEP_SLOTS = 12`. HTML-only. Every action authorizes.

### `index` — GET `/admin/shift_cycles`
- `authorize ShiftCycle`; `load_index_state`; render. 200.

### `create` — POST `/admin/shift_cycles`
- `@shift_cycle = ShiftCycle.new`; `authorize @shift_cycle`
- `save_shift_cycle(@shift_cycle, step_template_ids)`:
  - Success → `redirect_to admin_shift_cycles_path, notice: "Shift cycle created successfully."` (302)
  - Failure → `load_index_state(new_shift_cycle: @shift_cycle, new_step_template_ids: step_template_ids)`; `render :index, status: :unprocessable_entity` (422)

### `update` — PATCH/PUT `/admin/shift_cycles/:id`
- `@shift_cycle = ShiftCycle.find(params[:id])`; `authorize @shift_cycle`
- `save_shift_cycle(...)`:
  - Success → `redirect_to admin_shift_cycles_path, notice: "Shift cycle updated successfully."` (302)
  - Failure → `load_index_state(edit_shift_cycle: @shift_cycle, edit_step_template_ids: step_template_ids)`; `render :index, 422`

### `destroy` — DELETE `/admin/shift_cycles/:id`
- `authorize @shift_cycle`
- If `@shift_cycle.deletable?` `[external]` → `destroy!`; `redirect_to admin_shift_cycles_path, notice: "Shift cycle deleted successfully."` (302)
- Else → `redirect_to admin_shift_cycles_path, alert: "This shift cycle already has staff assignment history. Deactivate it instead of deleting it."` (302)

### `activate` — member route *(inferred POST/PATCH `/admin/shift_cycles/:id/activate`)*
- Delegates to `update_active_state!(true, "Shift cycle activated successfully.")`

### `deactivate` — member route *(inferred `/admin/shift_cycles/:id/deactivate`)*
- `update_active_state!(false, "Shift cycle deactivated successfully.")`

**`update_active_state!(active, notice_message)`**: `find(params[:id])`; `authorize @shift_cycle, :update?` (uses `update?` policy method); `update!(active: active)`; `redirect_to admin_shift_cycles_path, notice: notice_message`.

**`load_index_state(new_shift_cycle: ShiftCycle.new(active: true, starts_on: Date.current), edit_shift_cycle: nil, new_step_template_ids: nil, edit_step_template_ids: nil)`**:
- `@shift_templates = ShiftTemplate.active.order(:name, :start_time, :duration_minutes)`
- `@shift_cycles = ShiftCycle.includes(:shift_assignments, shift_cycle_steps: :shift_template).order(:name, :starts_on)`
- `@shift_cycle`, `@edit_shift_cycle`
- `@new_shift_cycle_step_ids = padded_step_ids(new_step_template_ids)`
- `@edit_shift_cycle_step_ids = padded_step_ids(edit_step_template_ids || edit_shift_cycle&.shift_cycle_steps&.map(&:shift_template_id))`
- New-cycle default: `active: true, starts_on: Date.current`.

**`save_shift_cycle(shift_cycle, selected_step_ids)`** (core algorithm):
1. `shift_cycle.assign_attributes(shift_cycle_params)`
2. If `selected_step_ids.empty?` → `shift_cycle.errors.add(:base, "Choose at least one shift in the cycle.")`; `return false`
3. `ShiftCycle.transaction do`:
   - `shift_cycle.shift_cycle_steps.destroy_all`
   - For each `shift_template_id` with `index`: `shift_cycle.shift_cycle_steps.build(shift_template_id:, position: index + 1)` (position 1-based)
   - `shift_cycle.save!`
4. `true`
5. `rescue ActiveRecord::RecordInvalid → false`

**`shift_cycle_params`**: `params.require(:shift_cycle).permit(:name, :starts_on, :active)`

**`step_template_ids`**: `Array(params.dig(:shift_cycle, :step_shift_template_ids)).map(&:presence).compact` (drops blanks; source key is `shift_cycle[step_shift_template_ids][]`).

**`padded_step_ids(ids)`**: `Array(ids).map(&:presence).compact.first(12)`, then right-pad with `nil` up to length 12. Always returns exactly 12-element array (for fixed-slot UI).

---

## Controller: `Admin::ShiftAssignmentsController < BaseController`

Single action `create`. HTML-only. Nested under staff member (`params[:staff_member_id]`) *(inferred POST `/admin/staff_members/:staff_member_id/shift_assignments`)*.

### `create`
1. `@staff_member = User.kept.where(role: :staff).find(params[:staff_member_id])` — `kept` = Discard gem not-discarded; role filter `:staff`; 404 if absent. (`role` is an enum `[external]`.)
2. `@shift_assignment = @staff_member.shift_assignments.build(notes: shift_assignment_params[:notes], active: true)`
3. `@shift_assignment.shift_template = ShiftTemplate.find_by(id: shift_assignment_params[:shift_template_id])` (nil-tolerant, not `find`)
4. `@shift_assignment.effective_from = Time.zone.now.change(sec: 0)` (current time truncated to minute)
5. `@shift_assignment.shift_cycle = @shift_assignment.shift_template&.current_shift_cycle(at: @shift_assignment.effective_from)` `[external method]`
6. `authorize @shift_assignment` (`ShiftAssignmentPolicy` `[external]`)
7. `validate_shift_assignment!` (may raise `ActiveRecord::RecordInvalid`)
8. `ShiftAssignment.transaction do`: `close_current_assignments!`; `@shift_assignment.save!`
9. Success → `redirect_to admin_staff_members_path, notice: "Shift assigned successfully."` (302)

**Rescue `ActiveRecord::RecordInvalid`** (rebuilds staff index page, 422 `render "admin/staff_members/index"`):
- `@staff_members = User.kept.where(role: :staff).includes(shift_assignments: [{ shift_template: { shift_cycles: { shift_cycle_steps: :shift_template } } }, { shift_cycle: { shift_cycle_steps: :shift_template } }]).order(:name, :username, :phone_number)`
- `@edit_staff_member = nil`
- `@active_staff_count = @staff_members.count(&:active?)`
- `@inactive_staff_count = @staff_members.count { |sm| !sm.active? }`
- `@unassigned_staff_count = @staff_members.count { |sm| sm.current_shift_template.blank? }`
- `@shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)`
- `@assignment_form_user_id = @staff_member.id`

**`shift_assignment_params`**: `params.require(:shift_assignment).permit(:shift_template_id, :notes)`

**`validate_shift_assignment!`** (adds errors then raises if any):
- If `shift_template.blank?` → `errors.add(:shift_template, "must be selected")`
- If `shift_template.present? && effective_from.blank?` → `errors.add(:effective_from, "must be present")`
- `raise ActiveRecord::RecordInvalid, @shift_assignment if @shift_assignment.errors.any?`

**`close_current_assignments!`**: `effective_from = @shift_assignment.effective_from`; iterate `@staff_member.shift_assignments.active.effective_at(effective_from).find_each` `[external scopes]` → each `update!(effective_to: effective_from - 1.second)` (closes overlapping active assignments 1s before the new one starts).

---

## Controller: `Admin::AttendanceRunsController < BaseController`

Constant `ATTENDANCE_RUNS_PER_PAGE = 6`. HTML-only. `before_action :load_shift_templates, :load_active_staff_members, only: %i[new create]`. Every action authorizes.

### `index` — GET `/admin/attendance_runs`
- `authorize AttendanceRun`
- `@record_filter = normalized_record_filter`
- `@current_start_date, @current_end_date = normalized_date_range`
- `attendance_scope = filtered_by_date_range(filtered_attendance_scope(AttendanceRun.all)).order(starts_at: :desc, created_at: :desc)`
- `@total_attendance_runs = attendance_scope.count`
- `@total_pages = @total_attendance_runs.zero? ? 1 : (count.to_f / 6).ceil`
- `@current_page = normalized_page(@total_pages)`
- `@attendance_runs = attendance_scope.includes(:shift_template, :recorded_by, attendance_entries: %i[scheduled_user actual_user replacement_user]).offset((@current_page-1)*6).limit(6)`
- `@showing_from = total.zero? ? 0 : ((@current_page-1)*6)+1`
- `@showing_to = total.zero? ? 0 : @showing_from + @attendance_runs.size - 1`

### `new` — GET `/admin/attendance_runs/new`
- `@attendance_run = AttendanceRun.new`; `authorize`; `apply_planning_state`

### `create` — POST `/admin/attendance_runs`
- `@attendance_run = AttendanceRun.new(attendance_run_params)`; `authorize`
- `@attendance_run.recorded_by = current_user`
- `attach_cycle_window_error(@attendance_run)` (may add base error)
- If `errors.none? && save` → `redirect_to admin_attendance_run_path(@attendance_run), notice: "Attendance recorded successfully."` (302)
- Else → set `@selected_shift_template = @attendance_run.shift_template`, `@planning_starts_at = starts_at`, `@planning_ends_at = ends_at`; `render :new, status: :unprocessable_entity` (422)

### `show` — GET `/admin/attendance_runs/:id`
- `@attendance_run = AttendanceRun.includes(:shift_template, attendance_entries: %i[scheduled_user actual_user replacement_user]).find(params[:id])`; `authorize`
- `@status_counts = AttendanceEntry.statuses.keys.index_with { |status| @attendance_run.status_counts.fetch(status, 0) }` — full status-key hash, 0-filled. `AttendanceEntry.statuses` = enum `[external]`; `@attendance_run.status_counts` `[external]` returns partial hash.

### `invalidate` — member route *(inferred PATCH `/admin/attendance_runs/:id/invalidate`)*
- `find`; `authorize`
- If `stale?` → `alert: "Attendance record is already marked invalid."` (302)
- Elsif `update(stale: true)` → `notice: "Attendance record marked invalid."` (302)
- Else → `alert: "Unable to mark this attendance record invalid."` (302)
- All redirect to `admin_attendance_run_path(@attendance_run)`.

### `mark_valid` — member route *(inferred PATCH `/admin/attendance_runs/:id/mark_valid`)*
- `find`; `authorize`
- Unless `stale?` → `alert: "Attendance record is already marked valid."`; return (302)
- Unless `can_mark_valid?` `[external]` → `alert: "Another attendance record already exists for this shift and time window."`; return (302)
- If `update(stale: false)` → `notice: "Attendance record marked valid."` (302)
- Else → `alert: @attendance_run.errors.full_messages.to_sentence.presence || "Unable to mark this attendance record valid."` (302)

### `destroy` — DELETE `/admin/attendance_runs/:id`
- `find`; `authorize`
- Unless `stale?` → `alert: "Only invalid attendance records can be deleted."`; return (redirect to show, 302)
- `@attendance_run.destroy` (not `destroy!`)
- `redirect_back fallback_location: admin_attendance_runs_path(filter: :invalid), notice: "Invalid attendance record deleted."`

**before_action loaders (`new`, `create`)**:
- `load_shift_templates`: `@shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)`
- `load_active_staff_members`: `@active_staff_members = User.active.where(role: :staff).order(:name, :username, :phone_number)`

**`apply_planning_state`** (for `new`): sets `@selected_shift_template`, `@planning_starts_at = parsed_starts_at`, `@planning_ends_at = computed_ends_at`; then `return` early unless template present, unless `duplicate_window_valid?`, unless `cycle_window_valid?`; then `build_attendance_entries`.

**`build_attendance_entries`**: `AttendanceRosterBuilder.call(shift_template:, starts_at:)` `[external service]` → each `item` (`item.fetch(:staff_member)`): builds `attendance_entries.build(scheduled_user: sm, actual_user: sm, status: :present, check_in_at: @planning_starts_at, check_out_at: @planning_ends_at)`. Then sets `shift_template`, `starts_at = @planning_starts_at`, `ends_at = @planning_ends_at` on the run.

**`selected_shift_template`**: id from `params[:shift_template_id]` or `params[:attendance_run][:shift_template_id]`; blank → nil; else `ShiftTemplate.find_by(id:)`.

**`parsed_starts_at`**: raw from `params[:starts_at]` or `params[:attendance_run][:starts_at]`; blank → `default_planning_starts_at`; else `Time.zone.parse(raw)`; rescue `ArgumentError, TypeError` → `default_planning_starts_at`.

**`computed_ends_at`**: nil unless template present; else `@planning_starts_at + @selected_shift_template.duration_minutes.minutes`.

**`default_planning_starts_at`**: no template → `Time.zone.now.change(min: 0)`; else `Time.zone.parse("#{Time.zone.today} #{@selected_shift_template.start_time_input_value}")` `[external]`; rescue → `Time.zone.now.change(min: 0)`.

**`cycle_window_valid?`** → true if template/starts/ends missing; `linked_cycles = @selected_shift_template.shift_cycles.active.includes(:shift_cycle_steps)`; true if empty; true if any `shift_cycle.valid_window_for?(shift_template:, starts_at:, ends_at:)` `[external]`; else `errors.add(:base, "Selected start and end date time do not match this shift's repeating cycle. Choose the next cycle-aligned window.")`; false.

**`duplicate_window_valid?`** → true if missing pieces; true unless `AttendanceRun.valid_records.exists?(shift_template_id:, starts_at:, ends_at:)`; else `errors.add(:base, "Attendance has already been recorded for this shift and time window.")`; false.

**`attach_cycle_window_error(attendance_run)`** (for `create`): return unless template/starts/ends present; `linked_cycles = ...active.includes(:shift_cycle_steps)`; return if empty; return if any `valid_window_for?`; else `errors.add(:base, "Selected start and end date time do not match this shift's repeating cycle. Choose the next cycle-aligned window.")` (same string as cycle_window_valid?).

**`attendance_run_params`**: `params.require(:attendance_run).permit(:shift_template_id, :starts_at, :ends_at, :stale, :notes, attendance_entries_attributes: [:scheduled_user_id, :actual_user_id, :replacement_user_id, :external_replacement_name, :status, :check_in_at, :check_out_at, :notes])`
- Nested `attendance_entries_attributes` (has_many, `accepts_nested_attributes_for` `[external]`). Note: no `id` or `_destroy` permitted → create-only nesting.

**`normalized_record_filter`**: legacy map `{"fresh"=>"valid","stale"=>"invalid"}`; `filter_value = legacy.fetch(params[:filter], params[:filter])`; then `.presence_in(%w[all valid invalid]) || "all"`.

**`filtered_attendance_scope(scope)`**: `"invalid"→scope.invalid_records`; `"valid"→scope.valid_records`; else `scope`. `[external scopes valid_records/invalid_records]`

**`filtered_by_date_range(scope)`**: if `@current_start_date` present → `where("starts_at >= ?", start.beginning_of_day)`; if `@current_end_date` present → `where("starts_at <= ?", end.end_of_day)`.

**`normalized_date_range`**: `start = clamp_to_today(parse_date(params[:start_date]))`, `end = clamp_to_today(parse_date(params[:end_date]))`; if both present and `start > end` → swap `[end, start]`; else `[start, end]`.

**`clamp_to_today(date)`**: nil if blank; else `[date, Time.zone.today].min` (caps at today).

**`normalized_page(total_pages)`**: `page = params[:page].to_i`; `<1→1`; `>total_pages→total_pages`.

**`parse_date(value)`**: blank→nil; `Date.iso8601(value.to_s)`; rescue `ArgumentError`→nil.

---

## Controller: `Admin::SchedulesController < ApplicationController`

`include AdminApiAuthenticatable` (token/session auth, CSRF null_session), `include AdminNotificationsPageState`. **No Pundit authorize.** Dual JSON/HTML via `respond_to`.

### `index` — GET `/admin/schedules`
- `schedules = NotificationSchedule.recent_first`
- JSON → `render json: schedules.map { serialize_schedule(s) }` (200, array)
- HTML → `redirect_to admin_notifications_path`

### `create` — POST `/admin/schedules`
- `@schedule = NotificationSchedule.new(schedule_params)`
- Success (`save`):
  - JSON → `render json: serialize_schedule(@schedule), status: :created` (201)
  - HTML → `redirect_to admin_notifications_path, notice: "Schedule created successfully."`
- Failure → `respond_with_schedule_errors(schedule: @schedule, status: :unprocessable_entity)`

### `update` — PATCH/PUT `/admin/schedules/:id`
- `@schedule = NotificationSchedule.find(params[:id])`
- Success (`update`):
  - JSON → `render json: serialize_schedule(@schedule), status: :ok` (200)
  - HTML → `redirect_to admin_notifications_path, notice: "Schedule updated successfully."`
- Failure → `respond_with_schedule_errors(schedule: @schedule, edit: true, status: :unprocessable_entity)`

### `destroy` — DELETE `/admin/schedules/:id`
- `find`; `destroy!`
- JSON → `head :no_content` (204)
- HTML → `redirect_to admin_notifications_path, notice: "Schedule deleted successfully."`

### `run` — collection route *(inferred POST `/admin/schedules/run`)*
- `result = NotificationScheduleRunner.new.run(current_time: Time.current)` `[external service]`
- JSON → `render json: result.as_json, status: :ok` (200) — shape = `result.as_json` (service-defined; includes at least `skipped, sent, failed, due, message, details`)
- HTML → `redirect_to admin_notifications_path, **scheduler_run_flash_for(result)`

### `send_now` — member route *(inferred POST `/admin/schedules/:id/send_now`)*
- `schedule = NotificationSchedule.find(params[:id])`
- `result = FirebasePushService.new.broadcast(title: schedule.title, message: schedule.message)` `[external service]`
- `schedule.update!(last_sent_at: Time.current) if result.sent.to_i.positive?`
- JSON → `render json: { schedule: serialize_schedule(schedule), delivery: result.as_json }, status: :ok` (200)
- HTML → `redirect_to admin_notifications_path, **schedule_send_now_flash_for(schedule, result)`
- `rescue FirebaseAppConfig::ConfigurationError => error` → `respond_with_broadcast_error(message: error.message, status: :unprocessable_entity)`

**`schedule_params`**: `params.fetch(:notification_schedule, params).permit(:title, :message, :frequency, :scheduled_time, :scheduled_date, :day_of_week, :day_of_month, :active)` — accepts params either nested under `notification_schedule` OR top-level (API-friendly fallback).

**`serialize_schedule(schedule)`** → exact JSON key set:
```
{ "id", "title", "message", "frequency", "scheduled_time", "scheduled_date",
  "day_of_week", "day_of_month", "last_sent_at", "active",
  "schedule_summary" => schedule.schedule_summary }
```
(First 10 keys via `schedule.slice(...)`; `schedule_summary` `[external method]` merged in.)

**`respond_with_schedule_errors(schedule:, edit: false, status:)`**:
- JSON → `render json: { errors: schedule.errors.full_messages }, status:`
- HTML → `load_notifications_page_state(schedule: edit ? NotificationSchedule.new : schedule, edit_schedule: edit ? schedule : nil)`; `flash.now[:alert] = schedule.errors.full_messages.to_sentence`; `render "admin/notifications/show", status:`

**`scheduler_run_flash_for(result)`** (HTML flash logic for `run`):
- `result.skipped` truthy → `{ alert: result.message }`
- `result.due.to_i.zero?` → `{ alert: "No schedules are due right now. Schedules run only after their scheduled IST time. Use Send Now to broadcast immediately." }`
- Else `flash_key = result.failed.to_i.positive? ? :alert : :notice`; `{ flash_key => scheduler_run_notice_for(result) }`

**`scheduler_run_notice_for(result)`**:
- `result.skipped` → `result.message`
- Else base = `"Scheduler run finished. #{result.sent} schedules sent, #{result.failed} failed."`; `first_error = Array(result.details).filter_map { |d| d[:error] || d["error"] }.first`; blank → base; else `"#{base} #{first_error}"`

**`schedule_send_now_flash_for(schedule, result)`**: `flash_key = result.requested.to_i.zero? || result.failed.to_i.positive? ? :alert : :notice`; `{ flash_key => schedule_send_now_notice_for(schedule, result) }`

**`schedule_send_now_notice_for(schedule, result)`**:
- `result.requested.to_i.zero?` → `"No active device tokens are registered, so \"#{schedule.title}\" was not sent."`
- Else base = `"Sent \"#{schedule.title}\" now. #{result.sent} deliveries succeeded, #{result.failed} failed."`; `first_error = Array(result.errors).filter_map { |e| e[:error] || e["error"] }.first`; blank → base; else `"#{base} #{first_error}"`

**`respond_with_broadcast_error(message:, status:)`**: JSON → `render json: { error: message }, status:`; HTML → `redirect_to admin_notifications_path, alert: message`.

**Service result contracts used** `[external]`: `result.as_json`, `.skipped`, `.message`, `.sent`, `.failed`, `.due`, `.requested`, `.details` (array of hashes with `:error`/`"error"`), `.errors` (array of hashes with `:error`/`"error"`).

---

## Controller: `Admin::NotificationsController < BaseController`

`include AdminNotificationsPageState`. HTML page (session-auth admin via BaseController; no explicit authorize call).

### `show` — GET `/admin/notifications` *(inferred)*
- `load_notifications_page_state` (sets all page ivars listed under the concern). Renders `admin/notifications/show`. 200.

---

## Controller: `Admin::NotificationDeliveriesController < ApplicationController`

`include AdminApiAuthenticatable` (token/session, CSRF null_session). **No Pundit authorize.** Single action.

### `create` — POST `/admin/notification_deliveries`
- `result = FirebasePushService.new.broadcast(**delivery_params.to_h.symbolize_keys)` — passes `{ title:, message: }`.
- JSON → `render json: result.as_json, status: :ok` (200)
- HTML → `redirect_to admin_notifications_path, notice: "Notification sent. #{result.sent} deliveries succeeded, #{result.failed} failed."`
- `rescue FirebaseAppConfig::ConfigurationError => error` → `respond_with_error(error.message, status: :unprocessable_entity)`
- `rescue ActionController::ParameterMissing => error` → `respond_with_error(error.message, status: :unprocessable_entity)`

**`delivery_params`**: `notification_params = params.fetch(:notification, params).permit(:title, :message)`; then `notification_params.require(:title)`; `notification_params.require(:message)`; returns `notification_params`. Accepts nested under `notification` OR top-level. Missing `title` or `message` → `ActionController::ParameterMissing` → 422 with the exception's message as `error`.

**`respond_with_error(message, status:)`**: JSON → `render json: { error: message }, status:`; HTML → `redirect_to admin_notifications_path, alert: message`.

---

## POLICIES (referenced, `[external]` — not in read set)

Pundit `authorize` targets and the exact policy methods invoked (rule text unknown without policy files):
- `ShiftTemplatePolicy` — `index?`, `create?`, `update?`
- `ShiftCyclePolicy` — `index?`, `create?`, `update?` (`destroy` authorizes instance then relies on `deletable?`; `activate`/`deactivate` explicitly call `:update?`)
- `ShiftAssignmentPolicy` — inferred `create?`
- `AttendanceRunPolicy` — `index?`, `new?`, `create?`, `show?`, and member actions `invalidate`/`mark_valid`/`destroy` (each calls `authorize @attendance_run`, i.e. `<action>?`)
- Schedules / NotificationDeliveries / Notifications#show — **no Pundit**; access gated by `AdminApiAuthenticatable` (admin session or bearer token) for Schedules/NotificationDeliveries, and by `BaseController` session auth for Notifications.

---

## Cross-cutting notes for the `/api/v1` layer

- **Auth split**: Notification/Schedule endpoints already support bearer-token auth (`AdminApiAuthenticatable`) and return JSON. Shift/attendance controllers are HTML+session+Pundit only — an API layer must add JSON responses and token auth for those, and preserve the exact Pundit rules.
- **Error message strings** are user-facing and load-bearing — reproduce verbatim (validation errors surface via `errors.full_messages` / `.to_sentence`).
- **Status codes**: success create = 201 (schedules JSON) or 302 (HTML); validation failure = 422; auth failure = 401; delete = 204 (schedules JSON) / 302 (HTML); `not found` via bare `find` = 404.
- **Pagination constants**: attendance=6/page, points ledger=5/page (offset 0), transaction history=5/page (offset +3 preview).
- **`shift_cycle` step ordering**: `position` is 1-based, rebuilt destructively on every save inside a transaction.
- **`shift_assignment` time semantics**: `effective_from` = now truncated to minute; prior active assignments closed at `effective_from - 1.second`.