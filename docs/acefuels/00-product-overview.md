# AceFuels — Product Overview

> **Status:** Foundational spec. This is the entry-point document for the AceFuels
> program. Read it first; every other doc in `docs/acefuels/` builds on the
> vocabulary, roles, and locked decisions defined here.

---

## 1. Product vision

**AceFuels** is a fuel-station loyalty **and** operations platform. It runs a
single fuel outlet's day-to-day: the operators who work the pumps, the customers
who fuel up, the rewards those customers earn, and the shift-end money-and-fuel
reconciliation that keeps the outlet honest.

Two things make AceFuels more than a punch-card loyalty app:

1. **Litres are the source of truth.** The platform is built around physical
   nozzle meter-readings and litres dispensed. Rupee amounts are *derived* from
   the product catalog's selling price — not typed in as the primary fact. This
   is what lets rewards, settlement, and reports all reconcile against the same
   physical reality.
2. **Operations and loyalty share one dataset.** The same customer visit that
   awards loyalty points also feeds the daily settlement, the churn dashboard,
   and the campaign engine. Capture once, use everywhere.

The near-term goal is to take the existing loyalty app (which today records only
a rupee `fuel_amount` per transaction) and grow it into the full operations
platform described across these docs — on **every** surface the outlet uses.

---

## 2. The two roles

AceFuels has exactly two user roles. Everything in the product is framed as
"what the Admin does" or "what the FSM does".

| Role | Also called | Who they are | What they do |
| --- | --- | --- | --- |
| **Admin** | Owner / Manager | The outlet owner or manager | Sets up the outlet (pumps, nozzles, products, vehicle types, staff, shifts); configures reward rules; runs campaigns and notifications; views and edits daily settlements and per-pump data; reads the dashboard, CRM, and reports. |
| **FSM** | Pump Operator, Forecourt Service Member | The person working the forecourt | Captures customer details at the pump many times a day; files the **Daily Settlement** at shift end (nozzle readings, lubes sold, discounts, digital payments, cash denominations, shortages). |

### Role boundaries (constraints)

Two capabilities that exist for the Admin are **explicitly denied** to the FSM
login. These are hard requirements, not preferences:

- **"My Pump" self-assignment is DISABLED in the FSM login.** Operators do not
  pick their own pump; the Admin assigns it. *(Today's app does the opposite —
  see feature `S-MYPUMP` in the gap analysis.)*
- **"Pause rewards" is NOT available in the FSM login.** Only the Admin can pause
  a customer's or the outlet's rewards. *(Today's app does the opposite — see
  `S-PAUSE`.)*

---

## 3. Glossary

New readers should skim this before the feature docs. Terms marked **(assumed,
to confirm)** are our current interpretation and must be validated with the
outlet before we build against them.

| Term | Meaning |
| --- | --- |
| **FSM** | *Forecourt Service Member* — the pump operator. The non-admin role. |
| **Nozzle** | The individual fuel gun. Each nozzle dispenses one fuel type and has a running meter (totalizer) reading. A pump has several nozzles. |
| **Pump** | A dispenser unit on the forecourt. Holds multiple nozzles. Example layout: `P1[N1 HSD, N2 HSD] P2[N3 HSD, N4 MS] P3[N5 HSD, N6 HSD, N7 MS, N8 MS]`. |
| **MS** | *Motor Spirit* — petrol. |
| **HSD** | *High-Speed Diesel* — diesel. |
| **Lube** | Lubricant / engine-oil product sold alongside fuel (e.g. 2T oils, 10W30, Milex). Sold by the unit from the product catalog. |
| **AdBlue** | Diesel-exhaust fluid (urea solution) sold in 5L / 10L / 20L packs. A catalog product like a lube. |
| **Meter reading / totalizer** | The cumulative litres a nozzle has ever dispensed. Litres sold in a shift = today's reading − yesterday's reading, minus testing litres. |
| **Testing litres** | Litres pumped out for calibration/testing and pumped back — subtracted from litres sold so they aren't billed. |
| **Decantation** | Unloading fuel from a delivery tank-truck into the outlet's underground storage tanks; tracked via tank KL (kilo-litre) readings. |
| **Daily Settlement** | The shift-end reconciliation an FSM files per pump: fuel sold + lubes sold, minus discounts and digital payments, reconciled against counted cash. |
| **PhonePe POS** | Payments taken on the physical PhonePe card **machine** at the pump. |
| **PhonePe Scanner** | Payments taken by the customer scanning a PhonePe **QR code**. Tracked separately from POS. |
| **TT** | *Tank-Truck* credit — fuel supplied on credit to a tank-truck, recorded as a credit line (litres + discount, e.g. "OTP 136 Lts NL-01/AE-2471"). |

