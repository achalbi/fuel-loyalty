# AceFuels — Product & Engineering Documentation

Detailed documentation for the **AceFuels** fuel-station loyalty + operations platform:
what the `AceFuels_Requirement.xlsx` spreadsheet asks for, what the app (Rails + PWA +
native Android) does today, and how to build the gap — as developer-ready specs.

**Status snapshot:** 41 requirement features → **11 present · 9 partial · 21 absent**.

## Locked decisions (2026-07-21)
| # | Decision | Implication |
|---|---|---|
| Q1 | **Litres = source of truth** | Capture meter readings/litres; derive ₹ from catalog price |
| Q2 | **Both surfaces in lockstep** | Every feature ships on Rails PWA **and** native Android (+ API) |
| Q3 | **Operator KYC = profile fields only** | Add Photo/Address/Aadhaar#/ID-photo; keep password login, **no OTP** |

> **Open item:** confirm the customer taxonomy — OTP = fleet/credit (litres-billed), TT = tank-truck credit, Drive-in = walk-in cash, Credit = credit account. Features E4/D5/F2 depend on it.

## How to read this set
Start at the overview, skim requirements + current architecture for context, then dive into the
per-area specs. The roadmap tells you what to build in what order.

| # | Document | What it is |
|---|---|---|
| 00 | [Product overview](00-product-overview.md) | Vision, roles, glossary, decisions, scope |
| 01 | [Functional requirements](01-functional-requirements.md) | Every feature ID with acceptance criteria + status |
| 02 | [Current architecture](02-current-architecture.md) | As-built map (models, controllers, services, Android), cited |
| 03 | [Target data model](03-target-data-model.md) | New/changed tables & columns; consolidated ER diagram |
| — | **Feature specs** | current state → target design → API → UI → acceptance |
| 10 | [Product catalog + stock](10-spec-product-catalog.md) | Priced products (fuel + lubes/AdBlue), MRP, batch, inventory — **keystone** |
| 11 | [Litres / readings model](11-spec-litres-readings.md) | Litres capture, ₹ derivation, reward reconciliation |
| 12 | [Daily settlement](12-spec-daily-settlement.md) | Shift-end reconciliation — the largest module (D1–D10) |
| 13 | [Customer master + capture](13-spec-customer-crm-capture.md) | Driver/owner/transport, contacted, customer type, FSM per-visit form |
| 14 | [Rewards + staff constraints](14-spec-rewards-staff-constraints.md) | Global pause, admin pump assignment, staff-login corrections — **quick wins** |
| 15 | [Dashboard + reports](15-spec-dashboard-reports.md) | Drill-through, cadence, customer-type, churn, feedback, reporting |
| 16 | [Campaigns + notifications](16-spec-campaigns-notifications.md) | Campaign engine, targeting, push/WhatsApp/SMS, token linkage |
| 17 | [Operator KYC](17-spec-operator-kyc.md) | Profile fields, ActiveStorage, PII handling (no OTP) |
| 20 | [API contracts](20-api-contracts.md) | All new/changed JSON endpoints for Android |
| 30 | [Implementation roadmap](30-implementation-roadmap.md) | Phased plan, dependencies, effort, biggest changes |
| 40 | [Gap analysis](40-gap-analysis.md) | The audit companion — full present/partial/absent matrix |

## Feature ID map
`A1–A10` setup/users/shifts · `B1–B2` customer capture · `C1–C5` rewards ·
`D1–D10` daily settlement · `E1–E7` dashboard/CRM/reports · `F1–F4` campaigns/notifications ·
`G1` per-pump visualize+edit · `S-MYPUMP` / `S-PAUSE` staff-login constraints.

---
*Source: `AceFuels_Requirement.xlsx` (7 sheets). Specs cite `file:line` against the repo as of 2026-07-21.*
