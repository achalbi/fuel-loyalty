# AceFuels — Functional Requirements Catalog

Authoritative, source-derived catalog of **what** the AceFuels system must do,
extracted from `AceFuels_Requirement.xlsx` (7 sheets). This document captures
requirements only — it does **not** propose designs, schemas, or implementation.

- **Feature IDs** are shared across all AceFuels docs: A1–A10 (setup/users/shifts),
  B1–B2 (customer capture), C1–C5 (rewards), D1–D10 (daily settlement),
  E1–E7 (dashboard/CRM/reports), F1–F4 (campaigns/notifications), G1 (per-pump
  visualize + edit), S-MYPUMP / S-PAUSE (staff-login constraints).
- **Status** column reflects the VERIFIED AUDIT STATUS of the current app
  (Rails PWA + JSON API + native Android): **Present** / **Partial** / **Absent**.
  See `40-gap-analysis.md` for the evidence behind each verdict.

### Locked decisions that scope acceptance (2026-07-21)

- **Q1 Units** — Litres / meter readings are the **source of truth**; ₹ is **derived**
  from the product-catalog selling price. Acceptance criteria referencing amounts assume
  this direction of derivation.
- **Q2 Surfaces** — Every feature must exist on **both** the Rails PWA and the native
  Android app, plus the JSON API that backs Android. "The system provides X" below means
  X on all three surfaces unless a requirement is admin-only (PWA/API) or FSM-mobile-first.
- **Q3 Operator KYC** — Operator identity captures **profile fields only** (photo, address,
  Aadhaar number, ID-card photo); **username/mobile + password** login is retained; **no OTP/SMS**.

### Terminology (inferred from the sheets — *to confirm*)

- **OTP** = fleet/credit account billed by litres (a customer *type*, **not** one-time-password).
- **TT** = tank-truck credit line.
- **Drive-in** = walk-in cash customer.
- **Credit** = credit-account customer.
- **FSM** = Forecourt Sales Man / pump operator (the non-admin role).

---

## Roles

| Role | Source sheet | Description |
|---|---|---|
| Admin User | Users | Full back-office access: setup, rewards, settlement view/edit, reports, CRM, campaigns, notifications. |
| Pump Operator / FSM | Users | Forecourt operator. Captures customer details per visit and files the shift-end Daily Settlement. Excluded from "My Pump" self-assignment and "Pause Rewards" (see Staff constraints). |

---

## A. Setup (pumps, nozzles, products, vehicle types)

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| A1 | Set up number of pumps | Admin / PumpsNozzlesProductsSetup | Admin defines the outlet's dispensing pumps. | • Admin can create, list, rename, and deactivate a pump.<br>• Each pump has a stable identifier/sequence (e.g. P1, P2, P3).<br>• Deactivating a pump hides it from FSM capture and settlement selectors without deleting history. | Present |
| A2 | Set up nozzles | Admin / PumpsNozzlesProductsSetup | Admin defines nozzles that belong to pumps. | • Admin can add one or more nozzles under a given pump.<br>• Each nozzle has a stable identifier/sequence (e.g. N1–N8).<br>• A nozzle cannot exist without a parent pump.<br>• Seed layout is reproducible: P1[N1 HSD, N2 HSD] P2[N3 HSD, N4 MS] P3[N5 HSD, N6 HSD, N7 MS, N8 MS]. | Present |
| A3 | Assign nozzles to pumps | Admin / PumpsNozzlesProductsSetup | Every nozzle is bound to exactly one pump. | • Each nozzle resolves to exactly one pump.<br>• Listing a pump shows its nozzles.<br>• The pump→nozzle map matches the seed layout in A2. | Present |
| A4 | Assign product (MS/HSD) per nozzle | Admin / PumpsNozzlesProductsSetup | Each nozzle dispenses a defined fuel product. | • Admin can set a nozzle's fuel product to MS or HSD.<br>• The nozzle's fuel product is displayed wherever the nozzle is selected (capture, settlement).<br>• Fuel-type list is at minimum {MS, HSD} and is admin-editable. | Present |
| A5 | Product catalog (fuel + lubes + AdBlue) | PumpsNozzlesProductsSetup | Master list of every sellable product with pricing and batch, spanning fuels, lubricants/oils, and AdBlue. | • Admin can create/edit a product with: name, batch, MRP, and selling price.<br>• Catalog covers fuels (HSD, MS) and lube/oil/AdBlue lines: 2T (20/40/60 ml, 500 ml), 10W30 800 ml, Milex Petrol (5/40 ml), Milex Diesel (10/50 ml), AdBlue (5L/10L/20L).<br>• Selling price for a product is retrievable by other features (settlement pricing, ₹ derivation).<br>• A product can be listed/searched and deactivated without losing historical references. | ✅ Present |
| A6 | Vehicle types | Admin | Admin maintains the vehicle-type taxonomy used for rewards and reporting. | • The six defaults exist: 2W, 3W, LMV (Car), LCV, MCV, HCV.<br>• Admin can create/edit/deactivate a vehicle type.<br>• A vehicle type carries its own reward configuration (see C2). | Present |