### Customer taxonomy — **assumed, to confirm**

The requirement refers to customer *types* — **OTP / Fleet**, **TT**,
**Drive-in**, **Credit** — but never defines them. Our working interpretation,
which **must be confirmed with the outlet before we build type-specific logic**:

| Type | Assumed meaning (to confirm) |
| --- | --- |
| **OTP / Fleet** | Fleet/credit accounts billed by litres. **"OTP" here is assumed to mean the fleet-account customer type, NOT a one-time-password.** |
| **TT** | Tank-truck credit customers (fuel on credit to a tanker). |
| **Drive-in** | Walk-in retail customers paying cash/card on the spot. |
| **Credit** | Credit-account customers billed periodically. |

---

## 4. Platform shape

AceFuels ships every feature on a common backend with three client surfaces.

```
                        ┌─────────────────────────────┐
                        │   Rails server (source of    │
                        │   truth: DB, business logic, │
                        │   points, settlement calc)   │
                        └──────────────┬──────────────┘
                          server-rendered │ serves
                    ┌───────────────┐     │     ┌──────────────────┐
                    │  PWA views    │◀────┼────▶│   JSON API (v1)  │
                    │ (Rails HTML,  │     │     │  token-auth      │
                    │  installable) │     │     └────────┬─────────┘
                    └───────────────┘     │              │ backs
                                          │     ┌────────▼─────────┐
                                          │     │  Native Android  │
                                          │     │ (Kotlin/Compose) │
                                          └─────┴──────────────────┘
```

| Layer | Technology | Notes |
| --- | --- | --- |
| **Server** | Ruby on Rails | Owns the database, business logic (points accrual, settlement math), and both the server-rendered views and the API. |
| **PWA** | Rails-rendered HTML views | Installable progressive web app; the browser-based Admin + FSM experience. |
| **Native Android** | Kotlin + Jetpack Compose | Under `android/`. Consumes the JSON API. Currently at versionCode 5 / v1.1.1. |
| **JSON API** | `api/v1/*`, token auth | Mirrors the web controllers; the contract that backs Android. |

---

## 5. The three LOCKED DECISIONS

These decisions were locked on **2026-07-21**. Every feature doc must honor them
verbatim. They are reproduced here word-for-word.

> **Q1 UNITS:** Litres/meter-readings are the SOURCE OF TRUTH. Capture
> readings/litres; DERIVE ₹ from the product-catalog selling price. (Today
> transactions store only ₹ fuel_amount.)

> **Q2 SURFACES:** Build EVERY feature on BOTH the Rails PWA and the native
> Android app (Kotlin/Compose), plus the JSON API that backs Android. Specs must
> describe both surfaces.

> **Q3 OPERATOR KYC:** Add operator PROFILE FIELDS ONLY — Photo, Address, Aadhaar
> number, ID-card photo (ActiveStorage for the two images + PII handling). KEEP
> username/mobile + password login. NO OTP / SMS provider.

### What each decision implies

