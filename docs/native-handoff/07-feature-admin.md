# 07 — Admin Features

Entire `/admin` namespace is admin-only (session), except Schedules + ad-hoc Send which also accept the service Bearer token (03). Admins also use all staff screens (06).

## 7.1 Dashboard (`GET /admin/dashboard` + `GET /admin/dashboard/data` JSON)

Analytics over transactions/customers/points. Filters (query params, both endpoints): `preset` (today | this_week | this_month | last_month — overrides dates), `start_date`/`end_date` (ISO; default = last 30 days ending today; swapped if reversed), `segment` (all | new | repeat), `fuel_type` (all | any fuel code). Full JSON contract in 11; math in 04.11.

- **8 KPI cards** (each: value, display value, change badge "+/−x% vs previous period" or "No data yet"/"New baseline", note): Total Customers · Active Customers (last 30 days) · Total Transactions · Total Revenue (with per-fuel-type breakdown list) · Points Issued · Points Redeemed · Average Spend per Visit · Visits per Customer.
- **Trends (4 line charts):** Transactions Trend, Revenue Trend, Points Issued vs Redeemed (2 series), Active Users Trend — all daily buckets.
- **Customer Insights:** Repeat vs New (bar), Visits Distribution (bar: "1 visit" / "2-5 visits" / "6+ visits"), two **Top-5 leaderboards** (by Visits, by Spend — rank, "Name - last4phone", value, sparkline trend, change label).
- **Rewards Insights:** Top Redemption Slabs (horizontal bar, bucketed by redemption increment, non-multiples → "Other / Legacy") + Redemption Rate card (% with meter, Issued/Redeemed totals).
- **Behavior:** Transactions by Hour (24 bars, "00:00"–"23:00"), Transactions by Day of Week (Mon–Sun).
- Toolbar: Quick Range chips, From/To dates, Customer Segment select, Fuel Type chips, **Reset**, **Download PDF** (= browser print — no server PDF; native: generate/share a PDF or screenshot), export-summary card (Range/Quick Range/Segment/Fuel Type/Generated).
- Web behavior worth keeping: filter changes fetch `/admin/dashboard/data` and re-render client-side without navigation; chart colors follow the theme.

## 7.2 Users (`/admin/users`)

Card list ordered role → name; role badge Admin/Staff; phone (`+91` or "Mobile not set"); email (real email or "Email not set"). "+ Add User" modal; per-row View + Edit modal. Empty: "No users available yet." Soft-deleted users excluded everywhere.

**Form fields:** Name* · Username (Login)* ("This is the login username shown on the sign-in page.") · Mobile Number* (`+91`, 10-digit) · Email (Optional) · Role (Admin/Staff) · Access Status (Active/Inactive — "Inactive users stay in history but cannot sign in until reactivated.") · Password (edit: "Leave blank to keep the existing password.") · Password confirmation. Blank password on update = keep existing. Model rules: 02 users (unique username/phone/email, last-admin guard).

**Show page:** detail grid (Name, Username, Role, Mobile, Email, Status) + for staff a **Soft Delete** button (confirm mentions history kept + must deactivate first). No hard delete anywhere; admins can never be deleted.

## 7.3 Staff (`/admin/staff_members`) + shift assignment

Staff-role users only. **Stat cards:** Active Staff / Inactive Staff / Unassigned Staff (no current shift). Header links: Cycles, Shifts, Attendance.

Per-staff card: avatar initial, name, optional subtitle, Active/Inactive badge; actions **Edit profile** (modal: Name*, Employee Code (Optional), Subtitle (Optional, ≤120), Access Status), **Shift** (assignment modal), **Soft-delete** (same rules as 7.2). "Assigned Shift" block: current shift name or "Unassigned", meta "{schedule} · {cycle name}". Details: Mobile, Employee Code (or "Not set"), Shift Cycle (or "No linked cycle"), Planning Status ("Visible in attendance"/"Hidden from attendance"). Empty: "No staff accounts available yet."