---

## B. Customer capture

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| B1 | Customer master | Admin | Admin maintains a customer master keyed by vehicle registration, with driver / supervisor / owner contacts and a contacted-by record. | • A customer record holds vehicle registration number and, separately, **driver name+mobile**, **supervisor name+mobile**, and **owner name+mobile**.<br>• A "contacted-by" selector records whether contact is via owner, supervisor, or driver, with an info affordance showing that contact's details.<br>• Admin can create, search, edit, and deactivate a customer.<br>• The record supports a customer **type** (OTP/Fleet, Drive-in, Credit) used by dashboard and campaigns. | Partial |
| B2 | FSM per-visit customer details entry | Staff_FSM / CustomerDetailsEntry | FSM captures a visit record many times per day at the forecourt. | • Form fields: Date (auto-populated, editable), Vehicle#, Driver Name, Driver Mobile, Number of Litres filled, Pump# (defaults to the FSM's pump, overridable), Discount Amount, Fleet/OTP (Yes/No, default No), Transport Name, Manager Name, Manager Mobile, Owner Name, Owner Mobile, Approx Number of Vehicles.<br>• Litres is captured directly; ₹ is derived from catalog selling price (Q1).<br>• A single FSM can submit multiple entries within one shift/day.<br>• Same-day entries are retrievable by pump/date so Daily Settlement can pull discounts (see D3). | Partial |

---

## C. Rewards

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| C1 | Cash reward per ₹100 / per x ₹ | Admin | Admin configures a base loyalty accrual as cash reward per spend increment. | • Admin can set the spend increment (default ₹100) and the reward value per increment.<br>• Accrual applies to qualifying transactions using the configured increment.<br>• Changing the setting affects future accrual only, not settled history. | Present |
| C2 | Reward by vehicle type | Admin | Reward rates can vary by vehicle type. | • Admin can set a distinct reward rate per vehicle type (points/₹ or points/₹100).<br>• A transaction's accrual uses its vehicle type's rate.<br>• Time-boxed offers (start/end) per vehicle type are supported. | Present |
| C3 | Reward by fuel type | Admin | Reward rates can vary by fuel type. | • Admin can set a distinct reward rate per fuel type.<br>• A transaction's accrual reflects the fuel type dispensed.<br>• Fuel-type and vehicle-type rules resolve to a defined, non-ambiguous accrual. | Present |
| C4 | Pause rewards | Admin | Rewards can be paused — both per customer and **globally** for all customers. | • Admin can pause/resume rewards for an individual customer.<br>• Admin can pause/resume rewards **globally** with a single switch.<br>• While paused (either scope), qualifying transactions accrue **no** reward.<br>• Resuming does not retroactively grant rewards for the paused window. | ✅ Present |
| C5 | Accumulated loyalty bonus | Admin | The system tracks each customer's accumulated loyalty balance and its cash value. | • Each qualifying transaction posts a ledger entry (points and/or cash value).<br>• A customer's current balance and cash value are retrievable.<br>• Redemptions decrement the balance and are recorded.<br>• Balance is consistent with the configured accrual rules (C1–C3) and pauses (C4). | Present |

---

