## Subsystem: controllers:admin-crm

Rails admin namespace, HTML-first (Turbo/partials), Pundit-authorized. All controllers inherit `Admin::BaseController`. No JSON except `DashboardController#data`. CSRF: standard Rails (no exemptions/token auth observed).

---

### Admin::BaseController (`app/controllers/admin/base_controller.rb`)
Superclass of all below; extends `ApplicationController`.
- `before_action :authenticate_user!` (Devise) — unauthenticated → Devise redirect to sign-in.
- `before_action :ensure_admin!` (private): `raise Pundit::NotAuthorizedError, "not allowed" unless current_user&.admin?`. Non-admin (incl. nil) → `Pundit::NotAuthorizedError` (typically 302 + flash by app-level rescue, or 403).
- Order: authenticate first, then admin gate. **Every action in this subsystem requires an authenticated admin.**

---

### Admin::DashboardController (`app/controllers/admin/dashboard_controller.rb`)
No strong params; reads query params directly. Delegates to service `Admin::Dashboard::OverviewReport`.

**Memoized builder** `dashboard_report` (private): `Admin::Dashboard::OverviewReport.new(start_date: params[:start_date], end_date: params[:end_date], segment: params[:segment], preset: params[:preset], fuel_type: params[:fuel_type])`.

| Action | HTTP+Path | authorize | Response |
|---|---|---|---|
| `show` | GET `/admin/dashboard` | `authorize :dashboard, :show?` (symbol policy → `DashboardPolicy#show?`) | HTML. Sets `@dashboard_filters = report.filters`, `@dashboard_payload = report.as_json`. Renders `show` view. |
| `data` | GET `/admin/dashboard/data` | `authorize :dashboard, :show?` | **JSON**: `render json: dashboard_report.as_json` (200). Exact key shape defined by `OverviewReport#as_json` — not in these files. |

No flash strings. No mutation.

---

### Admin::CustomersController (`app/controllers/admin/customers_controller.rb`)
Includes `CustomerPointsLedgerRendering`, `CustomerTransactionHistoryRendering`. Pundit `authorize` on `Customer` class or instance → `CustomerPolicy`.

**Strong params** `customer_params`: `params.require(:customer).permit(:name, :phone_number, :vehicle_number, :fuel_type, :vehicle_kind, :commercial_company_name, :commercial_contact_name, :commercial_contact_phone_number, :commercial_address, :commercial_notes)`. (Flat — vehicle fields are peers, NOT nested attributes; controller manually routes them to a `Vehicle`.)

| Action | HTTP+Path | authorize | Notes |
|---|---|---|---|
| `index` | GET `/admin/customers` | `authorize Customer` (`index?`) | `load_index_state`. HTML. |
| `new` | GET `/admin/customers/new` | `authorize @customer` (`new?`) on `Customer.new` | HTML. |
| `create` | POST `/admin/customers` | `authorize @customer` (`create?`) | see below |
| `show` | GET `/admin/customers/:id` | `authorize @customer` (`show?`) | renders `"customers/show"` |
| `edit` | GET `/admin/customers/:id/edit` | `authorize @customer` (`edit?`) | HTML |
| `update` | PATCH/PUT `/admin/customers/:id` | `authorize @customer` (`update?`) | see below |
| `points_ledger` | GET `/admin/customers/:id/points_ledger` (member) | `authorize @customer` | renders partial (see concern) |
| `transaction_history` | GET `/admin/customers/:id/transaction_history` (member) | `authorize @customer` | renders partial (see concern) |
| `destroy` | DELETE `/admin/customers/:id` | `authorize @customer` (`destroy?`) | see below |

**create** algorithm:
1. `normalized_phone = Customer.normalize_phone_number(customer_params[:phone_number])`.
2. `@customer = Customer.new(phone_number: normalized_phone)`; `authorize @customer`.
3. `@customer.name = customer_params[:name] if customer_params[:name].present?`.
4. `persist_customer_with_vehicle` (transaction):
   - `initial_vehicle_fields_present?` first calls `@customer.valid?` (populates errors), then for each of `vehicle_number`, `fuel_type`, `vehicle_kind`: if blank, `@customer.errors.add(field, "can't be blank")`. Returns true only if `@customer.errors.none?`. If false → whole persist returns false.
   - Inside `Customer.transaction`: `raise ActiveRecord::Rollback unless @customer.save && save_vehicle`; else `success = true`.
   - `save_vehicle`: `@customer.vehicles.find_or_initialize_by(vehicle_number: Vehicle.normalize_vehicle_number(customer_params[:vehicle_number]))`. If already persisted → returns vehicle (truthy, no changes). Else assigns `fuel_type, vehicle_kind, commercial_company_name, commercial_contact_name, commercial_contact_phone_number, commercial_address, commercial_notes` from `customer_params`, then `vehicle.save`; on failure copies each `vehicle.errors` onto `@customer.errors` (attribute+message).
