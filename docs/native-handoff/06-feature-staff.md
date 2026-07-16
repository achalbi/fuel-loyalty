# 06 — Staff Features

Everything here requires staff_access (admin OR staff). Admin sees these same screens via the sidebar.

## 6.1 New Transaction (`/staff/transactions/new`) — the flagship flow

A 3-step wizard with two lookup modes, presented as tabs: **"Vehicle Number"** (default) and **"Phone Number"**. Steps: **1 Find → 2 Review/Confirm → 3 Fuel Details**, with a stepper showing Locked/Next/Ready/Current/Done states. In the web app the wizard lives in a modal opened by an "Open Steps" button (auto-opens when the plate scanner is requested via `?plate_scanner=1` or when server errors need review); natively make the wizard the screen itself.

### Step 1 — Find

- **Vehicle tab:** vehicle-number field (autocapitalize; plate-scanner attached — see 09) with debounced lookup `GET /staff/transactions/lookup?vehicle_number=` (300 ms debounce, min 6 chars). Returns **all** vehicles matching the normalized plate (a plate can exist under multiple customers), each with its customer payload. Errors: invalid format → 422 "Vehicle number is invalid."; none found → 404 "No customer was found for that vehicle number." + a register-customer link.
- **Phone tab:** phone field (`+91`, 10-digit) with debounced lookup `GET /staff/customers/lookup?phone_number=` (300 ms). Errors: 422 "Phone number must be a 10 digit number."; 404 "Customer not found for that phone number." + register link.
- Lookup responses are race-guarded (stale responses discarded). "Continue to Review" stays disabled until a result loads.

### Step 2 — Review / Confirm

- **Phone mode:** live customer card (points, status, vehicles on file, selected vehicle) + a required **vehicle select** ("Select a vehicle") listing the customer's vehicles; tappable registered-vehicle list syncs the select.
- **Vehicle mode:** the select is relabeled **"Matching Customer"** ("Select the matching customer") to disambiguate shared plates. Header has an **"Add Customer"** (user-plus) button → inline registration (below).
- Auto-select when exactly 1 result, or when a prefilled `vehicle_id` matches.
- **Blockers:** inactive customer → "This customer is inactive. Activate the customer before recording a transaction." (submit disabled); multiple matches unresolved → submit disabled.

### Step 3 — Fuel Details

- **Fuel Amount (₹):** number, step 0.01, min 1, required.
- **Payment Type:** pill radios **Cash** (default) / **Credit**.
- **Pump/Nozzle** — depends on the admin "nozzle feature" toggle:
  - **Nozzle mode ON (default):** header "My Pump" with an edit link → `/my_pump`. Shows "Selected Pump" (Pump N) and "(n) assigned nozzle(s) ready." Then a **Nozzle** radio group of the user's assigned nozzles (each knows its fuel type). Client filters nozzles to the selected vehicle's fuel type, auto-selects a sole match, and messages: "Petrol nozzle selected for this vehicle." / "No Petrol nozzle is assigned to your pump for this vehicle." If My Pump isn't configured: warning "Set up My Pump with at least one active nozzle before recording transactions." + "Open My Pump" link; saving is blocked.
  - **Nozzle mode OFF:** header "Pump", radio list of active pumps with active-nozzle counts. Empty: "No active pumps are available right now. Ask an admin…"
- "Save Transaction" disabled until valid.

### Submit (`POST /staff/transactions`, scope `transaction`)

Params: `lookup_mode, phone_number, vehicle_number, vehicle_id, fuel_amount, fuel_pump_id, fuel_pump_nozzle_id, payment_mode`. Server runs TransactionCreator (all rules + messages in 04.3).

- **Success →** redirect to the customer profile. If rewards paused: notice "Transaction recorded. Rewards are paused for this customer, so no points were added." Otherwise the profile hero shows a one-time banner **"+{points} reward points added. Balance updated to {new_total}."** (via a `transaction_summary` flash). There is no separate success screen — the customer profile IS the success screen.
- **Failure →** 422 re-render with error list, a top alert "Transaction could not be saved." + "Review Steps" button, and the wizard highlighting the failing step (lookup/review/fuel).

### Inline customer registration (never leave the wizard)