| Decision | Implications for the build |
| --- | --- |
| **Q1 — Litres are truth** | A **product catalog with selling prices** (feature A5) becomes a prerequisite for almost everything downstream. Transactions/settlements must store litres and readings; ₹ is a derived, recomputable value. The current `transactions.fuel_amount`-only model must be extended, and reward accrual must be re-expressed against litres/₹ derived from the catalog. |
| **Q2 — Both surfaces** | No feature is "web-only" or "Android-only". Each feature spec describes the PWA view, the Compose screen, **and** the API endpoints that connect them. Parity is a shipping requirement, not a follow-up. |
| **Q3 — Profile-only KYC** | Operator records gain Photo, Address, Aadhaar number, and ID-card photo (two images via ActiveStorage, with PII handling). Login stays **username/mobile + password**. **No OTP, no SMS provider is in scope this phase** — the requirement's "login by mobile + OTP" is deliberately deferred. |

---

## 6. Scope & non-goals

### In scope (this program)

- The full Admin setup surface: pumps, nozzles, nozzle→pump assignment,
  fuel-type-per-nozzle, **product catalog with MRP + selling price** (incl. lubes
  and AdBlue), vehicle types, operator profiles (with KYC fields), shifts, and
  shift/pump assignment.
- Customer master and per-visit customer capture keyed on litres.
- Reward configuration (per ₹, by vehicle type, by fuel type, global + per-customer pause).
- The full **Daily Settlement** workflow for the FSM, and Admin view/edit of it.
- Dashboard, CRM (contact tracking, churn/lost-customer, cadence, feedback),
  and daily/weekly/monthly/yearly reports.
- Campaigns and notifications (push in-scope; WhatsApp/SMS tracked as a feature).

### Explicit non-goals (this phase)

- **No OTP / mobile-OTP login and no SMS provider.** Login is username/mobile +
  password only (per Q3). The requirement's OTP login is deferred.
- **No re-interpretation of the customer taxonomy without confirmation.** The
  OTP/TT/Drive-in/Credit meanings in §3 are assumptions to validate, not settled
  facts to build type-specific billing on yet.
- **Single-outlet scope.** The platform models one fuel station; multi-outlet /
  franchise rollout is out of scope for this program.

---

## 7. How these docs are organized

All AceFuels docs live in `docs/acefuels/`. Feature IDs (A1–A10, B1–B2, C1–C5,
D1–D10, E1–E7, F1–F4, G1, plus the S-MYPUMP / S-PAUSE staff constraints) are
**shared across every doc** so a feature can be traced from requirement to gap to
spec.

| Document | What it covers |
| --- | --- |
| **`00-product-overview.md`** *(this file)* | Vision, roles, glossary, platform shape, locked decisions, scope. The entry point. |
| **`40-gap-analysis.md`** | The verified as-built audit: which of the 41 features are Present / Partial / Absent today, and the delta to the requirement. |

> The remaining per-area feature specs (setup, customer capture, rewards, daily
> settlement, dashboard/CRM/reports, campaigns/notifications) are authored as
> companion docs and reference the same feature IDs. As each is written it is
> added to the table above.

### Feature-ID map (quick reference)

| ID range | Area |
| --- | --- |
| **A1–A10** | Outlet setup: pumps, nozzles, product catalog, vehicle types, operator profiles, shifts, assignments. |
| **B1–B2** | Customer master (B1) and per-visit customer capture (B2). |
| **C1–C5** | Reward settings and loyalty accrual. |
| **D1–D10** | The Daily Settlement workflow (readings, lubes, discounts, digital payments, cash denominations, shortage, stock, decantation, rate comparison, admin view/edit). |
| **E1–E7** | Dashboard, reports, CRM: customer types, contact tracking/conversion, churn, feedback. |
| **F1–F4** | Campaigns (F1), targeting (F2), push (F3), WhatsApp/SMS (F4). |
| **G1** | Per-pump visualize + edit of current and past days. |
| **S-MYPUMP / S-PAUSE** | FSM-login constraints: "My Pump" disabled, "Pause rewards" absent. |
