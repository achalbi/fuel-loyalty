# AceFuels Requirement → App Gap Analysis

Source: `AceFuels_Requirement.xlsx` (7 sheets) vs. the current app
(Rails backend + PWA views, and the native **Android** app under `android/`).
Generated 2026-07-21.

**Score: 41 atomic features assessed — 17 present ✅ · 6 partial 🟡 · 18 absent ❌.**

> **Phase 1 in progress:** ✅ **A5 Product Catalog** shipped (all surfaces — priced catalog + admin CRUD, 14 rows seeded, tested).

> **Phase 0 complete ✅ (2026-07-21):** shipped on all surfaces, tested — **C4 global pause** · **S-PAUSE** · **fuel types → MS/HSD** · **S-MYPUMP** · **A10 admin pump assignment** · **E2 dashboard drill-through**. Next: Phase 1 foundations (Product Catalog, litres model, customer expansion, push-token linkage).

> Every verdict below was cross-checked against the code (file:line evidence held
> in the audit run). Where the app does something *differently* than the sheet, it
> is called out rather than glossed as "done".

---

## 1. Three structural facts that shape everything

1. **The app is rupees-centric; the spreadsheet is litres-centric.**
   A transaction stores `fuel_amount` in **₹**, not litres (`docs/native-handoff/02-data-model.md:80` says explicitly "₹ amount, not litres"). Rewards accrue per ₹100. The requirement's **Daily Settlement** and **CustomerDetailsEntry** are built on **meter readings → litres → price**. Bridging the two is the single biggest architectural decision (see §5, Q1).

2. **There is no product pricing anywhere.** Fuel types have only `code`/`name` — **no MRP, no selling price, no batch, no stock**. There is no representation of lubricants/oils/AdBlue. This "Product Catalog" (Req A5) is the **keystone dependency** — Settlement, Reports and litres-based capture all need it.

3. **The app already exceeds the sheet in one area: shifts & attendance.** The sheet only asks to *create shifts and assign operators*. The app has that **plus** shift cycles, shift swaps, attendance runs with override/audit history. That subsystem is a strength, not a gap.

---

## 2. The requirement, by sheet (feature inventory)

| Sheet | What it defines |
|---|---|
| **Users** | Two roles: Admin, Pump Operator/FSM |
| **Admin** | 17 admin capabilities: pump/nozzle/product/vehicle-type setup, operator setup + auth, shifts, customer master, reward settings, settlement view/edit, reports, campaigns, notifications, CRM dashboard |
| **Staff_FSM** | FSM does Daily Settlement (shift-end) + Customer Details capture (many/day). Constraints: "My Pump" hidden from staff; "Pause Rewards" not in staff login |
| **PumpsNozzlesProductsSetup** | Pump→nozzle→fuel map, and a **priced product catalog**: HSD/MS + ~12 lubes/oils/AdBlue with batch, MRP, selling price |
| **CustomerDetailsEntry** | Per-visit FSM form: date, vehicle#, driver name/mobile, **litres filled**, pump#, **discount**, **Fleet/OTP flag**, transport/manager/owner details, approx # of vehicles |
| **DailySettlement** | Shift-end reconciliation: per-nozzle readings, testing litres, net litres, price, amount; lubes w/ qty & stock; discounts; PhonePe POS & Scanner; Fleet/OTP & TT credit; final-amount-to-settle; cash denomination count + shortage |
| **DailySettlementSample** (image) | A filled "ACE FUELS" settlement showing totals-by-fuel, per-FSM payments, OTP/TT credit lines, lubes w/ opening/closing stock, cash count, per-pump shortage, **stock received** & **decantation** (tank KL) |

---

## 3. Comparison matrix

### ✅ Present (17) — usable today
| ID | Feature | Note |
|---|---|---|
| A5 | Product catalog (fuel + lubes/AdBlue, MRP, selling price, batch) | ✅ **Shipped (Phase 1)** — priced `products` model (categories, fuel-type linkage, `Product.fuel_price_for`), 14 rows seeded, admin CRUD web + API + Android. The settlement pricing source. Stock ledger deferred to Phase 2 (D2/D8) |
| C4 | Pause rewards globally | ✅ **Shipped (Phase 0)** — global "Pause All Rewards" switch on reward settings zeroes accrual for everyone; per-customer pause still applies on top |
| E2 | Dashboard → customers by period | ✅ **Shipped (Phase 0)** — "View customers" drill-through (web + Android) opens a period-scoped customer list via `Customer.transacted_between` |
| A10 | Assign operator to a pump | ✅ **Shipped (Phase 0)** — admin "Assign Pump" flow (web + API + Android) reusing `update_pump_assignment`; staff self-service removed |
| S-PAUSE | Pause rewards not in staff login | ✅ **Shipped (Phase 0)** — pause/resume gated admin-only in `CustomerPolicy`; staff lose the buttons (web) and the control is hidden in the Android profile; admin keeps it |
| S-MYPUMP | Hide "My Pump" from staff login | ✅ **Shipped (Phase 0)** — self-service pump assignment is admin-only; nav link, staff transaction control (web) and Android account tile are hidden from staff |
| A1 | Setup number of pumps | Full CRUD, web + Android + API |
| A2 | Set up nozzles | Nested under pump, auto-sequenced |
| A3 | Assign nozzles to pumps | Inherent in pump→nozzle model |
| A4 | Assign product (MS/HSD) per nozzle | Per-nozzle **fuel type** works; defaults now read **MS (Petrol)** / **HSD (Diesel)** ✅ (Phase 0, codes unchanged). No *price* attached — that's A5 |
| A6 | Vehicle types 2W/3W/LMV/LCV/MCV/HCV | Exact six defaults + CRUD + per-type reward config |
| A8 | Create shifts (24/12/8 hr) | Shift templates; app also has cycles/swaps/attendance |
| A9 | Assign operator to a shift | Shift assignments + cycles |
| C1 | Cash reward per ₹100 / x ₹ | `rupees_per_reward_unit` + `cash_value_per_point` |
| C2 | Reward by vehicle type | `vehicle_type_reward_offers` / per-type points |
| C3 | Reward by fuel type | `fuel_reward_rates` |
| C5 | Accumulated loyalty bonus | Points ledger + cash value |

