# Admin: Reset Transaction Data

Web-only admin screen for wiping operational data so the site can restart from a
clean slate — pilot data before go-live, or a bad import. There is **no API or
native counterpart**, and there is no undo.

- Route: `GET/POST /admin/data_reset` → `Admin::DataResetsController`
- Nav: sidebar → App Management → **Reset Data** (admins only)
- Service: [`Admin::DataReset`](../app/services/admin/data_reset.rb)
- Policy: `DataResetPolicy` — `current_user.admin?` for both actions

## What can be deleted

Each entity is an independent checkbox, so the admin decides the blast radius.

| Checkbox | Table | Date column | Customer-scoped |
| --- | --- | --- | --- |
| Fuel transactions | `transactions` | `created_at` | yes |
| Points ledger entries | `points_ledgers` | `created_at` | yes |
| Visit entries | `visit_entries` | `entry_date` | yes |
| Customer feedback | `customer_feedbacks` | `created_at` | yes |
| Campaign qualifications | `campaign_qualifications` | `created_at` | yes |
| Daily settlements | `daily_settlements` | `business_date` | **no** |

### Forced and implicit cascades

- **Points ledger rows attached to in-scope transactions are always deleted**
  with those transactions, even if the ledger box is unticked —
  `points_ledgers.transaction_id` has a blocking FK. The page shows the count up
  front.
- **Daily settlement children** (nozzle readings, cash denominations, credit /
  lube / discount lines, decantations, stock receipts, rate comparisons, audit
  changes) go via `ON DELETE CASCADE`.
- **Surviving rows are nullified, not deleted**, by existing FKs: a kept
  `customer_feedback` or `visit_entry` loses its `transaction_id`, a kept
  `settlement_discount_line` loses its `visit_entry_id`, and a kept
  `campaign_qualification` loses its `reward_points_ledger_id`.
- **Milestone watermarks re-arm**: once a customer has no ledger rows left,
  `customers.last_milestone_points` is reset to 0, so auto-milestone
  notifications fire again instead of being suppressed by a watermark that
  outlived its ledger.

## Scope

Three filters, combinable:

- **From / To date** — blank means all time. Applied per entity on the date
  column in the table above. A reversed range is swapped rather than rejected.
- **Customer phone number** — blank means every customer. Resolved against the
  unique `customers.phone_number`; an unknown number is an error and deletes
  nothing. Daily settlements belong to a pump, not a customer, so they are
  **skipped** (and labelled as such) whenever a customer filter is set.

## Safeguards

1. Counts are previewed per entity before anything runs.
2. The reset form is armed only with what was previewed — its selection, dates
   and customer are hidden fields rendered from the last preview, so editing the
   pickers without pressing **Preview counts** cannot widen a reset.
3. The submit button is disabled while nothing is selected.
4. The literal phrase `RESET` must be typed; it is checked server-side.
5. The Bootstrap confirm modal (`data-confirm-modal`) intercepts the submit.
6. Everything runs inside one `ApplicationRecord.transaction`.
7. Each run is logged at `warn` with the admin's user id, the entity keys, the
   scope, and the deleted row counts: grep for `[Admin::DataReset]`.

## Tests

`test/controllers/admin/data_resets_controller_test.rb`
