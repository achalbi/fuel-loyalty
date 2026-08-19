# AceFuels — Consolidated JSON API Contracts (native Android)

Status: spec. Scope: every **new** and **changed** `/api/v1` endpoint required by the AceFuels feature specs (00–19). This doc is the single source of truth for the Kotlin/Compose client's networking layer and the Rails `Api::V1::*` controllers/serializers that back it. Web PWA parity is assumed (Q2); this doc describes only the JSON surface.

Feature IDs referenced throughout: A1–A10, B1–B2, C1–C5, D1–D10, E1–E7, F1–F4, G1, S-MYPUMP, S-PAUSE (see `01-functional-requirements.md`).

---

## 0. Conventions (all endpoints honor these)

These mirror the as-built `Api::V1::BaseController` and must not be re-invented per endpoint.

| Concern | Contract |
|---|---|
| Base URL | `/api/v1` |
| Namespaces | `/api/v1/staff/*` = authenticated **admin OR staff**; `/api/v1/admin/*` = **admin only** (`ensure_admin`); unscoped `/api/v1/*` = any authenticated user (own record) |
| Auth | `Authorization: Bearer <access_token>` on every call except `auth/login`, `auth/refresh`, `auth/logout`. Tokens from `POST /api/v1/auth/login`. |
| Request body | JSON, `Content-Type: application/json`. **Body is nested under the resource key** (`resource_params` helper): e.g. `{ "settlement": { … } }`, `{ "customer": { … } }`. Top-level flat is tolerated as a fallback but nested is canonical. GET filters are flat query params. |
| File upload | KYC images (A7) use `multipart/form-data` with `user[photo]`, `user[id_card_photo]`. All other write bodies are JSON. |
| Money / litres | Per **Q1**, litres & meter readings are the source of truth; ₹ amounts are **derived** server-side from the product-catalog selling price. Clients send litres/readings; server returns both litres and the derived `amount`. Decimals serialize as JSON numbers (`.to_f`). |
| Timestamps | ISO-8601 strings (`created_at`, `starts_at`, …). Dates as `YYYY-MM-DD`. |
| Pagination | Envelope `{ "<items>": [...], "page": Int, "per_page": Int, "total": Int, "has_more": Bool }`. `page` query param, 1-based. |
| Success codes | `200` read/update, `201` create, `204` no-content (logout/destroy). |
| Error envelope | `{ "error": { "code": String, "message": String, "details": { field: [msgs] } } }` — `details` present only on validation failures. |

### Standard error codes (from `BaseController`, reusable everywhere)

| HTTP | `code` | When |
|---|---|---|
| 400 | `parameter_missing` | required top-level param absent |
| 401 | `unauthorized` / `invalid_credentials` | missing/invalid bearer token; bad login |
| 403 | `forbidden` / `account_inactive` | Pundit denial; admin-only hit by staff; inactive account |
| 404 | `not_found` / `customer_not_found` / `vehicle_not_found` | record missing |
| 409 | `delete_restricted` | destroy blocked by dependent history |
| 422 | `validation_failed` (+ `details`) | model validation; also `invalid_phone`, `invalid_vehicle`, `invalid_points`, `configuration_error` |

Endpoint sections below list **only endpoint-specific** error cases; the standard set above always applies.

---

## Endpoint index

| # | Area | Feature | New / Changed |
|---|---|---|---|
| 1 | Product catalog | A5 | New (admin CRUD) + Changed (`staff/catalog`) |
| 2 | Litres-based transactions | Q1, D1, C5 | Changed (`staff/transactions`) |
| 3 | Daily Settlement | D1–D10, G1 | New |
| 4 | Customer capture (per-visit) | B2 | New |
| 5 | Customer master (driver/supervisor/owner + type) | B1, E4 | Changed |
| 6 | Global reward pause | C4 | Changed (`admin/reward_rates`) |
| 7 | Admin pump assignment | A10 | New |
| 8 | Dashboard drill-through / cadence / type / churn | E2–E6 | Changed + New |
| 9 | Campaigns | F1, F2 | New |
| 10 | Notifications + targeting | F3, F4 | Changed + New |
| 11 | Operator KYC | A7 | Changed (`admin/users`, multipart) |
| 12 | Reports | E1 | New |
| 13 | Customer feedback / rating | E7 | New |

---

## 1. Product catalog (A5)

Adds a first-class product catalog (fuels + lubricants/oils + AdBlue) with batch, MRP, selling price, and stock. Selling price is the number `TransactionCreator`/settlement read to derive ₹ from litres/qty.

**Model note:** new `products` table — `sl_num`, `name`, `category` (`fuel`|`lubricant`|`adblue`), `batch`, `unit_label` (e.g. `"20ml"`, `"5L"`, `"litre"`), `mrp` (decimal), `selling_price` (decimal), `fuel_type_code` (nullable FK, set for fuels), `current_stock` (decimal), `active` (bool).

### 1.1 `GET /api/v1/admin/products` — list — **New**
Auth: admin. Purpose: catalog management screen.

Query (all optional): `category` (`fuel`|`lubricant`|`adblue`), `active` (`true`/`false`), `q`.

Response `200`:
```json
{
  "products": [
    {
      "id": 12, "sl_num": 6, "name": "10W30 800ml", "category": "lubricant",
      "batch": "B-2207", "unit_label": "800ml",
      "mrp": 380.0, "selling_price": 350.0,
      "fuel_type_code": null, "current_stock": 42.0, "active": true,
      "created_at": "2026-07-21T09:00:00Z"
    }
  ]
}
```

### 1.2 `POST /api/v1/admin/products` — **New**
Auth: admin. Body:

| field | type | req | notes |
|---|---|---|---|
| `name` | string | yes | |
| `category` | enum | yes | `fuel`\|`lubricant`\|`adblue` |
| `batch` | string | no | |
| `unit_label` | string | yes | |
| `mrp` | number | yes | ≥ 0 |
| `selling_price` | number | yes | ≥ 0 |
| `fuel_type_code` | string | cond | required when `category=fuel`, must match a `FuelType.code` |
| `current_stock` | number | no | default 0 |
| `active` | bool | no | default true |

```json
{ "product": { "name": "AdBlue 10L", "category": "adblue", "unit_label": "10L", "mrp": 1080.0, "selling_price": 1080.0 } }
```
Response `201`: single `product` object (as 1.1). Errors: `422 validation_failed` (blank name, negative price, `fuel_type_code` not found / missing for fuel).

### 1.3 `PATCH /api/v1/admin/products/:id` — **New**
Auth: admin. Body: any subset of 1.2 fields under `product`. Response `200` product. Errors: `404 not_found`, `422`.

### 1.4 `DELETE /api/v1/admin/products/:id` — **New**
Auth: admin. Response `200 { "message": "… removed successfully." }`. Errors: `409 delete_restricted` when settlement lube lines reference it (prefer soft-deactivate via 1.3 `active:false`).

### 1.5 `GET /api/v1/staff/catalog` — **Changed**
Existing response returns `fuel_types` + `vehicle_kinds`. **Add** `products` (selling price + stock) so the FSM settlement and transaction screens can price litres/qty and show lube checkboxes.

Response `200` (added key in **bold**):
```json
{
  "fuel_types": [ { "code": "ms", "label": "MS (Petrol)" } ],
  "vehicle_kinds": [ { "code": "lcv", "label": "LCV", "commercial": true } ],
  "products": [
    { "id": 1, "name": "HSD", "category": "fuel", "fuel_type_code": "hsd", "unit_label": "litre", "selling_price": 98.95, "current_stock": 12000.0 },
    { "id": 6, "name": "10W30 800ml", "category": "lubricant", "unit_label": "800ml", "selling_price": 350.0, "current_stock": 42.0 }
  ]
}
```
No new error cases (still authorized as `Customer :create?`).

---

## 2. Litres-based transactions (Q1 / D1 / C5) — **Changed**

`POST /api/v1/staff/transactions` today accepts `fuel_amount` (₹) only. Per Q1, the client sends **litres** (and optionally the nozzle meter reading); the server derives `fuel_amount = litres × selling_price(nozzle.fuel_type)` and awards points on the derived ₹ exactly as `TransactionCreator` does today.

### 2.1 `POST /api/v1/staff/transactions` — **Changed**
Auth: staff/admin. Body (`transaction`), changed/added fields in **bold**:

| field | type | req | notes |
|---|---|---|---|
| `lookup_mode` | enum | yes | `phone`\|`vehicle` (unchanged) |
| `phone_number` / `vehicle_number` / `vehicle_id` | string/int | cond | customer resolution (unchanged) |
| **`litres`** | number | cond | **new** — primary quantity; required unless `fuel_amount` sent |
| **`nozzle_reading`** | number | no | **new** — meter reading at fill; stored for reconciliation with settlement |
| `fuel_amount` | number | cond | now **optional/derived**; if omitted, computed from `litres × selling_price`. If both sent and inconsistent → `422 amount_litres_mismatch` |
| `fuel_pump_id` / `fuel_pump_nozzle_id` | int | cond | as today; nozzle drives the price/fuel type |
| `payment_mode` | enum | yes | `cash`\|`credit` |
| `discount_amount` | number | no | comes off the fuel amount; points accrue on the net |
| **`fleet_otp`** | bool | no | **item 2** — the visit detail folded in from the retired Capture Visit post |
| **`transport_name`** / **`approx_vehicle_count`** | string/int | no | **item 2** |
| **`driver_name`** / **`driver_phone_number`** | string | no | **item 2** — upserts a customer contact |
| **`manager_name`** / **`manager_phone_number`** | string | no | **item 2** |
| **`owner_name`** / **`owner_phone_number`** | string | no | **item 2** |

**Item 2 — one capture, both records.** This endpoint records the loyalty
transaction *and* the visit entry from a single post (`CounterEntry`), so the
client no longer chooses between two screens. Two cases produce only one record,
and neither is an error: an unregistered plate yields a visit with no
transaction, and a fuel with no catalog selling price yields the sale alone with
`visit_skipped_reason` set. `POST /api/v1/staff/visit_entries` is unchanged for a
caller that wants a visit-only capture.

```json
{ "transaction": { "lookup_mode": "vehicle", "vehicle_id": 88, "litres": 35.5, "nozzle_reading": 104233.5, "fuel_pump_nozzle_id": 5, "payment_mode": "cash", "fleet_otp": true, "transport_name": "NL Roadways", "driver_name": "Manoj", "driver_phone_number": "9800011122" } }
```
Response `201` (added fields in **bold**):
```json
{
  "points_earned": 35, "rewards_paused": false, "new_total": 420,
  "message": "+35 reward points added. Balance updated to 420.",
  "customer": { "…CustomerLookupSerializer…": true },
  "transaction": {
    "id": 9001, "litres": 35.5, "unit_price": 98.95, "fuel_amount": 3512.73,
    "nozzle_reading": 104233.5, "payment_mode": "cash",
    "pump": "Pump 3", "nozzle": "N5 (HSD)", "created_at": "2026-07-21T10:12:00Z"
  },
  "visit_entry": { "…VisitEntrySerializer…": true },
  "visit_skipped_reason": null
}
```
`customer`, `transaction` and `visit_entry` are each null when that record was
not produced (see the two cases above).
Endpoint errors: `422 amount_litres_mismatch`; `422 no_price_for_nozzle` (nozzle fuel type has no active catalog product to price from); existing `422 validation_failed`, `404 vehicle_not_found`.