### 🟡 Partial (6) — exists but doesn't fully meet the sheet
| ID | Feature | What's missing |
|---|---|---|
| A7 | Operator user record + auth | Only **Name** exists. **No Photo, Address, Aadhaar #, ID-card photo**. → **Decision: add these profile fields; keep username/mobile + password (no OTP).** Needs ActiveStorage for 2 images + PII handling |
| B1 | Customer master details | Have: name + single phone + (commercial vehicles only) one owner/manager contact. **Missing:** separate Driver / Supervisor / Owner name+mobile triple, and the **"Contacted-by" checkbox + info button** |
| B2 | FSM per-visit CustomerDetailsEntry | No dedicated form. Overlaps only on vehicle# + pump#. **Missing:** litres, discount, Fleet/OTP flag, driver/transport/manager/owner, approx # of vehicles, editable date |
| E3 | Visit-frequency analysis | Has a visits-distribution chart, but **no per-customer last-visit + daily/weekly/biweekly cadence** |
| F3 | Push for offers + loyalty bonus | FCM broadcast + scheduled push work, but sends are **untargeted broadcasts**, there's **no offer object** to attach, and **nothing auto-pushes** a loyalty-bonus milestone |
| G1 | Visualize per-pump data + edit past days | Transactions list is **view-only** (no edit), and has **no per-pump filter**. "Edit current/past days" not implemented |

### ❌ Absent (18) — not built
**Daily Settlement (the biggest single gap — 9 features, all missing):**
| ID | Feature |
|---|---|
| D1 | Per-nozzle settlement entry (today/yesterday reading auto-pop, testing, net litres, price auto, amount) |
| D2 | Lubes in settlement (checkbox, qty, amount, **opening/closing stock**) |
| D3 | Discounts pulled from customer entries into settlement |
| D4 | PhonePe POS + PhonePe Scanner amounts |
| D5 | Fleet/OTP + TT (tank-truck) credit lines |
| D6 | Final-amount-to-settle calculation |
| D7 | Cash denomination breakdown + **shortage** per pump |
| D8 | Stock received (MS/HSD) + decantation (tank KL) |
| D9 | Admin view/edit settlement per pump & across pumps, incl. past days |
| D10 | Rate comparison (competitor JIO-BP vs own price) |