## D. Daily Settlement (FSM shift-end + Admin view/edit)

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| D1 | Per-nozzle settlement entry | Staff_FSM / DailySettlement | At shift end the FSM picks a pump; its nozzles and fuels are shown, and per-nozzle meter figures are entered/derived. | • Selecting a pump lists its nozzles with their fuel and price (from catalog).<br>• Per nozzle: Today's Reading entered, Yesterday's Reading auto-populated from the prior settlement.<br>• System computes Total Litres, subtracts Testing Litres to give Net Litres Sold, and computes Amount = Net Litres × Price.<br>• FSM name is recorded on the settlement. | Absent |
| D2 | Lubes in settlement (qty + stock) | Staff_FSM / DailySettlement | Lube/oil/AdBlue sales and stock are captured in settlement. | • Each catalog lube product is selectable via checkbox.<br>• For a selected lube, FSM enters Qty; Amount is computed from catalog price.<br>• Opening Stock and Closing Stock are captured per lube product.<br>• Lube amounts roll into the settlement fuel+lubes subtotal. | Absent |
| D3 | Discounts pulled from customer entries | Staff_FSM / DailySettlement | Same-day discount lines flow from CustomerDetailsEntry into the settlement. | • Settlement's discount section is populated from same-day CustomerDetailsEntry records for that pump.<br>• Each discount line shows Transport, Litres, Discount Amount, and driver/manager/owner name+mobile.<br>• Total discounts feed the final-settlement calculation (D6). | Absent |
| D4 | PhonePe POS + Scanner amounts | Staff_FSM / DailySettlement | Digital collections are recorded in settlement. | • FSM can enter PhonePe POS (machine) Amount.<br>• FSM can enter PhonePe Scanner Amount.<br>• Both reduce the cash to be settled in the final calculation (D6). | Absent |
| D5 | Fleet/OTP + TT credit lines | Staff_FSM / DailySettlement | Credit dispensed to fleet/OTP accounts and tank-trucks is recorded as credit lines. | • FSM can add Fleet/OTP credit lines (litres + discount + vehicle reference, e.g. "OTP 136 Lts NL-01/AE-2471").<br>• FSM can add TT (tank-truck) credit lines with litres and discount.<br>• Credit-line totals feed the final-settlement calculation (D6). | Absent |
| D6 | Final amount to settle | Staff_FSM / DailySettlement | The settlement computes the net cash the FSM must hand over. | • Final Amount = {Fuel Sold + Lubes} − {Discounts + PhonePe POS + PhonePe Scanner + credit lines}.<br>• The computation is shown with its component subtotals.<br>• Recalculates when any contributing input changes. | Absent |
| D7 | Cash denomination + shortage | Staff_FSM / DailySettlement | Remaining cash is counted by denomination and reconciled against expected. | • FSM enters counts for denominations 500/100/50/20/10/5; each row shows qty × value = amount.<br>• Counted cash total is computed.<br>• Shortage per pump = expected (D6) − counted, and is displayed. | Absent |
| D8 | Stock received + decantation | DailySettlement / DailySettlementSample | Fuel stock received and tank decantation readings are recorded. | • FSM can record Stock Received per fuel (MS / HSD).<br>• FSM can record Decantation as tank KL readings.<br>• These entries are attached to the day's settlement for the pump/outlet. | Absent |
| D9 | Admin view/edit settlement | Admin / DailySettlement | Admin can review and correct settlements per pump and across pumps, including past days. | • Admin can view any settlement by pump and date, and an across-pumps consolidated view.<br>• Admin can edit a submitted settlement, including prior days.<br>• Edits are persisted and reflected in dependent totals/reports. | Absent |
| D10 | Rate comparison | DailySettlementSample | Own selling price is compared against a competitor benchmark. | • The system displays own price vs a competitor benchmark (e.g. JIO-BP) per fuel.<br>• The comparison is visible in the settlement/admin context.<br>• Values derive from the product catalog (A5) and a competitor input. | Absent |

---

## E. Dashboard / CRM / Reports

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| E1 | Reports (periodic, by dimension) | Admin | Daily/weekly/monthly/yearly reports per vehicle, transporter, and driver. | • Reports can be generated for daily, weekly, monthly, and yearly periods.<br>• Reports can be grouped by vehicle, transporter, and driver.<br>• Metrics include litres, discount, and gifts/rewards.<br>• Report output is exportable. | Absent |
| E2 | Customers by period (dashboard) | Admin | Dashboard buckets customers by today / this week / last 30 days / last month, with drill-through. | • Dashboard shows customer counts for today, this week, last 30 days, and last month.<br>• Each tile/leaderboard entry drills through to the underlying period-filtered customer list.<br>• Counts are consistent with the selected period. | ✅ Present |
| E3 | Visit cadence per customer | Admin | Per-customer/transporter last-visit and cadence classification (daily/weekly/biweekly). | • Each customer/transporter shows a last-visit date.<br>• The system classifies visit cadence as daily, weekly, or biweekly.<br>• Cadence is derived from actual visit history. | Partial |
| E4 | Customer-type view | Admin | Dashboard segments customers by type: OTP (Fleet) / Drive-in / Credit. | • Dashboard can filter/segment customers by type OTP/Fleet, Drive-in, and Credit.<br>• Counts per type are shown.<br>• Type is sourced from the customer master (B1). | Absent |
| E5 | Contact tracking + conversion probability | Admin | Track how many customers were contacted, when last contacted, and a conversion likelihood. | • Dashboard shows contacted count and last-contact date per customer/segment.<br>• A conversion-probability indicator is presented.<br>• Contact data derives from the contacted-by record (B1). | Absent |
| E6 | Lost-customer / churn detection | Admin | Intelligent detection of customers who have lapsed (e.g. visited last week, not this week). | • The system flags customers who visited in a prior period but not the current one.<br>• Flagged (lost) customers are surfaced as a "reach out" list.<br>• Detection uses visit-cadence history (E3). | Absent |
| E7 | Customer feedback / rating | Admin | Capture and view customer feedback and ratings. | • A customer feedback/rating can be recorded.<br>• Aggregated or per-customer feedback is viewable in the dashboard.<br>• Feedback is associated with the correct customer. | Absent |
| G1 | Per-pump visualize + edit past days | Admin | Admin can visualize per-pump data any time and edit current or past days. | • Admin can view transaction/settlement data filtered per pump.<br>• Admin can edit current-day and past-day records.<br>• Edits persist and propagate to dependent totals. | Partial |