> **Global pause interaction (C4):** when `reward_setting.rewards_paused_globally` is true (see §6), `rewards_paused:true` and `points_earned:0` regardless of per-customer state; the transaction is still recorded.

---

## 3. Daily Settlement (D1–D10, G1) — **New**

Shift-end settlement per pump. FSM creates; admin views/edits current & past (G1). One settlement = one `(fuel_pump, business_date, shift)` tuple.

**Model note:** `daily_settlements` (header) + child rows: `settlement_nozzle_readings`, `settlement_lube_lines`, `settlement_credit_lines`, `settlement_denominations`, `settlement_stock_receipts`, `settlement_decantations`. Header stores `fuel_pump_id`, `business_date`, `shift_label`, `fsm_name`, `phonepe_pos_amount`, `phonepe_scanner_amount`, `status` (`draft`|`submitted`), plus derived totals.

Derivations (server-side, never trusted from client):
- per nozzle: `total_litres = todays_reading − yesterday_reading`; `net_litres_sold = total_litres − testing_litres`; `amount = net_litres_sold × price`
- `fuel_total = Σ amount`; `lube_total = Σ (qty × selling_price)`
- `discounts_total`, `phonepe_total = pos + scanner`, `credit_total`
- `final_amount_to_settle = (fuel_total + lube_total) − (discounts_total + phonepe_total + credit_total)`
- `expected_cash = final_amount_to_settle`; `counted_cash = Σ (denomination × qty)`; `shortage = expected_cash − counted_cash`

### 3.1 `GET /api/v1/staff/settlements/new` — prefill — **New**
Auth: staff/admin. Purpose: build the blank settlement form for a pump with everything auto-populated (D1 yesterday reading, D2 lube catalog, D3 same-day discounts pulled from customer entries §4, prices from catalog).