Modal "Add Customer" → `POST /staff/transactions/register_customer`. Renders the shared customer form **with vehicle fields**, carrying hidden `transaction_lookup[...]` state (lookup mode, phone, vehicle number, fuel amount, pump/nozzle, payment mode) so the wizard resumes afterward.

- Auto-opens after a "not found" lookup; also opened manually. A **scanned** plate is treated as a committed lookup and opens the modal immediately (the scanner also closes its camera on a successful read so the modal isn't hidden behind the live preview); a **typed** plate still waits ~2 s so the number can be finished first.
- **Live existing-customer detection:** typing a phone that matches an existing customer locks the name field and shows "Existing customer found: {name} (+91 …). This vehicle will be added to that customer."
- **Vehicle-detail locking:** when opened from a vehicle-mode match with known fuel type/kind, those pickers are hidden and mirrored as hidden inputs.
- Server: find-or-build customer by phone; requires name, phone, vehicle_number, fuel_type, vehicle_kind; saves customer + vehicle atomically. Success → back to the transaction screen, prefilled, with notice "Customer created successfully. Continue recording the transaction." (variants: "Vehicle added to the existing customer…", "Existing customer details loaded…"). Failure → 422, modal reopens with errors.
- **Native app parity:** the Android transaction screen mirrors this. An unregistered plate (`/api/v1/staff/transactions/lookup` → 404 `vehicle_not_found`) shows an "Add Customer" action that opens a bottom-sheet form; fuel-type/vehicle-kind options come from `GET /api/v1/staff/catalog` (commercial kinds reveal the commercial fields), and `POST /api/v1/staff/transactions/register_customer` returns the customer, which becomes the selected match so the sale is recorded without leaving the screen.

### Prefill entry points

- Topbar camera button and `?plate_scanner=1` → vehicle tab + scanner auto-open.
- Customer-profile vehicle rows have a gas-station quick link that prefills `{lookup_mode: "vehicle", phone_number, vehicle_number, vehicle_id}`.

## 6.2 Redeem Points (`/staff/redemptions/new`)

Two-column screen.

- **Left form** (`POST /staff/redemptions`, scope `redemption`): **Phone number** (`+91`, 10-digit, debounced lookup via the same customer-lookup endpoint) and **Points to Redeem** — a select, disabled until a customer loads, populated from `minimum_redeemable_points` to `max_redeemable_points` stepping by `redemption_increment`; option labels append cash value when configured. Helper: "Points can only be redeemed in multiples of {increment}." A live line shows the cash value of the chosen amount. Submit **"Redeem Points"** — enabled only when customer loaded + valid amount.
- **Right card "Customer Details":** placeholder "Search by phone number to view the customer and current points balance." → after lookup: Available Points, redeem-status note, name, status pill, phone, and stats **Minimum Redeemable / Max Redeemable / Max Cash Reward / Vehicles on File**.
- Client blocks with messages: paused → "Rewards are paused for this customer. Resume rewards to redeem points."; insufficient → "This customer does not have enough redeemable points yet. Minimum redemption for this customer is {N} points."
- Server validation ladder + messages: see 04.2. Success → customer profile, notice **"{N} points redeemed successfully."** (+ " Cash reward: ₹{X}." when configured). Failure → 422 with errors.

## 6.3 Customers (`/staff/customers`)

**Index:** header "Customers" + **"+ Add Customer"** (modal). Search box "Search by customer name or phone number." (param `q`).
- No query → **top 3 customers by total points** (ledger-sum, desc, then newest).
- Query → `name ILIKE %q%` OR `phone LIKE %digits%`, newest first, limit 50.
- Row: titleized name + Active/Inactive pill, `+91` phone, vehicle numbers joined (or "No vehicles on file"), `{N} pts`, eye → profile. Empty: "No customers matched that search." / "No customers available yet."

**Create (`POST /staff/customers`):** shared form with **required initial vehicle**: Name, Phone, Initial Vehicle Number, Fuel Type pills, Vehicle Type pills (+ commercial fields for lcv/mcv/hcv — company name*, owner/manager name*, owner/manager phone, address*, notes). Customer + first vehicle saved atomically. Success → profile, "Customer created successfully." There's also a standalone `GET /staff/customers/new` page (prefills `phone_number`/`vehicle_number` from query params — used by "register customer" links).

**Status toggles** (PATCH member routes; also exposed on the profile's actions menu):
- `activate` → "Customer activated successfully."
- `deactivate` (confirm "Mark this customer as inactive?") → "Customer marked as inactive."
- `pause_rewards` (confirm "Pause rewards for this customer?") → "Rewards paused for this customer."
- `resume_rewards` → "Rewards resumed for this customer."

**Customer lookup JSON** (`GET /staff/customers/lookup?phone_number=`) — the most reused endpoint (transaction wizard, redemption, points adjustment). Returns id, display name, phone, active, rewards_paused, status labels, total_points, cash-value fields, minimum/max redeemable, redemption_increment, and vehicles (id, number, fuel_type_code, display names). Full shape in 11.

## 6.4 Customer profile (`GET /customers/:id`) — staff's main workspace

- **Hero:** "Current Points" (total), one-time "+N reward points added…" banner after recording a sale; chips: visits count, vehicles count, "Rewards Paused" (when paused), cash-value chip (when configured), "Joined {Mon YYYY}", and a **"Redeem Points"** chip prefilling the redemption screen.
- Identity: titleized name, Active/Inactive pill, "Phone: {digits}".
- **Actions menu (pencil):** Edit Customer (modal: name + phone only → `PATCH /customers/:id`, success "Customer updated successfully."), Mark Active/Inactive, Pause/Resume Rewards, Delete Customer (**admin only**, confirm "Remove this customer?"; blocked with "Customer cannot be removed because transaction history exists." if any transactions).
- **Vehicles section:** "+" opens Add Vehicle modal. Row: number, `{fuel} · {kind}`, commercial contact summary when commercial; quick-transaction link; Edit modal / Delete (confirm "Remove this vehicle?"; blocked with "Vehicle cannot be removed because transaction history exists."). Empty: "No vehicles registered yet." Vehicle form fields + validations: see 02 vehicles. Success notices: "Vehicle added successfully." / "Vehicle updated successfully." / "Vehicle removed successfully."
- **Recent Transactions:** latest 3 preview; "view more" opens a history modal **only when > 3** exist. Row: vehicle number (or "Vehicle not linked"), "Handled by {staff}", "Pump N · Nozzle M" when present, "Reward Points: +N", "Cash Reward: ₹X" when recorded, amount ₹ + short date. Empty: "No transactions recorded yet."
- **Points Ledger:** collapsible; lazy-loads pages of 5 (`GET /customers/:id/points_ledger?page=`). Row label by entry type: earn "Points Earned", redeem "Points Redeemed", expire "Points Expired", adjust "Manual Adjustment"; signed points green/red; "Cash: ₹X" when recorded; short date; pager "Showing X–Y of N entries". Empty: "No ledger entries yet."
- **Transaction history modal:** pages of 5 **offset by the 3 previewed** ("Showing X–Y of N more transactions"), `GET /customers/:id/transaction_history?page=`.

## 6.5 My Pump (`/my_pump`)

Self-service pump/nozzle assignment that powers nozzle-mode transactions. Any staff/admin, own record only.

- **Pump** select ("Select your pump"; inactive pumps labeled "(Inactive)").
- **Assigned Nozzles:** per-pump checkbox cards ("Multiple allowed"); only the selected pump's group is visible/enabled; tapping a card toggles it. Empty state: "No pumps are available yet." (admins get an "Add pumps" link).
- `PATCH /my_pump` params: `fuel_pump_id`, `assigned_fuel_pump_nozzle_ids[]`. Validation errors (friendly): "Select at least one nozzle for the chosen pump." / "Select only nozzles from the chosen pump." / "Select only active nozzles for the chosen pump."; pump must be active. Success: "My pump updated successfully."

## 6.6 Notifications (`/staff/notifications`)

Static device-enrollment page: if push configured → "This Device" section with the push opt-in panel (title "Enable Notifications On This Device") — enable/disable buttons wired to `/push/subscriptions` (see 08). Else → "Push Notifications Are Unavailable" empty state. Side card: three static "Why Enable It?" blurbs.

## 6.7 Change Password (`/password/edit`)

Current password, New password, Confirm new password → `PATCH /password`. Success → role home + "Password updated successfully."; keeps the session. Errors listed inline. Length 6–128.