---

## F. Campaigns / Notifications

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| F1 | Campaign creation | Admin | Admin defines campaigns: a minimum purchase over a period earns discounts/gifts. | • Admin can create a campaign with a minimum-purchase threshold and a qualifying period.<br>• The reward is expressible as a discount or a gift.<br>• Campaigns can be listed, edited, and deactivated.<br>• Qualification can be evaluated against customer purchase history. | Absent |
| F2 | Campaign targeting | Admin | Campaigns can target an individual customer, a customer-type, or a hand-picked set. | • A campaign can target one specific customer.<br>• A campaign can target a customer-type (OTP / Credit / Drive-in).<br>• A campaign can target a manually selected set of customers.<br>• The resolved audience is reviewable before send. | Absent |
| F3 | Push for offers + loyalty bonus | Admin | Push notifications for offers and for accumulated loyalty-bonus milestones. | • The system can push an offer/campaign to a resolved, **targeted** audience.<br>• A loyalty-bonus notification can be sent when a customer's accumulated bonus reaches a milestone.<br>• A push references a concrete offer/campaign object where applicable. | Partial |
| F4 | WhatsApp / SMS notifications | Admin | Offer and loyalty notifications can also be delivered via WhatsApp and SMS. | • The system can send a notification via WhatsApp.<br>• The system can send a notification via SMS.<br>• Channel selection works alongside the same targeting as push (F2). | Absent |

---

## Users / Auth

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| A7 | Operator user record + auth | Admin | Admin sets up operator users with identity profile fields; login remains username/mobile + password. | • Operator record captures Name, **Photo**, **Address**, **Aadhaar number**, and **ID-card photo**.<br>• Login is by username or mobile + password (no OTP — Q3).<br>• Admin can create, edit, deactivate operator users.<br>• Aadhaar/ID images are stored with PII-appropriate handling. | Partial |
| A10 | Assign operator to a pump | Admin | Admin assigns an operator to a pump/nozzle (an admin-driven path, not operator self-service). | • Admin can assign a given operator to a specific pump (and nozzle where applicable).<br>• The assignment drives the FSM's default pump in capture/settlement.<br>• Assignment is performed by admin, not by the operator (couples with S-MYPUMP). | ✅ Present |

---

## Shifts

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| A8 | Create shifts (24 / 12 / 8 hr) | Admin | Admin defines shift patterns. | • 24-hr shift (6–6) is definable.<br>• 12-hr shifts (6AM–6PM, 6PM–6AM) are definable.<br>• 8-hr shifts (6–2, 2–10, 10–6) are definable.<br>• Shifts are reusable across assignments. | Present |
| A9 | Assign operator to a shift | Admin | Admin assigns operators to shifts. | • Admin can assign a given operator to a defined shift.<br>• Assignments are viewable per operator and per shift.<br>• Assignment history is retained. | Present |

---

## Staff constraints (FSM login)

| ID | Title | Source sheet | Description | Acceptance criteria | Status |
|---|---|---|---|---|---|
| S-MYPUMP | Hide "My Pump" from staff login | Staff_FSM | Operators must not self-assign their pump; the "My Pump" feature is absent from staff login. | • The "My Pump" self-assignment feature is not accessible to FSM users on any surface.<br>• The FSM's pump comes from the admin assignment (A10).<br>• Current app ships the **opposite** (My Pump is a staff feature) → requires correction. | ✅ Present |
| S-PAUSE | Remove "Pause Rewards" from staff login | Staff_FSM | Pausing rewards is an admin-only capability; it must not appear in staff login. | • FSM users cannot pause rewards (per customer or globally) on any surface.<br>• Reward pause controls are admin-only (see C4).<br>• Current app ships the **opposite** (staff can pause) → requires correction. | ✅ Present |

---

## Status roll-up

| Status | Count | IDs |
|---|---|---|
| Present | 17 | A1, A2, A3, A4, A5, A6, A8, A9, A10, C1, C2, C3, C4, C5, E2, S-PAUSE, S-MYPUMP |
| Partial | 6 | A7, B1, B2, E3, F3, G1 |
| Absent | 18 | D1, D2, D3, D4, D5, D6, D7, D8, D9, D10, E1, E4, E5, E6, E7, F1, F2, F4 |

Total: **41 features** — 17 Present, 6 Partial, 18 Absent. *(Phase 0 complete; Phase 1: **A5 Product Catalog** shipped on every surface.)*