5. Success → `redirect_to admin_customer_path(@customer), notice: "Customer created successfully."` (302).
6. Failure → `load_index_state(form_customer: @customer)`; `render :index, status: :unprocessable_entity` (422).

**update** algorithm:
1. Load `@customer` with `includes(:vehicles, transactions: %i[user vehicle])`.
2. `authorize @customer`.
3. `@customer.assign_attributes(customer_params.slice(:name, :phone_number))` — only name+phone editable here.
4. `@customer.phone_number = Customer.normalize_phone_number(customer_params[:phone_number])` (overwrites with normalized).
5. `@customer.save` → success `redirect_to admin_customer_path(@customer), notice: "Customer updated successfully."` (302).
6. Failure → `prepare_show_state(open_edit_modal: true)`; `render "customers/show", status: :unprocessable_entity` (422). (`prepare_show_state` sets `@vehicle = Vehicle.new`, `@customer_update_path = admin_customer_path(@customer)`, `@customer_edit_modal_open = open_edit_modal`.)

**destroy** algorithm:
- `@customer.destroy!`. Success → `redirect_to admin_customers_path, notice: "Customer removed successfully."` (302).
- `rescue ActiveRecord::DeleteRestrictionError` → `redirect_to admin_customer_path(@customer), alert: "Customer cannot be removed because transaction history exists."` (302). (Restriction comes from `has_many :transactions, dependent: :restrict_with_error/exception` on Customer model.)

**index state / filtering** (`load_index_state`, `filtered_customers`, `normalized_status_filter`):
- `@query = params[:q].to_s.strip`; `@current_status = normalized_status_filter` (whitelist `%w[all active inactive]`, default `"all"`); `@customers = filtered_customers`; `@customer = form_customer` (default `Customer.new`).
- `filtered_customers` base scope: `Customer.left_joins(:vehicles).select("customers.*, COALESCE((SELECT SUM(points_ledgers.points) FROM points_ledgers WHERE points_ledgers.customer_id = customers.id), 0) AS total_points_sum").distinct`. **`total_points_sum` is a computed column the API would expose** = sum of all `points_ledgers.points` for the customer, 0 if none.
- Search (when `@query` present): builds OR conditions.
  - Always: `LOWER(customers.name) LIKE :name` with `name = "%#{sanitize_sql_like(query.downcase)}%"`.
  - If `Customer.normalize_phone_number(@query)` present: adds `customers.phone_number LIKE :phone` (`"%#{sanitize_sql_like(phone)}%"`).
  - If `Vehicle.normalize_vehicle_number(@query)` present: adds both `customers.vehicle_number LIKE :legacy_vehicle` AND `vehicles.vehicle_number LIKE :vehicle` (same value). Conditions joined with `" OR "`.
- Status filter: `active` → `where(active: true)`; `inactive` → `where(active: false)`; else no filter.
- Final: `.preload(:vehicles).order(created_at: :desc)`.

---

### CustomerPointsLedgerRendering concern (`app/controllers/concerns/customer_points_ledger_rendering.rb`)
Constants: `POINTS_LEDGER_PREVIEW_LIMIT = 3`, `POINTS_LEDGER_PER_PAGE = 5`.
`render_points_ledger_for(customer)`:
- `total_entries = customer.points_ledgers.count`.
- `total_pages = total_entries.zero? ? 1 : (total_entries.to_f / 5).ceil`.
- `current_page = params[:page].to_i`; clamp `<1 → 1`; `> total_pages → total_pages`.
- Entries: `customer.points_ledgers.order(created_at: :desc).offset((current_page-1)*5).limit(5)`.
- Renders partial `"customers/points_ledger"` with locals `{ customer, points_ledger_entries, current_page, total_pages, total_entries }`. **API equivalent JSON keys: entries + current_page, total_pages, total_entries; page size 5; ordered created_at desc; no preview offset (unlike transactions).**