**Assign shift** (`POST /admin/staff_members/:id/shift_assignments`): Shift select (label "{name} · {start} · {duration} · {cycle}", blank "Choose the shift this staff member should load under") + Assignment Notes (Optional). Behavior: 04.10 (closes the previous assignment, links the template's current cycle). Success: "Shift assigned successfully." No templates yet → "No shifts yet" + "Open Shifts" link.

## 7.4 Shifts (`/admin/shift_templates`)

Card grid: name + Active/Inactive; **Starts At** (12h label), **Duration** ("X hours Y min"), **Assigned Staff** (active assignment count), **Linked Cycles** (active cycle count); Edit modal. "+ New Shift" modal. No delete. Empty: "No shift templates created yet."

**Form:** Name* (≤80, unique) · Shift Start Time* (time picker, 5-min steps → stored "HH:MM") · Shift Duration (hours)* (min 0.5, step 0.25; hint "Use hours like 6, 12, 24, or a custom value such as 7.5" — converted to minutes) · Active select.

## 7.5 Cycles (`/admin/shift_cycles`)

Rotation sequences of shifts. Card: name + badge; **Cycle Starts** date, **Flow** ("Each shift uses its saved duration"), **Full Cycle** (total duration), **Sequence** ("A → B → C"), **Assigned Staff** count. Actions: Edit modal; **Delete** only when unused (confirm "Delete this unused shift cycle?"; else alert "This shift cycle already has staff assignment history. Deactivate it instead of deleting it."); Activate/Deactivate toggles.

**Form:** Cycle Name* (≤80, unique) · Cycle Starts On* (date) · **Shift Order In The Cycle**: up to **12** step selects ("Leave this step empty" | template label); 3 slots visible initially, "Add Another Shift" reveals more; ≥1 required ("Choose at least one shift in the cycle.") · Active. Steps are fully rebuilt on save (positions 1..n). Rotation math: 04.8.

## 7.6 Attendance (`/admin/attendance_runs`)

**Index:** filters — Record State chips All/Valid/Invalid + Attendance Date From/To (≤ today, swapped if reversed); 6 per page, newest first. Run card: shift name snapshot, staff-count badge, window "dd Mon · hh:mm AM to …", Open; if Invalid: "Invalid" badge + Delete (confirm "Delete this invalid attendance record?"). Details: Recorded By, Saved At, Status (Valid/Invalid), Status Summary ("Present 3 · Absent 1" for non-zero statuses). Pager "Showing X–Y of N".

**New (planner):** Shift select + Start Date Time (default = today at the shift's start time) + auto-computed read-only End (= start + duration) + "Load Staff". Guards: duplicate valid window → "Attendance has already been recorded for this shift and time window."; if the shift belongs to active cycles, the window must align to the rotation → "Selected start and end date time do not match this shift's repeating cycle…". Loads one row per rostered staff (04.9), all defaulted Present with check-in/out = window.

**Entry rows:** scheduled name + phone, shift badge; fields per row — **Status** (Present/Absent/Late/Half day/Leave/Off), **Actual Staff** select, **Replacement Staff** select (absent only; includes "No internal replacement"), **External Replacement** text (absent only), **Check In / Check Out** (datetime), **Notes**. Header button "Mark All Present". Run-level: "Mark this as an invalid attendance record" checkbox + Run Notes. Save → show page. No staff rostered → "No staff assigned yet".

**Show:** summary cards (Shift, Window, Recorded By, Status); count cards for all 6 statuses; entry list (scheduled name, status badge, actual worker, check in/out, notes). Actions: valid run → **Invalidate** (confirm "Mark this attendance record invalid?"); invalid run → **Mark Valid** (only when the exact window is still free, else disabled) + **Delete** (only invalid runs deletable: "Only invalid attendance records can be deleted.").

Entries are immutable after save (no per-entry edit UI); corrections = invalidate the run and record a new one.

## 7.7 Fuel Types (`/admin/fuel_types`)

Left: add form — **Fuel Type Name*** (hint: internal code auto-generated on first save, then fixed) + **Show in app** switch; persisted rows show `Code: {code}`. Right: list — name; meta "Code: {code}. Shown in app./Hidden from new selections. Used by N vehicles/Not used…"; Active/Inactive pill; Edit page; Delete (confirm "Remove {name}?"; blocked while vehicles or nozzles use it). Empty: "No fuel types have been added yet."

## 7.8 Pumps (`/admin/fuel_pumps`)

Top-left: **Transaction Pump Settings** — single switch **"Enable nozzle selection"** (`PATCH /admin/fuel_pumps/feature_settings`, stored on RewardSetting): "When enabled, staff use My Pump and assigned nozzles. When disabled, staff choose the pump directly in New Transaction." Notice: "Pump transaction settings updated successfully."

Pump add/edit form: info banner with pending display name ("Pump N" auto-numbered) · **Show in app** switch · **Nozzles** repeater ("Add Nozzle" clones a row): per nozzle **Fuel Type** select (active types; an in-use inactive type stays visible) + **Active nozzle** switch + Remove. New pump starts with one active nozzle; ≥1 required ("must include at least one nozzle").

List: "Pump N", meta "N nozzles configured. M active nozzle(s). Shown/Hidden"; nozzle badges "Nozzle N • {fuel type}[ • Inactive]"; Edit; Delete (confirm "Remove Pump N?"; blocked with transactions). Empty: "No pumps have been added yet."

## 7.9 Vehicle Types (`/admin/vehicle_types`)

List rows: icon + name; meta "Short name: {..}. App label: {Vehicle Type Name|Short Name}. Icon: {label}. Minimum redeemable: {n} points. Code: {code}. Shown/Hidden. Used by N vehicles…"; Edit; Delete (blocked while vehicles use it).

**Form:** Vehicle Type Name* · Short Name (placeholder "LMV") · **App Label** radio: "Use Vehicle Type Name" / "Use Short Name" · **Code** (create only; pattern `[a-z_]+`; "leave blank to generate from name… Once created, the code stays fixed.") · **Icon** picker (8 options: Bike, Auto Rickshaw / 3 Wheeler, Car, Pickup Truck, Truck, Big Truck, Bus, Tractor; auto-suggested from the name until manually chosen) · **Minimum Redeemable Points*** (min/step 100; "in multiples of 100") · Show in app switch.

Note: per-type earn override (`reward_points_per_100`) is edited on Reward Rates (7.10), not here.

## 7.10 Reward Rates (`GET/PATCH /admin/fuel_reward_rates`) — one page, three forms

A. **Reward Settings:** **Rupee Unit*** (`rupees_per_reward_unit`, Rs. prefix, min 1) · **Minimum Redeemable Points** (optional; "Leave blank to keep using existing vehicle-type minimums") · **1 Point Cash Reward** (`cash_value_per_point`, Rs., min 0, step 0.01, optional). Submit "Save Reward Settings".

B. **Vehicle Type Reward Overrides:** one number per vehicle type (`reward_points_per_100`, min 0, suffix "pts / Rs.{unit}"); blank = fall back to fuel-type rate. Submit "Save Vehicle Type Reward Rates".

C. **Fuel-Type Fallback Rates:** one required number per active fuel type (`points_per_100`, min 0, suffix "pts"; meta "Points awarded for every Rs.{unit} spent…"). Submit "Save Fuel Reward Rates".

All three PATCH the same endpoint; the server dispatches by which param group is present. Effects on math: 04.1/04.2.

## 7.11 Theme (`GET/PATCH /admin/theme_settings`)

Color picker for **primary_color** (+ read-only hex echo) with a live Preview card (Accent Badge, Primary Button, Outline Button). Save → "Theme color updated successfully." On change, Cloudflare cache purge fires for public URLs. Propagation mechanics: 10.

## 7.12 Notifications (`GET /admin/notifications`)

- Header **Run Scheduler** button (`POST /admin/schedules/run`).
- **Send Now** card: Title* (≤120) + Message* (≤240) → `POST /admin/notifications/send`. Notice: "Notification sent. {sent} deliveries succeeded, {failed} failed."
- **Stat cards:** Active Tokens / Total Registrations / Saved Schedules (+ per-platform badges "Android: N" etc.).
- **Create Schedule** card + **Saved Schedules** list — per schedule: title, Active/Paused badge, frequency badge, message, "Schedule: {summary}", "Last sent: {…|Never}"; actions Send Now / Edit modal / Delete (confirm). Empty: "No schedules yet".
- **Schedule form:** Title* · Message* · **Frequency** (Once/Daily/Weekly/Monthly, default Daily) · **Time*** ("Times use India Standard Time (IST)…") · Active switch · conditional: Once → **Send on** date ("One-time schedules auto-disable after the first successful run."); Weekly → **Day of week** (Sunday…Saturday); Monthly → **Day of month** 1–31 ("If the chosen day does not exist … sends on that month's last day.").
- Semantics + runner: 04.7; delivery: 08.

## 7.13 Customers (admin) (`/admin/customers`)

Same profile/form components as staff (06.3/06.4) plus:
- **Index filters:** Search `q` ("Search by name, phone, or vehicle" — matches name, phone, vehicle numbers incl. legacy column) + status chips All/Active/Inactive; newest first; rows show name+pill, phone, vehicles, points, View.
- Full CRUD: new/create (initial vehicle required), edit/update (name+phone), **destroy** (blocked with transaction history), plus the same ledger/history endpoints under `/admin/customers/:id/…`.

## 7.14 Points Adjustments (`/admin/points_adjustments/new`)

"Adjust Loyalty Points": **Phone Number** (`+91`, live lookup card via the staff lookup endpoint: name/status/points/max redeemable/vehicles) + **Points** (number; "Use positive values to add points and negative values to deduct…") → `POST /admin/points_adjustments`. Creates ledger row `entry_type: adjust` with the signed points (**no reason field**). Errors: "Phone number must be a 10 digit number." / "Customer not found." Success → customer profile, "Points adjusted successfully."

## 7.15 Transactions (`/admin/transactions`) — read-only

Filters: Quick chips All/Today · **Sort By** ("Time: Latest first" default, "Time: Oldest first", "Amount: High to low", "Amount: Low to high") · From/To dates (override the chip; swapped if reversed). 10 per page ("Showing X–Y of N transactions", Previous/Next preserving filters). "+ New" → the staff wizard.

Row: customer name; "dd Mon YYYY · hh:mm AM"; "Pump N · Nozzle M" when present; ₹amount; **View** → detail modal: hero amount + fuel-type chip; chips (timestamp, vehicle kind); grid — Phone Number, Vehicle Number, Fuel / Type ("{fuel} · {kind}"), Pump, Nozzle, Handled By. Transactions are never editable or deletable.