Query: `fuel_pump_id` (required; defaults to caller's My Pump if omitted), `business_date` (default today), `shift_label` (optional).

Response `200`:
```json
{
  "fuel_pump": { "id": 3, "display_name": "Pump 3" },
  "business_date": "2026-07-21",
  "nozzles": [
    { "nozzle_id": 5, "label": "N5", "fuel_type_code": "hsd", "fuel_type": "HSD",
      "yesterday_reading": 104200.0, "price": 98.95 }
  ],
  "lube_products": [
    { "product_id": 6, "name": "10W30 800ml", "selling_price": 350.0, "opening_stock": 42.0 }
  ],
  "discount_lines": [
    { "customer_entry_id": 55, "transport_name": "ABC Logistics", "litres": 136.0,
      "discount_amount": 272.0, "driver_name": "Ravi", "driver_mobile": "9800000000",
      "manager_name": null, "owner_name": null }
  ],
  "fuel_types_for_stock": [ { "code": "ms", "name": "MS" }, { "code": "hsd", "name": "HSD" } ],
  "denomination_units": [500, 100, 50, 20, 10, 5]
}
```

### 3.2 `POST /api/v1/staff/settlements` — **New**
Auth: staff/admin. Body (`settlement`):

| field | type | req | notes |
|---|---|---|---|
| `fuel_pump_id` | int | yes | |
| `business_date` | date | yes | |
| `shift_label` | string | no | e.g. `"6-2"` |
| `fsm_name` | string | yes | D-settlement "Name of FSM" |
| `nozzle_readings` | array | yes | `[{ nozzle_id, todays_reading, testing_litres }]` (yesterday derived server-side) |
| `lube_lines` | array | no | `[{ product_id, qty, opening_stock, closing_stock }]` |
| `credit_lines` | array | no | `[{ kind, litres, discount_amount, vehicle_number, label }]` — `kind` ∈ `fleet_otp`\|`tt` |
| `phonepe_pos_amount` | number | no | |
| `phonepe_scanner_amount` | number | no | |
| `denominations` | array | no | `[{ denomination, qty }]` |
| `stock_received` | array | no | `[{ fuel_type_code, litres }]` (D8) |
| `decantations` | array | no | `[{ tank_label, opening_kl, closing_kl }]` (D8) |
| `rate_comparison` | object | no | `{ competitor: "JIO-BP", competitor_ms, competitor_hsd, own_ms, own_hsd }` (D10) |
| `status` | enum | no | `draft`\|`submitted`, default `submitted` |

```json
{
  "settlement": {
    "fuel_pump_id": 3, "business_date": "2026-07-21", "fsm_name": "Suresh",
    "nozzle_readings": [ { "nozzle_id": 5, "todays_reading": 104460.0, "testing_litres": 5.0 } ],
    "lube_lines": [ { "product_id": 6, "qty": 3, "opening_stock": 42.0, "closing_stock": 39.0 } ],
    "credit_lines": [ { "kind": "fleet_otp", "litres": 136.0, "discount_amount": 272.0, "vehicle_number": "NL01AE2471", "label": "OTP 136 Lts" } ],
    "phonepe_pos_amount": 4200.0, "phonepe_scanner_amount": 1500.0,
    "denominations": [ { "denomination": 500, "qty": 10 }, { "denomination": 100, "qty": 12 } ],
    "stock_received": [ { "fuel_type_code": "hsd", "litres": 12000.0 } ],
    "decantations": [ { "tank_label": "T1-HSD", "opening_kl": 8.2, "closing_kl": 20.2 } ],
    "status": "submitted"
  }
}
```
Response `201` — full settlement with derived totals:
```json
{
  "settlement": {
    "id": 77, "fuel_pump": { "id": 3, "display_name": "Pump 3" },
    "business_date": "2026-07-21", "shift_label": null, "fsm_name": "Suresh", "status": "submitted",
    "nozzle_readings": [
      { "nozzle_id": 5, "label": "N5", "fuel_type": "HSD", "yesterday_reading": 104200.0,
        "todays_reading": 104460.0, "total_litres": 260.0, "testing_litres": 5.0,
        "net_litres_sold": 255.0, "price": 98.95, "amount": 25232.25 }
    ],
    "lube_lines": [ { "product_id": 6, "name": "10W30 800ml", "qty": 3, "selling_price": 350.0, "amount": 1050.0, "opening_stock": 42.0, "closing_stock": 39.0 } ],
    "credit_lines": [ { "id": 1, "kind": "fleet_otp", "litres": 136.0, "discount_amount": 272.0, "vehicle_number": "NL01AE2471", "label": "OTP 136 Lts" } ],
    "totals": {
      "fuel_total": 25232.25, "lube_total": 1050.0, "discounts_total": 272.0,
      "phonepe_total": 5700.0, "credit_total": 13460.0,
      "final_amount_to_settle": 6850.25,
      "expected_cash": 6850.25, "counted_cash": 6200.0, "shortage": 650.25
    },
    "created_at": "2026-07-21T18:05:00Z"
  }
}
```
Errors: `422 validation_failed` (details per child collection, e.g. `nozzle_readings[0].todays_reading` < yesterday → `reading_regression`); `409 settlement_exists` when a submitted settlement already exists for the `(pump, date, shift)`.

### 3.3 `GET /api/v1/staff/settlements/:id` — **New**
Auth: staff/admin (staff limited to own pump). Response `200`: settlement object (as 3.2). Errors `404`, `403`.

### 3.4 `PATCH /api/v1/staff/settlements/:id` — **New**
Auth: staff/admin. Body: any subset of 3.2 (child arrays replace-in-full). Response `200` recomputed settlement. Errors `404`, `422`.

### 3.5 `GET /api/v1/admin/settlements` — list across pumps (G1) — **New**
Auth: admin. Query: `fuel_pump_id`, `user_id` (the FSM who recorded it — Admin-12), `start_date`, `end_date`, `status`, `page`. The envelope also carries `per_user_totals`: one entry per FSM (`user_id`, `name`, `count`, `pumps[]`, `totals{}`), counting only `submitted`/`reconciled` rows since only those carry money. Paginated envelope:
```json
{ "settlements": [ { "id": 77, "fuel_pump": {"id":3,"display_name":"Pump 3"}, "business_date": "2026-07-21", "fsm_name": "Suresh", "final_amount_to_settle": 6850.25, "shortage": 650.25, "status": "submitted" } ],
  "page": 1, "per_page": 10, "total": 1, "has_more": false }
```

### 3.6 `GET /api/v1/admin/settlements/:id` / `PATCH /api/v1/admin/settlements/:id` — **New**
Auth: admin. Same shapes as 3.3/3.4 but unrestricted by pump; admin may edit past dates (G1 "edit current/past days").

`PATCH` requires **both** `change_reason` (`422 change_reason_required`) and `on_behalf_of_id` (`422 on_behalf_of_required`) — an admin edits a settlement only *for* the FSM who could not, never as himself, so `on_behalf_of_id` must name a current staff member other than the caller (Admin-12). Each entry in the response `changes[]` carries `changed_by` (the admin) alongside `on_behalf_of` / `on_behalf_of_id` (the FSM); the two are never conflated. `PATCH .../reconcile` takes neither — approving is the admin's own act, not data entry.

**§3.2 for admin callers:** `POST /api/v1/staff/settlements` additionally accepts and **requires** `settlement.recorded_by_id` when the caller is an admin (same `422 on_behalf_of_required`, same eligibility rule). The named FSM becomes `recorded_by`; the acting admin is stored as `entered_by`, stamped once at creation and never back-stamped by a later edit. Staff callers may not set it, and it is ignored on `PATCH` for everyone — ownership is decided once and never re-pointed.

---

## 4. Customer capture — per-visit entry (B2) — ✅ **Shipped (2026-07-22)**

The FSM `CustomerDetailsEntry`: captured many times per shift, independent of the loyalty transaction. Feeds §3.1 `discount_lines`. *(Shipped as **`visit_entries`**; `entry_date` is the shift date and phone columns are `*_phone_number`.)*

**Model note:** `visit_entries` — `entry_date`, `vehicle_number`, `driver_name`, `driver_phone_number`, `litres` (decimal, source of truth), `fuel_type_code`, `fuel_pump_id`, `discount_amount`, `fleet_otp` (bool), `transport_name`, `manager_name`, `manager_phone_number`, `owner_name`, `owner_phone_number`, `approx_vehicle_count` (int), `user_id` (capturing FSM), nullable `customer_id`/`vehicle_id` (anonymous plate), nullable `transaction_id`.

### 4.1 `POST /api/v1/staff/visit_entries` — ✅ **Shipped**
Auth: staff/admin. Body (`visit_entry`) with an optional top-level `create_transaction` (and `fuel_pump_nozzle_id` when the nozzle feature is on):

| field | type | req | notes |
|---|---|---|---|
| `vehicle_number` | string | yes | normalized server-side |
| `litres` | number/string | yes | `> 0`; decimal(10,3) |
| `fuel_pump_id` | int | no | defaults to the caller's My Pump; overridable (must be active) |
| `fuel_type_code` | string | no | for later pricing |
| `discount_amount` | number | no | default 0 |
| `fleet_otp` | bool | no | default false |
| `driver_name` / `driver_phone_number` | string | no | phone 10-digit |
| `transport_name` | string | no | |
| `manager_name` / `manager_phone_number` | string | no | |
| `owner_name` / `owner_phone_number` | string | no | |
| `approx_vehicle_count` | int | no | |
| `entry_date` | date | no | default today |

The backend resolves the customer/vehicle from the plate, upserts the driver/manager/owner contacts, and (when `create_transaction=true` with a resolved customer + vehicle) links a `transaction_id` via `TransactionCreator`.

Response `201`:
```json
{ "visit_entry": { "id": 55, "entry_date": "2026-07-21", "vehicle_number": "NL01AE2471",
  "customer_id": 42, "customer_name": "Ravi", "vehicle_id": 88, "fuel_pump_id": 3, "fuel_pump": "Pump 3",
  "driver_name": "Ravi", "driver_phone_number": "9800000000", "litres": 136.0, "fuel_type_code": "hsd",
  "discount_amount": 272.0, "fleet_otp": true, "transport_name": "ABC Logistics",
  "approx_vehicle_count": 12, "transaction_id": null, "created_at": "2026-07-21T14:00:00Z" },
  "points_earned": null, "transaction_id": null }
```
Errors: `422 validation_failed` (missing vehicle number, non-positive litres, no resolvable pump).

### 4.2 `GET /api/v1/staff/visit_entries?date=&fuel_pump_id=` — ✅ **Shipped**
Auth: staff/admin. Defaults to the caller's My Pump + today. Response `{ visit_entries: [ … ], total, date, fuel_pump_id }` — the day-review + settlement-discount pull.

### 4.3 `PATCH`/`DELETE …/visit_entries/:id` — planned
Admin past-day editing lands with D9/G1 (settlement review/edit).

---

## 5. Customer master — contacts + type (B1, E4) — ✅ **Shipped (2026-07-22)**

Extends the customer record from "name + single phone (+ commercial contact)" to a **`customer_contacts` child table** (driver / supervisor / owner / manager, each with a phone + a `contacted` marker + notes), transport master fields, and a `customer_type` taxonomy. *(Implemented as a child table rather than a fixed name/mobile triple, so a customer can carry any number of role contacts.)*

**Model note (added to `customers`):** `customer_type` (`drive_in`|`otp`|`credit`, default `drive_in`), `transport_name`, `approx_vehicle_count`, `info_note`, `primary_contact_id`. **New table `customer_contacts`:** `customer_id`, `role` (`driver`|`supervisor`|`owner`|`manager`), `name`, `phone_number`, `contacted` (bool), `contacted_at`, `notes`, `active`.

### 5.1 `GET /api/v1/staff/customers?type=` — **Changed (E4)**
Auth: staff/admin. New optional query `type` (`drive_in`|`otp`|`credit`) filters the list server-side; combines with `q` and the E2 period params. `CustomerSummarySerializer` now includes `customer_type` and `transport_name`.

### 5.2 `POST /api/v1/staff/customers` & `PATCH /api/v1/staff/customers/:id`
Auth: staff/admin. Body (`customer`) — existing fields plus optional `customer_type`, `transport_name`, `approx_vehicle_count`, `info_note`, and nested `customer_contacts_attributes` (`id`, `role`, `name`, `phone_number`, `contacted`, `notes`, `active`, `_destroy`). A contact row persists only if it carries a name or phone. Existing initial-vehicle fields (`vehicle_number`, `fuel_type`, `vehicle_kind`, `commercial_*`) unchanged. *(The nested-contacts editor is live on the **web** customer form; the native contacts write UI folds into B2.)*

### 5.3 `GET /api/v1/staff/customers/:id` — **Changed**
`CustomerProfileSerializer` gains `customer_type`, `customer_type_label`, `transport_name`, `approx_vehicle_count`, `info_note`, and a `contacts` array (`id`, `role`, `role_label`, `name`, `phone_number`, `contacted`, `contacted_at`, `notes`). No request change. `CustomerLookupSerializer` is unchanged.

---

## 6. Global reward pause (C4) — **Changed**

Adds an outlet-wide pause switch alongside the existing per-customer pause. Belongs to the reward-settings endpoint, not a new route.

**Model note:** `reward_settings.rewards_paused_globally` (bool, default false).

### 6.1 `GET /api/v1/admin/reward_rates` — **Changed**
`reward_setting` object gains `rewards_paused_globally`:
```json
{ "reward_setting": { "rupees_per_reward_unit": 100.0, "cash_value_per_point": 1.0,
  "minimum_redeemable_points": 50, "rewards_paused_globally": false }, "…": "…" }
```

### 6.2 `PATCH /api/v1/admin/reward_rates` — **Changed**
The `reward_setting` param group accepts `rewards_paused_globally` (bool):
```json
{ "reward_setting": { "rewards_paused_globally": true } }
```
Response `200`: updated payload + `message`. Precedence unchanged (`reward_setting` group wins over rate groups). Effect: §2.1 stops awarding points while true.

> **S-PAUSE constraint:** this toggle is admin-only (`/admin` namespace); the staff namespace has no route to it.

---

## 7. Admin pump assignment (A10) — **New**

Today assignment is staff self-service only (`/api/v1/my_pump`). Adds an admin path to assign any operator to a pump + nozzles.

> **Date rules (2026-08-19).** `GET/PATCH /api/v1/my_pump` is **always today's** assignment, for admins as well as staff. A write carrying any other `assignment_date` is refused with `422 daily_assignment_only`; a read serves today whatever was asked for, and echoes `assignment_date` so a client holding a stale date corrects itself. The admin endpoints below accept a date for a specific-day override but refuse a **past** one with `422 past_assignment_date` — a back-dated override cannot move transactions that already snapshotted their pump, so it would silently achieve nothing. See `14-spec-rewards-staff-constraints.md`.

### 7.1 `GET /api/v1/admin/staff_members/:id/pump_assignment` — **New**
Auth: admin. Response `200`:
```json
{ "user": { "id": 42, "name": "Suresh" },
  "fuel_pump_id": 3,
  "assigned_fuel_pump_nozzle_ids": [5, 6],
  "available_pumps": [ { "id": 3, "display_name": "Pump 3", "nozzles": [ { "id": 5, "label": "N5 (HSD)" } ] } ] }
```

### 7.2 `PATCH /api/v1/admin/staff_members/:id/pump_assignment` — **New**
Auth: admin. Body (`user`): `fuel_pump_id` (int, nullable to clear), `assigned_fuel_pump_nozzle_ids` (int[]). Reuses `User#update_pump_assignment`. Response `200` (as 7.1) + `message`. Errors: `404 not_found`, `422 validation_failed` (nozzle not on pump).

---

## 8. Dashboard — drill-through / cadence / type / churn (E2–E6) — **Changed + New**

### 8.1 `GET /api/v1/admin/dashboard` — **Changed**
Existing overview payload (`Admin::Dashboard::OverviewReport`) gains, per feature set:
- **E2** tile targets: each summary tile carries a `segment` key usable with 8.2.
- **E4** `customer_type_breakdown`: counts by `otp`/`credit`/`drivein`.
- **E5** `contacted`: `{ contacted_count, last_contacted_at, conversion_probability }`.

Added keys (existing keys unchanged):
```json
{
  "summary": [ { "key": "today", "label": "Customers today", "value": 34, "segment": "today" } ],
  "customer_type_breakdown": { "otp": 12, "credit": 40, "drivein": 88 },
  "contacted": { "contacted_count": 21, "last_contacted_at": "2026-07-20T17:00:00Z", "conversion_probability": 0.38 },
  "…existing charts/rewards/filters/meta…": true
}
```
Query filters unchanged (`preset`, `start_date`, `end_date`, `segment`, `fuel_type`).

### 8.2 `GET /api/v1/admin/dashboard/customers` — tile drill-through (E2) — **New**
Auth: admin. Query: `segment` (`today`|`this_week`|`last_30_days`|`last_month`|`otp`|`credit`|`drivein`|`lost`), plus the same date filters, `page`. Paginated:
```json
{ "customers": [ { "id": 7, "name": "ABC Logistics", "phone_number": "9800000000",
  "customer_type": "credit", "last_visit_at": "2026-07-19T10:00:00Z",
  "visits_in_range": 4, "total_points": 320 } ],
  "page": 1, "per_page": 20, "total": 1, "has_more": false }
```

### 8.3 `GET /api/v1/admin/customers/:id/cadence` — per-customer cadence (E3) — **New**
Auth: admin. Response `200`:
```json
{ "customer": { "id": 7, "name": "ABC Logistics", "customer_type": "credit", "transport_name": "ABC Logistics" },
  "last_visit_at": "2026-07-19T10:00:00Z",
  "cadence": { "avg_days_between_visits": 3.2, "bucket": "biweekly", "visits_last_30_days": 9 },
  "recent_visits": [ { "date": "2026-07-19", "litres": 136.0, "amount": 13460.0 } ] }
```
`bucket` ∈ `daily`|`weekly`|`biweekly`|`irregular`.

*(Shipped as `GET /api/v1/admin/customers/:id/insight`.)* The response also carries a **`metrics`** block — what this customer has taken and cost us: `{ visits, litres, discount, gifts, contacts, points }`, all plain numbers. `gifts` is the ₹ value of their reward redemptions. Optional `preset` / `start_date` / `end_date` narrow those figures to a period and add a `lifetime_metrics` block beside them; without a period every figure is lifetime and `lifetime_metrics` is omitted. The same figures back the admin customer list's "at least X" filters (`min_visits`, `min_litres`, `min_contacts`, `min_discount`, `min_points`), computed by one shared definition so list and profile cannot disagree — counting rules in `13-spec-customer-crm-capture.md` business rule 8.

### 8.4 `GET /api/v1/admin/dashboard/lost_customers` — churn (E6) — **New**
Auth: admin. Query: `window` (`week`|`month`, default `week`), `page`. "Visited previous window, not current window." Paginated `customers` (as 8.2, plus `last_visit_at`, `days_since_last_visit`).

---

## 9. Campaigns (F1, F2) — **New**

Rule: min purchase per period → discount/gift, targeted at an individual, a customer-type, or a hand-picked list.

**Model note:** `campaigns` — `name`, `min_purchase_amount`, `period` (`weekly`|`monthly`), `reward_kind` (`discount`|`gift`), `reward_value` (decimal), `reward_note` (string), `target_type` (`individual`|`customer_type`|`selected`), `target_customer_type` (nullable enum), `starts_at`, `ends_at`, `active`; join `campaign_customers`.

### 9.1 `GET /api/v1/admin/campaigns` — **New**
Auth: admin. Query: `active`, `page`. Paginated `campaigns`:
```json
{ "campaigns": [ { "id": 3, "name": "Monsoon fleet", "min_purchase_amount": 50000.0,
  "period": "monthly", "reward_kind": "discount", "reward_value": 2.0, "reward_note": "₹2/L",
  "target_type": "customer_type", "target_customer_type": "otp", "audience_size": 12,
  "starts_at": "2026-07-01", "ends_at": "2026-07-31", "active": true } ],
  "page": 1, "per_page": 10, "total": 1, "has_more": false }
```

### 9.2 `POST /api/v1/admin/campaigns` — **New**
Auth: admin. Body (`campaign`):

| field | type | req | notes |
|---|---|---|---|
| `name` | string | yes | |
| `min_purchase_amount` | number | yes | |
| `period` | enum | yes | `weekly`\|`monthly` |
| `reward_kind` | enum | yes | `discount`\|`gift` |
| `reward_value` | number | cond | required for `discount` |
| `reward_note` | string | no | e.g. gift description |
| `target_type` | enum | yes | `individual`\|`customer_type`\|`selected` |
| `target_customer_type` | enum | cond | required when `target_type=customer_type` |
| `customer_ids` | int[] | cond | required when `target_type` ∈ `individual`\|`selected` |
| `starts_at`, `ends_at` | date | yes | |
| `active` | bool | no | default true |

Response `201`: campaign object (as 9.1). Errors: `422 validation_failed` (bad target combo → `details.target_type`), `422` empty `customer_ids` for selected/individual.

### 9.3 `GET /api/v1/admin/campaigns/:id` · `PATCH …/:id` · `DELETE …/:id` — **New**
Auth: admin. Standard read/update/`200`-message-delete. `PATCH` accepts any 9.2 subset.

### 9.4 `POST /api/v1/admin/campaigns/:id/preview_audience` — **New**
Auth: admin. Purpose: resolve the targeted customer set before saving/sending (no side effects). Body: optional overrides (same target fields as 9.2) to preview an unsaved rule. Response `200`:
```json
{ "audience_size": 12, "sample": [ { "id": 7, "name": "ABC Logistics", "customer_type": "otp" } ] }
```

---

## 10. Notifications + targeting (F3, F4) — **Changed + New**

Existing broadcast is untargeted, push-only. Adds an audience selector, channel selector (push / WhatsApp / SMS — provider **out of scope**, see note), an optional attached offer, and an auto loyalty-bonus trigger.

> **Provider note (per Q3):** no OTP/SMS provider is wired. `channel` values other than `push` are accepted and recorded, but non-push delivery returns `queued` status; actual WhatsApp/SMS dispatch is a later integration. Clients must handle `channel_status` per channel.

### 10.1 `POST /api/v1/admin/notifications/send` — **Changed**
Auth: admin. Body — existing `notification[title,message]` plus **new** targeting/channel/offer:

| field | type | req | notes |
|---|---|---|---|
| `notification[title]` | string | yes | |
| `notification[message]` | string | yes | |
| `notification[audience]` | object | no | default `{ "type": "all" }`. `type` ∈ `all`\|`customer_type`\|`selected`\|`campaign`; with `customer_type` → `value`; `selected` → `customer_ids`; `campaign` → `campaign_id` |
| `notification[channels]` | string[] | no | subset of `["push","whatsapp","sms"]`, default `["push"]` |
| `notification[offer]` | object | no | `{ campaign_id }` or `{ title, detail, valid_till }` — rendered into the message payload |

```json
{ "notification": { "title": "Monsoon offer", "message": "₹2/L off for fleet cards",
  "audience": { "type": "customer_type", "value": "otp" },
  "channels": ["push"], "offer": { "campaign_id": 3 } } }
```
Response `200`:
```json
{ "sent": 12, "failed": 0, "audience_size": 12,
  "channel_status": { "push": "sent", "whatsapp": "queued", "sms": "queued" } }
```
Errors: `422 configuration_error` (Firebase unconfigured — unchanged), `422 validation_failed` (bad audience combo).

### 10.2 `POST /api/v1/admin/notifications/loyalty_bonus` — auto loyalty push (F3) — **New**
Auth: admin. Purpose: push accumulated-loyalty-bonus notifications to customers who crossed a points threshold. Body (`notification`): `min_points` (int, default = `reward_setting.minimum_redeemable_points`), `template` (string, supports `{name}`/`{points}` tokens), `channels` (as 10.1). Response `200`: `{ "sent": Int, "audience_size": Int, "channel_status": {…} }`.

### 10.3 `POST /api/v1/admin/schedules` / `PATCH …/:id` — **Changed**
`notification_schedule` param group gains optional `audience` (object, as 10.1) and `channels` (string[]), so scheduled sweeps can target and multi-channel. Serializer echoes both. No new error cases.

---

## 11. Operator KYC (A7) — **Changed**

Per **Q3**: add profile fields only — photo, address, Aadhaar number, ID-card photo — via ActiveStorage. **Keep** username/mobile + password login; **no OTP**.

**Model note (added to `users`):** `address` (text), `aadhaar_number` (string, stored server-side; serialized **masked**), ActiveStorage attachments `photo`, `id_card_photo`.

### 11.1 `POST /api/v1/admin/users` & `PATCH /api/v1/admin/users/:id` — **Changed**
Auth: admin. For image fields the request is **`multipart/form-data`** (JSON still accepted when no files):

| field | type | req | notes |
|---|---|---|---|
| existing: `name`, `username`, `phone_number`, `email`, `role`, `employee_code`, `subtitle`, `active`, `password[_confirmation]` | — | — | unchanged; blank password keeps existing on update |
| `user[address]` | string | no | **new** |
| `user[aadhaar_number]` | string | no | **new**; validated as 12 digits |
| `user[photo]` | file | no | **new**; JPEG/PNG, ≤ 5 MB |
| `user[id_card_photo]` | file | no | **new**; JPEG/PNG/PDF, ≤ 5 MB |

Response `201`/`200`: `UserSerializer` extended:
```json
{ "user": { "id": 42, "name": "Suresh", "username": "suresh", "role": "staff",
  "address": "12 MG Road, …", "aadhaar_number_masked": "XXXX XXXX 4471",
  "photo_url": "https://…/photo.jpg", "id_card_photo_url": "https://…/id.jpg", "active": true } }
```
Errors: `422 validation_failed` (`aadhaar_number` not 12 digits, unsupported content type, file too large → `details.photo`/`details.id_card_photo`).

### 11.2 `GET /api/v1/admin/users/:id` — **Changed**
Returns the extended serializer above. Aadhaar is **always masked** in responses; the raw value is never serialized. PII handling (encryption at rest, access scoping) per the KYC spec.

---

## 12. Reports (E1) — **New**

Aggregated litres / discount / gifts by period, grouped by vehicle / transporter / driver.

### 12.1 `GET /api/v1/admin/reports` — **New**
Auth: admin. Query:

| param | type | notes |
|---|---|---|
| `period` | enum | `daily`\|`weekly`\|`monthly`\|`yearly` |
| `group_by` | enum | `vehicle`\|`transporter`\|`driver` |
| `start_date`, `end_date` | date | range; defaults to current `period` window |
| `fuel_type` | string | optional filter |
| `page` | int | |

Response `200`:
```json
{
  "period": "monthly", "group_by": "transporter",
  "range": { "start_date": "2026-07-01", "end_date": "2026-07-31" },
  "rows": [
    { "key": "ABC Logistics", "label": "ABC Logistics",
      "litres": 4820.0, "amount": 476000.0, "discount": 9640.0, "gifts": 2,
      "visits": 41 }
  ],
  "totals": { "litres": 4820.0, "amount": 476000.0, "discount": 9640.0, "gifts": 2 },
  "page": 1, "per_page": 25, "total": 1, "has_more": false
}
```
Errors: `422 invalid_period` / `invalid_group_by` for unknown enum values.

### 12.2 `GET /api/v1/admin/reports/export` — **New (optional)**
Auth: admin. Same query as 12.1 plus `format=csv`. Returns `text/csv` (`Content-Disposition: attachment`). Non-JSON; client streams to a file. Errors as 12.1.

---

## 13. Customer feedback / rating (E7) — **New**

Lightweight rating captured against a customer (or a visit), surfaced on the dashboard.

**Model note:** `customer_feedbacks` — `customer_id`, `rating` (int 1–5), `comment`, `user_id`, `customer_entry_id` (nullable).

### 13.1 `POST /api/v1/staff/customers/:id/feedback` — **New**
Auth: staff/admin. Body (`feedback`): `rating` (int 1–5, req), `comment` (string, opt), `customer_entry_id` (int, opt). Response `201`:
```json
{ "feedback": { "id": 9, "customer_id": 7, "rating": 4, "comment": "Prompt service", "created_at": "2026-07-21T14:10:00Z" } }
```
Errors: `422 validation_failed` (rating out of 1–5), `404 not_found`.

### 13.2 `GET /api/v1/admin/customers/:id/feedback` — **New**
Auth: admin. Paginated `feedbacks` (rows as 13.1) plus `average_rating` (number).

---

## Appendix A — New vs changed, by route

**New routes**
```
GET/POST         /api/v1/admin/products
PATCH/DELETE     /api/v1/admin/products/:id
GET              /api/v1/staff/settlements/new
POST             /api/v1/staff/settlements
GET/PATCH        /api/v1/staff/settlements/:id
GET              /api/v1/admin/settlements
GET/PATCH        /api/v1/admin/settlements/:id
GET/POST         /api/v1/staff/customer_entries
PATCH/DELETE     /api/v1/staff/customer_entries/:id
GET/PATCH        /api/v1/admin/staff_members/:id/pump_assignment
GET              /api/v1/admin/dashboard/customers
GET              /api/v1/admin/dashboard/lost_customers
GET              /api/v1/admin/customers/:id/cadence
GET/POST         /api/v1/admin/campaigns
GET/PATCH/DELETE /api/v1/admin/campaigns/:id
POST             /api/v1/admin/campaigns/:id/preview_audience
POST             /api/v1/admin/notifications/loyalty_bonus
GET              /api/v1/admin/reports
GET              /api/v1/admin/reports/export
POST             /api/v1/staff/customers/:id/feedback
GET              /api/v1/admin/customers/:id/feedback
```

**Changed routes (request/response extended, path unchanged)**
```
GET   /api/v1/staff/catalog                     (+ products)
POST  /api/v1/staff/transactions                (+ litres/nozzle_reading; fuel_amount derived)
POST/PATCH /api/v1/staff/customers[/:id]        (+ driver/supervisor/owner, contacted_by, customer_type)
GET/PATCH  /api/v1/admin/reward_rates           (+ rewards_paused_globally)
GET   /api/v1/admin/dashboard                   (+ customer_type_breakdown, contacted, tile segments)
POST  /api/v1/admin/notifications/send          (+ audience, channels, offer)
POST/PATCH /api/v1/admin/schedules[/:id]        (+ audience, channels)
POST/PATCH /api/v1/admin/users[/:id]            (+ address, aadhaar_number, photo, id_card_photo; multipart)
GET   /api/v1/admin/users/:id                   (+ KYC fields, masked aadhaar)
```

## Appendix B — Open items to confirm

1. **Customer taxonomy** (`customer_type` values `otp`/`credit`/`drivein`) — assumed per locked notes; confirm labels and whether `tt` is a customer type or only a settlement credit-line kind.
2. **Settlement uniqueness** — one submitted settlement per `(pump, date, shift)`; confirm shift granularity vs per-day.
3. **Shortage sign** — `shortage = expected − counted` (positive = cash short); confirm convention with ops.
4. **WhatsApp/SMS** — `channels` accepted and recorded but not dispatched (no provider, Q3); confirm the queue/hand-off target.
5. **Aadhaar at rest** — masked in all responses; confirm encryption strategy and who may read the raw value (likely nobody via API).