### CustomerTransactionHistoryRendering concern (`app/controllers/concerns/customer_transaction_history_rendering.rb`)
Constants: `TRANSACTION_PREVIEW_LIMIT = 3`, `TRANSACTION_HISTORY_PER_PAGE = 5`.
`render_transaction_history_for(customer)`:
- `total_remaining_entries = [customer.transactions.count - 3, 0].max` (first 3 shown as preview elsewhere; this paginates the REMAINDER).
- `total_pages = total_remaining_entries.zero? ? 1 : (total_remaining_entries.to_f / 5).ceil`.
- `current_page` clamped as above.
- Entries: `customer.transactions.includes(:points_ledger, :fuel_pump, :vehicle, :user, fuel_pump_nozzle: %i[fuel_pump fuel_type_record]).order(created_at: :desc).offset(3 + (current_page-1)*5).limit(5)`. **Note the +3 preview offset — load-bearing: page 1 of history starts at record index 3.**
- Renders partial `"customers/transaction_history"` with locals `{ customer, transaction_history_entries, current_page, total_pages, total_remaining_entries }`.

---

### Admin::TransactionsController (`app/controllers/admin/transactions_controller.rb`)
Read-only; single action. Constants: `TRANSACTIONS_PER_PAGE = 10`; `SORT_OPTIONS = %w[time_desc time_asc amount_desc amount_asc]`; `RANGE_OPTIONS = %w[all today]`.

| Action | HTTP+Path | authorize | Response |
|---|---|---|---|
| `index` | GET `/admin/transactions` | `authorize Transaction` (`index?`) | HTML |

**index** algorithm:
1. `@current_start_date, @current_end_date = normalized_date_range`.
2. `@current_range = (@current_start_date.present? || @current_end_date.present?) ? "custom" : normalized_range`.
3. `@current_sort = normalized_sort`.
4. `scoped_transactions = filtered_transactions`.
5. `@total_transactions = scoped_transactions.count`.
6. `@total_pages = @total_transactions.zero? ? 1 : (@total_transactions.to_f / 10).ceil`.
7. `@current_page = normalized_page(@total_pages)`.
8. `@transactions = scoped.offset((page-1)*10).limit(10)`.
9. `@showing_from = total.zero? ? 0 : ((page-1)*10)+1`; `@showing_to = total.zero? ? 0 : @showing_from + @transactions.size - 1`.

Helpers:
- `filtered_transactions`: base `Transaction.includes(:customer, :fuel_pump, :user, :vehicle, fuel_pump_nozzle: %i[fuel_pump fuel_type_record])`. Date logic: if start/end present → `where("created_at >= ?", start.beginning_of_day)` and/or `where("created_at <= ?", end.end_of_day)`; elsif `@current_range == "today"` → `where(created_at: Time.zone.today.all_day)`. Sort switch: `time_asc` → `order(created_at: :asc, id: :asc)`; `amount_desc` → `order(fuel_amount: :desc, created_at: :desc, id: :desc)`; `amount_asc` → `order(fuel_amount: :asc, created_at: :desc, id: :desc)`; else (`time_desc`) → `order(created_at: :desc, id: :desc)`.
- `normalized_range`: whitelist RANGE_OPTIONS else `"all"`.
- `normalized_sort`: whitelist SORT_OPTIONS else `"time_desc"`.
- `normalized_date_range`: parses `start_date`,`end_date`; if both present and start > end → **swaps** to `[end, start]`.
- `normalized_page(total_pages)`: `params[:page].to_i`; `<1 → 1`; `> total_pages → total_pages`.
- `parse_date(value)`: blank → nil; `Date.iso8601(value.to_s)`; `rescue ArgumentError → nil`.

No flash. No JSON.

---

### Admin::PointsAdjustmentsController (`app/controllers/admin/points_adjustments_controller.rb`)
Pundit `authorize PointsLedger` → `PointsLedgerPolicy`. Strong params `points_adjustment_params`: `params.require(:points_adjustment).permit(:phone_number, :points)`.

| Action | HTTP+Path | authorize | Response |
|---|---|---|---|
| `new` | GET `/admin/points_adjustments/new` | `authorize PointsLedger` (`new?`) | HTML |
| `create` | POST `/admin/points_adjustments` | `authorize PointsLedger` (`create?`) | see below |

