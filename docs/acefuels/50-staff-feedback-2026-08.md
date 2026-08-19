# Staff feedback — August 2026

Thirteen items raised by FSM staff after running the app at the counter. This
page is the running record of what each item meant in the code and how it was
resolved, so the fixes stay traceable back to the request that prompted them.

Items are delivered in three batches: the small, self-contained fixes first,
then the ones needing new schema, then the New Transaction / Capture Visit
merge.

| # | Item | Batch | Status |
|---|------|-------|--------|
| 1 | Loyalty Lookup — phone number not cleared after navigating away and back | 1 | ✅ Done |
| 2 | Difference between New Transaction and Capture Visit — only one way to capture | 3 | ⏳ Planned |
| 3 | Only 3 customer types: Drive-In, Credit, Fleet/OTP | 1 | ✅ Done |
| 4 | Only 2 payment types: Cash or Credit | 1 | ✅ Already correct |
| 5 | Settlement date should default to yesterday | 1 | ✅ Done |
| 6 | Daily settlement multiplies if submitted twice; staff can't view the day's settlement report | 2 | ⏳ Planned |
| 7 | Cash counter should include ₹2 and ₹1 | 1 | ✅ Done |
| 8 | New Transaction is missing the discount field | 1 | ✅ Done |
| 9 | Credit Line type should be the customer type | 1 | ✅ Done |
| 10 | Free-form digital receipts (PAYTM or any other means) with an amount | 2 | ⏳ Planned |
| 11 | Add a discount during settlement calculation if it was missed at capture | 2 | ⏳ Planned |
| 12 | Free-form field for Salary Advance or any other same-day note | 2 | ⏳ Planned |
| 13 | Customer-capture notes should be timestamped, append-only entries | 2 | ⏳ Planned |

## Batch 1 — delivered

### 1 · Loyalty lookup clears itself

The counter device is shared, so a number left in the lookup field is both a
privacy leak and a mis-scan waiting to happen.

- **Android** — `LoyaltyLookupCard` (Home) and `LoyaltyLookupScreen` (public)
  held the typed number in `rememberSaveable` while the view model held the
  result, so both survived navigating away. A `LifecycleResumeEffect` now
  clears the field and resets the view model as soon as the screen stops being
  the foreground destination.
- **Web** — the lookup input is marked `data-clear-on-restore` and cleared on
  `turbo:before-cache` (so the snapshot Turbo restores from is empty) and on a
  bfcache `pageshow`. A value the server deliberately re-rendered — the number
  that failed validation — is left alone. `autocomplete` is off.

### 3 · Three customer types, named consistently

The three types already existed (`drive_in / otp / credit`); the wording and
order did not. `Customer::CUSTOMER_TYPE_LABELS` is now the single source —
**Drive-In, Credit, Fleet/OTP**, in that order — and every picker, filter chip
and badge reads from it (`Customer.customer_type_options` /
`customer_type_label_for`) instead of hardcoding a list or calling `humanize`.
The Android filter chips mirror the same list.

### 4 · Two payment types

Already correct on every surface: `Transaction#payment_mode` is
`{ cash, credit }`, and the web radio group and the Android payment options
offer exactly those two. No change.

### 5 · Settlement defaults to yesterday

Staff record the day's transactions as they happen and settle the next morning,
so a draft opened with no date now loads **yesterday's** sheet
(`Settlement::Builder.default_business_date`). An unparseable date falls back to
the same default. The pump/date chooser still lets the FSM pick any date, and
Android picks the default up from the draft API.

### 7 · ₹2 and ₹1 in the cash counter

`SettlementCashDenomination::DENOMINATIONS` is now
`500, 200, 100, 50, 20, 10, 5, 2, 1`. The form grid, the draft API and the
Android denomination rows all derive from that constant, so one change covers
all three. Existing settlements gain the two new rows when reopened.

### 8 · Discount on New Transaction

`Transaction#discount_amount` existed and was permitted, but no form ever set
it. Added on the web fuel step and the Android transaction screen, with the
submit gate refusing a negative discount or one that swallows the sale.

`TransactionCreator` previously applied a discount only on the litres path; the
web form captures ₹, so the typed-amount path now treats the figure as the
gross and takes the discount off it. Points are earned on the net — what the
customer actually paid.

### 9 · Credit line type is the customer type

`SettlementCreditLine#credit_type` was `fleet_otp / tank_truck`. It now mirrors
the three customer account types. `fleet_otp` keeps its stored value (`0`) so
installed app builds keep posting a value the server accepts; `tank_truck` (`1`)
was migrated to `credit` (`3`), which is what a tank-truck credit sale was being
used to record. The Android type toggle became a three-way segmented control.