**Catalog, CRM, campaigns, reports, notifications, staff constraints:**
| ID | Feature |
|---|---|
| E1 | Reports daily/weekly/monthly/**yearly** per vehicle/transporter/driver (litres, discount, gifts) |
| E4 | Customer-type view: **OTP(Fleet) / Drive-in / Credit** |
| E5 | Contact tracking + probability of conversion |
| E6 | Intelligent **lost-customer / churn** feedback ("who to reach out to") |
| E7 | Customer feedback / rating |
| F1 | **Campaign** creation (min purchase per period → discount/gift) |
| F2 | Campaign **targeting**: individual / customer-type / selected customers |
| F4 | **WhatsApp / SMS** notifications |

> Note: **S-MYPUMP and A10 both shipped in Phase 0** — self-service pump assignment
> is now admin-only and hidden from staff, and admins assign an operator's pump via
> an "Assign Pump" flow on all three surfaces (web + API + Android), so the staff
> transaction flow still resolves an assigned pump.

---

## 4. Dependency map (why order matters)

```
A5 Product Catalog (prices, lubes, stock)  ─┬─► D1/D2 Settlement pricing & lubes
                                            ├─► E1  Reports (₹/litre, product mix)
Litres decision (Q1) ───────────────────────┴─► B2  Litres capture ─► D1 readings

Customer model expansion (B1/B2) ─┬─► E4 Customer type (OTP/Drive-in/Credit)
  (driver/owner/transport, type)  ├─► D5 Fleet/OTP & TT credit lines
                                  ├─► E1 per-transporter/driver reports
                                  └─► F2 campaign targeting

Push token ↔ customer link ───────┬─► F2 targeted send
                                  └─► F3 auto loyalty-bonus push
F1 Campaign object ───────────────┴─► F3 offer push

E3 cadence baseline ──────────────────► E6 churn / "who to reach out to"
```

Four foundations unlock most of the backlog: **(1) Product Catalog**, **(2) the litres decision**, **(3) an expanded customer model with a customer-type**, **(4) a push-token↔customer link**.

---

## 5. Priority roadmap

> **Locked decisions (2026-07-21):**
> **(Q1) Litres = source of truth** — capture meter readings/litres and derive ₹ from catalog price. This makes A5 (catalog) + the litres/readings model the top of Tier 1, and reshapes B2/D1/E1.
> **(Q2) Both surfaces in lockstep** — every feature lands in Rails PWA **and** native Android (+ API). Budget ~1.5–2× per-feature effort accordingly.
> **(Q3) Operator KYC = profile fields only** — add Photo/Address/Aadhaar#/ID-photo (ActiveStorage + PII handling); **keep password login, no OTP/SMS**. A7 drops from High → **Medium**.

### Tier 0 — Quick wins & corrections (low effort, do first)
| ID | Feature | Effort | Why now |
|---|---|---|---|
| A4 | Rename/seed fuel types to **MS/HSD** | XS | Config only; makes the app read like the sheet |
| S-PAUSE | Remove Pause-Rewards from staff | S | Policy change + drop staff route/button |
| C4 | **Global** pause-rewards switch | S | One flag on `reward_settings` + one accrual check |
| A10 + S-MYPUMP | Move pump assignment to **admin**, hide "My Pump" from staff | S–M | Model already supports it; do the pair together |
| E2 | Make dashboard tiles/leaderboard **click through** to a period-filtered customer list | M | Reuses existing data; high perceived value |
| D10 | Rate comparison (own vs competitor price) | S | Small, but only meaningful once A5 exists |

### Tier 1 — Foundations (unblock the rest)
| ID | Feature | Effort | Unlocks |
|---|---|---|---|
| A5 | **Product Catalog** (fuel + lubes/AdBlue, MRP, selling price, batch, stock) | H | D1, D2, E1, B2 |
| — | **Litres/readings model** — add litres to transactions, derive ₹ from catalog price (decided Q1) | M–H | D1, B2, E1 |
| B1/B2 | Expand **customer model** (driver/supervisor/owner + contacted + transport + **customer type** + Fleet/OTP flag) & FSM capture form | H | E1, E4, D5, F2 |
| F2-prep | **Push-token ↔ customer** opt-in link | M | F2, F3 |

### Tier 2 — Major new subsystems
| ID | Feature | Effort |
|---|---|---|
| D1–D9 | **Daily Settlement** module (readings, lubes+stock, discounts, PhonePe, credit lines, final settle, cash count+shortage, stock/decantation, admin view/edit) | Very high |
| E1 | **Reporting** subsystem (periodic, per vehicle/transporter/driver, exportable) | High |
| F1/F2 | **Campaign** engine + targeting | High |
| A7 | **Operator profile fields**: Photo/Address/Aadhaar#/ID-photo (ActiveStorage + PII); password login kept, no OTP (decided Q3) | Medium |
| F4 | **WhatsApp / SMS** channel (new provider) | M–H |

### Tier 3 — Intelligence / advanced CRM
| ID | Feature | Effort |
|---|---|---|
| E4 | Customer-type dashboard view | M |
| E3 | Per-customer visit cadence | M |
| E7 | Customer feedback / rating | M |
| E5 | Contact tracking + conversion probability | H |
| E6 | Churn detection / "who to reach out to" | H |

### "Biggest change" ranking (by effort × ripple)
1. **Daily Settlement** subsystem — largest single build (9 features), depends on almost everything else.
2. **Rupees → Litres** model shift — ripples into rewards, capture, reports.
3. **Product Catalog + inventory/stock** — new priced entity, the keystone.
4. **Campaign engine + targeting** — new model + segmentation + per-recipient send.
5. **Reporting** subsystem — new pipeline + several missing data captures.
6. **OTP auth + Aadhaar PII** — new auth strategy + compliance/storage.
7. **CRM intelligence** (churn, conversion, cadence) — new analytics + surfaces.
8. **WhatsApp/SMS** — external integration + templates/opt-in.

Every gap requires **backend + at least one client** (Rails PWA and/or native Android), so each lands in 2–3 surfaces.

---

## 6. Decisions & remaining open item
**Resolved 2026-07-21:**
- **Q1 — Units:** ✅ Move to **litres/readings** as source of truth; derive ₹ from catalog price.
- **Q2 — Surface:** ✅ **Both** Rails PWA and native Android in lockstep (+ API).
- **Q3 — Operator KYC:** ✅ **Profile fields only** (Photo/Address/Aadhaar#/ID-photo); keep password login, no OTP/SMS.

**Still open:**
- **Domain terms (inferred, please confirm):** OTP = fleet/credit account customers (billed by litres, not "one-time password"); TT = **tank-truck** credit; Drive-in = walk-in cash; Credit = credit-account. Features E4/D5/F2 depend on this taxonomy.