**create** algorithm:
1. `authorize PointsLedger`.
2. `assign_prefill_values`: if `params[:points_adjustment].present?` sets `@prefill_phone_number = points_adjustment_params[:phone_number]`, `@prefill_points = points_adjustment_params[:points]`.
3. `normalized_phone = Customer.normalize_phone_number(points_adjustment_params[:phone_number])`.
4. `unless Customer.valid_phone_number?(normalized_phone)` → `flash.now[:alert] = "Phone number must be a 10 digit number."`; `render :new, status: :unprocessable_entity` (422); return.
5. `customer = Customer.find_by(phone_number: normalized_phone)`. If nil → `flash.now[:alert] = "Customer not found."`; `render :new, status: :unprocessable_entity` (422); return.
6. `customer.points_ledgers.create!(points: points_adjustment_params[:points], entry_type: :adjust)` — **entry_type enum value `:adjust` hardcoded**.
7. Success → `redirect_to customer_path(customer), notice: "Points adjusted successfully."` (302). Note: redirects to `customer_path` (non-admin route), not `admin_customer_path`.
8. `rescue ActiveRecord::RecordInvalid => e` → `flash.now[:alert] = e.record.errors.full_messages.to_sentence`; `render :new, status: :unprocessable_entity` (422).

Alert strings: `"Phone number must be a 10 digit number."`, `"Customer not found."`; dynamic on RecordInvalid.

---

### Admin::UsersController (`app/controllers/admin/users_controller.rb`)
Pundit `authorize User`/instance → `UserPolicy`. Operates on `User.kept` (Discard gem — excludes soft-deleted).

**Strong params** `user_params`: `params.require(:user).permit(:name, :username, :phone_number, :email, :active, :password, :password_confirmation)`. **`:role` is permitted SEPARATELY** via `role_param` = `params.require(:user).permit(:role)[:role]` (kept out of mass-assign, applied explicitly).

| Action | HTTP+Path | authorize | Response |
|---|---|---|---|
| `index` | GET `/admin/users` | `authorize User` (`index?`) | HTML, `load_index_state` |
| `new` | GET `/admin/users/new` | `authorize @user` (`new?`) on `User.new(role: :staff)` | HTML |
| `show` | GET `/admin/users/:id` | `authorize @user` (`show?`) on `User.kept.find` | HTML |
| `create` | POST `/admin/users` | `authorize @user` (`create?`) | see below |
| `edit` | GET `/admin/users/:id/edit` | `authorize @user` (`edit?`) on `User.kept.find` | HTML |
| `update` | PATCH/PUT `/admin/users/:id` | `authorize @user` (`update?`) on `User.kept.find` | see below |

**create**: `@user = User.new`; authorize; `assign_user_attributes(@user, user_params)`. Success → `redirect_to admin_users_path, notice: "User created successfully."` (302). Failure → `load_index_state(new_user: @user)`; `render :index, status: :unprocessable_entity` (422).

**update**: load `User.kept.find`; authorize; `assign_user_attributes(@user, filtered_update_params)`. Success → `redirect_to admin_users_path, notice: "User updated successfully."` (302). Failure → `load_index_state(edit_user: @user)`; `render :index, status: :unprocessable_entity` (422).

Helpers:
- `load_index_state(new_user: User.new(role: :staff), edit_user: nil)`: `@users = User.kept.order(:role, :name, :username, :phone_number)`; `@user = new_user`; `@edit_user = edit_user`.
- `filtered_update_params`: `user_params.tap` — if BOTH `password` and `password_confirmation` blank, deletes both keys (so update leaves password unchanged). Otherwise keeps them.
- `assign_user_attributes(user, attributes)`: `user.assign_attributes(attributes)`; then `return unless role_param.present?`; `user.role = role_param`. **Role only set when the `user[role]` param is present** (allows creating/updating role explicitly; default `:staff` on `new`).
- `role_param`: `params.require(:user).permit(:role)[:role]`.

Notices: `"User created successfully."`, `"User updated successfully."`. No JSON. No `destroy` action here (users are not deleted via this controller).

---

### Admin::StaffMembersController (`app/controllers/admin/staff_members_controller.rb`)
Pundit `authorize User`/instance → `UserPolicy`. Scoped to `User.kept.where(role: :staff)`.

**Strong params** `staff_member_params`: `params.require(:user).permit(:name, :active, :employee_code, :subtitle)`. (Narrower than UsersController — no password/role/username/phone/email here.)

