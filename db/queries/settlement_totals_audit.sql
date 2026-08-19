-- Settlement totals audit
--
-- Written to answer "did the item-6 duplicate repair do the right thing, and is
-- anything still wrong?" after migration 20260819090000 deduplicated settlement
-- child rows in production and re-derived the affected totals.
--
-- Query 1 is the one that matters: it should return zero rows, now and forever.
-- Queries 2 and 3 are forensic — what the repair touched, and proof the
-- constraint that prevents a recurrence is in place.
--
-- Run against production with the same job that runs migrations (no secret
-- leaves Secret Manager):
--
--   gcloud run jobs execute fuel-loyalty-git-migrate --region=us-central1 --wait \
--     --args="exec,rails,runner,script/audit_settlement_totals.rb"
--
-- or paste a single query into any psql session on quickink-pg.


-- ---------------------------------------------------------------------------
-- 1. Stored totals that disagree with their own line items.
--
-- Settlement::Calculator recomputes these on every save, so a mismatch means a
-- settlement's header is lying about its own lines — which is exactly what the
-- duplicate bug produced (doubled children, doubled totals). Expect ZERO rows.
--
-- The D6/D7 formulas being checked:
--   final    = (fuel + lube) − (discount + credit + digital receipts + expenses)
--   shortage = final − counted cash
-- ---------------------------------------------------------------------------
WITH line_totals AS (
  SELECT
    s.id,
    s.business_date,
    s.fuel_pump_id,
    s.status,
    s.fsm_name_snapshot,
    s.total_fuel_amount,
    s.total_lube_amount,
    s.total_discount_amount,
    s.total_credit_amount,
    s.total_digital_receipt_amount,
    s.total_expense_amount,
    s.counted_cash_amount,
    s.final_amount_to_settle,
    s.shortage_amount,
    COALESCE(nr.total, 0) AS lines_fuel,
    COALESCE(ll.total, 0) AS lines_lube,
    COALESCE(dl.total, 0) AS lines_discount,
    COALESCE(cl.total, 0) AS lines_credit,
    COALESCE(dr.total, 0) AS lines_digital,
    COALESCE(el.total, 0) AS lines_expense,
    COALESCE(cd.total, 0) AS lines_cash
  FROM daily_settlements s
  LEFT JOIN (SELECT daily_settlement_id, SUM(amount)          AS total FROM settlement_nozzle_readings   GROUP BY 1) nr ON nr.daily_settlement_id = s.id
  LEFT JOIN (SELECT daily_settlement_id, SUM(amount)          AS total FROM settlement_lube_lines        GROUP BY 1) ll ON ll.daily_settlement_id = s.id
  LEFT JOIN (SELECT daily_settlement_id, SUM(discount_amount) AS total FROM settlement_discount_lines    GROUP BY 1) dl ON dl.daily_settlement_id = s.id
  LEFT JOIN (SELECT daily_settlement_id, SUM(amount)          AS total FROM settlement_credit_lines      GROUP BY 1) cl ON cl.daily_settlement_id = s.id
  LEFT JOIN (SELECT daily_settlement_id, SUM(amount)          AS total FROM settlement_digital_receipts  GROUP BY 1) dr ON dr.daily_settlement_id = s.id
  LEFT JOIN (SELECT daily_settlement_id, SUM(amount)          AS total FROM settlement_expense_lines     GROUP BY 1) el ON el.daily_settlement_id = s.id
  LEFT JOIN (SELECT daily_settlement_id, SUM(amount)          AS total FROM settlement_cash_denominations GROUP BY 1) cd ON cd.daily_settlement_id = s.id
),
expected AS (
  SELECT
    line_totals.*,
    ROUND((lines_fuel + lines_lube)
          - (lines_discount + lines_credit + lines_digital + lines_expense), 2) AS expected_final
  FROM line_totals
)
SELECT
  id,
  business_date,
  fuel_pump_id,
  status,
  fsm_name_snapshot,
  total_fuel_amount,            lines_fuel,
  total_lube_amount,            lines_lube,
  total_discount_amount,        lines_discount,
  total_credit_amount,          lines_credit,
  total_digital_receipt_amount, lines_digital,
  total_expense_amount,         lines_expense,
  counted_cash_amount,          lines_cash,
  final_amount_to_settle,       expected_final,
  shortage_amount,              ROUND(expected_final - lines_cash, 2) AS expected_shortage,
  -- A settlement whose header is exactly twice its lines is an unrepaired
  -- double-submit; anything else is a different kind of drift.
  CASE
    WHEN lines_fuel > 0 AND total_fuel_amount = lines_fuel * 2 THEN 'looks doubled'
    ELSE 'other drift'
  END AS diagnosis
FROM expected
WHERE total_fuel_amount            <> lines_fuel
   OR total_lube_amount            <> lines_lube
   OR total_discount_amount        <> lines_discount
   OR total_credit_amount          <> lines_credit
   OR total_digital_receipt_amount <> lines_digital
   OR total_expense_amount         <> lines_expense
   OR counted_cash_amount          <> lines_cash
   OR final_amount_to_settle       <> expected_final
   OR shortage_amount              <> ROUND(expected_final - lines_cash, 2)
ORDER BY business_date DESC, id;


-- ---------------------------------------------------------------------------
-- 2. Settlements that were probably re-submitted before the fix.
--
-- Heuristic, not proof. Keyed child rows are written once, when the sheet is
-- first saved, and updated in place afterwards. The repair kept the NEWEST of
-- each duplicate pair, so a surviving reading created well after its parent is
-- the second post's copy — the signature of the id-less re-submit.
--
-- False positives to expect: a nozzle activated after the sheet was first
-- saved, and admin edits that add a line. Treat the list as "worth eyeballing",
-- and read it alongside query 1 — anything here that is absent from query 1 was
-- repaired correctly.
-- ---------------------------------------------------------------------------
SELECT
  s.id,
  s.business_date,
  s.fuel_pump_id,
  s.fsm_name_snapshot,
  s.status,
  s.created_at                                  AS settlement_created_at,
  MAX(nr.created_at)                            AS last_reading_created_at,
  ROUND(EXTRACT(EPOCH FROM (MAX(nr.created_at) - s.created_at)))::int AS seconds_after_create,
  COUNT(*)                                      AS surviving_readings
FROM daily_settlements s
JOIN settlement_nozzle_readings nr ON nr.daily_settlement_id = s.id
GROUP BY s.id, s.business_date, s.fuel_pump_id, s.fsm_name_snapshot, s.status, s.created_at
HAVING MAX(nr.created_at) > s.created_at + INTERVAL '60 seconds'
ORDER BY s.business_date DESC, s.id;


-- ---------------------------------------------------------------------------
-- 3. The constraints that stop it happening again.
--
-- Expect five rows — nozzle readings, lube lines, cash denominations, stock
-- receipts, rate comparisons — plus the digital receipts key added alongside.
-- A missing row means a duplicate can be written again.
-- ---------------------------------------------------------------------------
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE indexname LIKE '%_on_settlement_key'
ORDER BY tablename;