| Action | HTTP+Path | authorize | Response |
|---|---|---|---|
| `index` | GET `/admin/staff_members` | `authorize User` (`index?`) | HTML |
| `update` | PATCH/PUT `/admin/staff_members/:id` | `authorize @staff_member` (`update?`) | see below |
| `destroy` | DELETE `/admin/staff_members/:id` | `authorize @staff_member` (`destroy?`) | see below |

**index** state:
- `@staff_members = staff_members_scope`.
- `@edit_staff_member = nil`; `@assignment_form_user_id = nil`.
- `@shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)`.
- `@active_staff_count = @staff_members.count(&:active?)`.
- `@inactive_staff_count = @staff_members.count { |s| !s.active? }`.
- `@unassigned_staff_count = @staff_members.count { |s| s.current_shift_template.blank? }`. (`current_shift_template` is a User public method.)

`staff_members_scope`: `User.kept.where(role: :staff).includes(shift_assignments: [{ shift_template: { shift_cycles: { shift_cycle_steps: :shift_template } } }, { shift_cycle: { shift_cycle_steps: :shift_template } }]).order(:name, :username, :phone_number)`.

**update**: `@staff_member = User.kept.where(role: :staff).find(params[:id])`; authorize; `@staff_member.update(staff_member_params)`. Success → `redirect_to admin_staff_members_path, notice: "Staff member updated successfully."` (302). Failure → rebuilds all index ivars (`@staff_members`, `@edit_staff_member = @staff_member`, `@assignment_form_user_id = nil`, `@shift_templates`, and the three counts), `render :index, status: :unprocessable_entity` (422).

**destroy** (soft delete):
- `@staff_member = User.kept.where(role: :staff).find(params[:id])`; authorize.
- `@staff_member.soft_delete!` → `redirect_to admin_staff_members_path, notice: "Staff member soft deleted successfully. Historical records were kept."` (302).
- `rescue ActiveRecord::RecordInvalid` → `redirect_to admin_staff_members_path, alert: @staff_member.errors.full_messages.to_sentence.presence || "Unable to soft delete this staff member."` (302). Fallback alert string: `"Unable to soft delete this staff member."`.

Notices/alerts: `"Staff member updated successfully."`, `"Staff member soft deleted successfully. Historical records were kept."`, dynamic-or-fallback `"Unable to soft delete this staff member."`.

---

### Cross-cutting notes for the API layer
- **Auth**: every endpoint requires authenticated admin (`authenticate_user!` + `admin?`). A JSON API must return 401 (unauthenticated) / 403 (non-admin) instead of the HTML redirects Devise/Pundit produce.
- **Pundit policy classes** (not in these files, must be honored): `DashboardPolicy#show?`, `CustomerPolicy`, `Transaction`→policy, `PointsLedgerPolicy`, `UserPolicy`. `authorize` on a class calls the same-named `?` method as the action; symbol form `authorize :dashboard, :show?` targets `DashboardPolicy#show?`.
- **Normalization is model-side, invoked in controllers**: `Customer.normalize_phone_number`, `Customer.valid_phone_number?`, `Vehicle.normalize_vehicle_number` — the API must apply the same before persistence/lookup.
- **Failure convention (HTML)**: 422 `unprocessable_entity` re-rendering the index/show with form objects carrying `.errors`. JSON layer should serialize `record.errors.full_messages` / `errors` hash for these cases.
- **`entry_type: :adjust`** is the only ledger entry type this subsystem writes (points adjustments).
- **Pagination page sizes**: transactions index = 10; customer points_ledger = 5; customer transaction_history = 5 (with a fixed 3-record preview offset). Page clamping everywhere: `<1 → 1`, `>total_pages → total_pages`.
- **Computed field**: customer index exposes `total_points_sum` (SUM of points_ledgers.points, COALESCE 0).
- `PointsAdjustmentsController#create` success redirects to `customer_path` (non-admin), an inconsistency vs. other admin redirects.

Source files (absolute): `/Users/achalindiresh/workspace/fuel-loyalty/app/controllers/admin/{base,dashboard,customers,transactions,points_adjustments,users,staff_members}_controller.rb`; concerns `/Users/achalindiresh/workspace/fuel-loyalty/app/controllers/concerns/customer_{points_ledger,transaction_history}_rendering.rb`.