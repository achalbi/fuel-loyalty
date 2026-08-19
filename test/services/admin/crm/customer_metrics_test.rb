require "test_helper"

module Admin
  module Crm
    # Staff feedback item 4 — the cohort metrics and the thresholds built on them.
    class CustomerMetricsTest < ActiveSupport::TestCase
      JULY = Time.zone.local(2026, 7, 1).beginning_of_day..Time.zone.local(2026, 7, 31).end_of_day

      setup do
        @staff = users(:two)
        @pump = fuel_pumps(:one)
        # Fresh customers only: the fixtures already carry transactions, so every
        # assertion below scopes to the ids it created.
        @customer = Customer.create!(name: "Metric Cust", phone_number: "9333300001")
      end

      def vehicle(customer = @customer, number: "TN33AA0001")
        @vehicles ||= {}
        @vehicles[number] ||= Vehicle.create!(customer: customer, vehicle_number: number,
                                              fuel_type: "petrol", vehicle_kind: "two_wheeler")
      end

      def add_visit(date, customer: @customer, litres: 10, discount: 0, fuel_transaction: nil, number: "TN33AA0001")
        VisitEntry.create!(customer: customer, user: @staff, fuel_pump: @pump, entry_date: date,
                           vehicle_number: number, litres: litres, discount_amount: discount,
                           fuel_transaction: fuel_transaction)
      end

      def add_transaction(date, customer: @customer, litres: 10, discount: 0, amount: 500, number: "TN33AA0001")
        Transaction.create!(customer: customer, user: @staff, fuel_pump: @pump,
                            vehicle: vehicle(customer, number: number), fuel_amount: amount,
                            litres: litres, discount_amount: discount, payment_mode: "cash",
                            created_at: date.in_time_zone.change(hour: 9))
      end

      # The metrics as the list reads them: SELECT the expressions, then decode.
      def metrics_for(customer = @customer, range: nil)
        service = CustomerMetrics.new(range: range)
        row = Customer.where(id: customer.id).select("customers.*", service.select_sql).first
        CustomerMetrics.values_for(row)
      end

      def cohort_ids(thresholds, range: nil, **filters)
        CustomerMetrics.new(range: range).cohort(thresholds: thresholds, **filters).pluck(:id)
      end

      # ---- visit_count -------------------------------------------------------

      test "visit_count counts recorded fuellings across transactions and visit entries" do
        add_visit(Date.new(2026, 7, 1))
        add_visit(Date.new(2026, 7, 8))
        add_transaction(Date.new(2026, 7, 15))

        assert_equal 3, metrics_for[:visit_count]
      end

      test "a linked visit and transaction pair counts as one visit" do
        # VisitEntryRecorder copies the visit onto the loyalty transaction it
        # creates, so touching both tables counts this fuelling twice.
        txn = add_transaction(Date.new(2026, 7, 10), litres: 20, discount: 100)
        add_visit(Date.new(2026, 7, 10), litres: 20, discount: 100, fuel_transaction: txn)
        add_visit(Date.new(2026, 7, 11))

        assert_equal 2, metrics_for[:visit_count]
      end

      test "a linked pair straddling midnight is still one visit, one litre total, one discount" do
        # THE BUG THIS PINS. visit_count used to de-duplicate on the calendar DAY
        # (a UNION of visit days), which only collapses a linked pair when both
        # rows land on the same date. Back-dated capture — the fleet/credit
        # workflow visit entries exist for — breaks that: the entry is written for
        # 30 Jun and the loyalty transaction it creates is stamped 1 Jul. The day
        # rule then reported TWO visits for ONE fuelling while litres_total and
        # discount_total (which de-duplicate on the LINK) reported it once, so
        # three figures on the same row contradicted each other.
        txn = add_transaction(Date.new(2026, 7, 1), litres: 20, discount: 100)
        add_visit(Date.new(2026, 6, 30), litres: 20, discount: 100, fuel_transaction: txn)

        values = metrics_for
        assert_equal 1, values[:visit_count], "one fuelling, whatever the two rows are dated"
        assert_equal 20.0, values[:litres_total]
        assert_equal 100.0, values[:discount_total]

        # And the three agree inside a window that cuts between the two rows, from
        # either side: the anti-join carries the same window as the visit side, so
        # the pair is counted once by whichever row falls in — never twice, never
        # dropped by both.
        june = Time.zone.local(2026, 6, 1).beginning_of_day..Time.zone.local(2026, 6, 30).end_of_day
        july_only = metrics_for(range: JULY)
        assert_equal 1, july_only[:visit_count], "the transaction side is inside July"
        assert_equal 20.0, july_only[:litres_total]

        june_only = metrics_for(range: june)
        assert_equal 1, june_only[:visit_count], "the visit-entry side is inside June"
        assert_equal 20.0, june_only[:litres_total]
      end

      test "two fuellings on one day are two visits" do
        # The flip side of counting fuellings rather than days, stated so nobody
        # reads visit_count as Cadence's figure: Admin::Crm::Cadence uniqs dates
        # because it measures the GAP between visits, this counts the events the
        # litres and discount totals are built from.
        add_visit(Date.new(2026, 7, 4), litres: 10)
        add_visit(Date.new(2026, 7, 4), litres: 15, number: "TN33AA0099")

        values = metrics_for
        assert_equal 2, values[:visit_count]
        assert_equal 25.0, values[:litres_total], "and the litres agree with the count"
      end

      # ---- litres_total / discount_total ------------------------------------

      test "litres and discount count a linked pair once and standalone rows in full" do
        txn = add_transaction(Date.new(2026, 7, 10), litres: 20, discount: 100)
        add_visit(Date.new(2026, 7, 10), litres: 20, discount: 100, fuel_transaction: txn)
        add_visit(Date.new(2026, 7, 11), litres: 5, discount: 40)          # visit only
        add_transaction(Date.new(2026, 7, 12), litres: 2.5, discount: 25)  # transaction only

        values = metrics_for
        assert_equal 27.5, values[:litres_total]   # 20 once + 5 + 2.5, not 47.5
        assert_equal 165.0, values[:discount_total] # 100 once + 40 + 25, not 265
      end

      test "discount_total agrees with Customer#discount_total" do
        # The set-wise SQL and the per-customer Ruby rule are two expressions of
        # one definition; this pins them together so neither can drift.
        txn = add_transaction(Date.new(2026, 7, 10), discount: 100)
        add_visit(Date.new(2026, 7, 10), discount: 100, fuel_transaction: txn)
        add_visit(Date.new(2026, 7, 11), discount: 40)
        add_transaction(Date.new(2026, 7, 12), discount: 25)

        assert_equal @customer.discount_total.to_f, metrics_for[:discount_total]
        assert_equal @customer.discount_total(range: JULY).to_f, metrics_for(range: JULY)[:discount_total]
      end

      test "metrics are zero for a customer with no history" do
        values = metrics_for
        assert_equal 0, values[:visit_count]
        assert_equal 0.0, values[:litres_total]
        assert_equal 0.0, values[:discount_total]
        assert_equal 0, values[:contact_count]
        assert_equal 0, values[:points_earned]
        assert_equal 0, values[:points_balance]
      end

      # ---- contacts ----------------------------------------------------------

      test "contact_count counts outreach logs and windows on contacted_at" do
        ContactLog.create!(customer: @customer, user: @staff, channel: "call", outcome: "reached",
                           contacted_at: Time.zone.local(2026, 7, 5, 10))
        ContactLog.create!(customer: @customer, user: @staff, channel: "sms", outcome: "no_answer",
                           contacted_at: Time.zone.local(2026, 7, 20, 10))
        ContactLog.create!(customer: @customer, user: @staff, channel: "call", outcome: "declined",
                           contacted_at: Time.zone.local(2026, 6, 20, 10))

        assert_equal 3, metrics_for[:contact_count]
        assert_equal 2, metrics_for(range: JULY)[:contact_count]
      end

      # ---- points ------------------------------------------------------------

      test "points_earned is windowed and ignores redemptions while points_balance is lifetime and net" do
        @customer.points_ledgers.create!(points: 300, entry_type: :earn, created_at: Time.zone.local(2026, 6, 10))
        @customer.points_ledgers.create!(points: 120, entry_type: :earn, created_at: Time.zone.local(2026, 7, 10))
        @customer.points_ledgers.create!(points: -50, entry_type: :redeem, created_at: Time.zone.local(2026, 7, 12))

        all_time = metrics_for
        assert_equal 420, all_time[:points_earned]
        assert_equal 370, all_time[:points_balance]

        july = metrics_for(range: JULY)
        assert_equal 120, july[:points_earned], "earn rows outside the window must not count"
        assert_equal 370, july[:points_balance], "the balance is lifetime by design, never windowed"
      end

      # ---- thresholds --------------------------------------------------------

      test "a customer exactly at the threshold is included" do
        3.times { |i| add_visit(Date.new(2026, 7, 1) + i.days) }

        assert_includes cohort_ids({ visit_count: 3 }), @customer.id, ">= not >"
        assert_not_includes cohort_ids({ visit_count: 4 }), @customer.id
      end

      test "litres and discount thresholds are inclusive at the boundary too" do
        add_visit(Date.new(2026, 7, 3), litres: 42.5, discount: 99.5)

        assert_includes cohort_ids({ litres_total: BigDecimal("42.5") }), @customer.id
        assert_not_includes cohort_ids({ litres_total: BigDecimal("42.501") }), @customer.id
        assert_includes cohort_ids({ discount_total: BigDecimal("99.5") }), @customer.id
        assert_not_includes cohort_ids({ discount_total: BigDecimal("99.51") }), @customer.id
      end

      test "an unset threshold leaves customers with zero of that metric reachable" do
        # No contacts, no points, no visits at all — the metric subqueries must
        # COALESCE to 0 rather than drop the row (LEFT JOIN semantics).
        quiet = Customer.create!(name: "Never Seen", phone_number: "9333300009")

        assert_includes cohort_ids({}), quiet.id
        assert_includes cohort_ids({ visit_count: 0 }), quiet.id
        assert_not_includes cohort_ids({ visit_count: 1 }), quiet.id
      end

      test "thresholds are AND-combined" do
        add_visit(Date.new(2026, 7, 2), litres: 100)
        add_visit(Date.new(2026, 7, 3), litres: 100)
        ContactLog.create!(customer: @customer, user: @staff, channel: "call", outcome: "reached",
                           contacted_at: Time.zone.local(2026, 7, 4, 10))

        assert_includes cohort_ids({ visit_count: 2, litres_total: BigDecimal("200"), contact_count: 1 }), @customer.id
        # One unmet threshold drops the customer even though the others pass.
        assert_not_includes cohort_ids({ visit_count: 2, contact_count: 2 }), @customer.id
      end

      test "a customer with three visits and two contacts is not multiplied by the join" do
        # The classic fan-out bug: joining both has-manys in one grouped query
        # reports 6 of each.
        3.times { |i| add_visit(Date.new(2026, 7, 1) + i.days, litres: 10) }
        2.times do |i|
          ContactLog.create!(customer: @customer, user: @staff, channel: "call", outcome: "reached",
                             contacted_at: Time.zone.local(2026, 7, 10 + i, 10))
        end

        values = metrics_for
        assert_equal 3, values[:visit_count]
        assert_equal 2, values[:contact_count]
        assert_equal 30.0, values[:litres_total]
      end

      # ---- the period bug ----------------------------------------------------

      test "a visit-entry-only customer survives a date range" do
        # The regression this fixes: the period filter used to be
        # `transacted_between` (transactions only), so a fleet/OTP customer whose
        # fuelling is captured as a visit_entry vanished the moment any date range
        # was chosen — exactly the segment a litres cohort exists to find.
        fleet = Customer.create!(name: "Fleet Only", phone_number: "9333300002", customer_type: "otp")
        add_visit(Date.new(2026, 7, 9), customer: fleet, litres: 300, number: "TN33BB0002")

        assert_includes cohort_ids({}, range: JULY), fleet.id
        assert_includes cohort_ids({ litres_total: BigDecimal("300") }, range: JULY), fleet.id
        assert_not_includes cohort_ids({}, range: Time.zone.local(2026, 6, 1).beginning_of_day..Time.zone.local(2026, 6, 30).end_of_day), fleet.id
      end

      test "a period gates every threshold, including the lifetime points balance" do
        # KEPT BEHAVIOUR, PINNED SO IT IS DOCUMENTED RATHER THAN DISCOVERED.
        # A period means "active in period": it restricts WHO is listed as well as
        # windowing the figures, and that gate AND-combines with every threshold.
        # points_balance is deliberately lifetime (never windowed), but a customer
        # who did not fuel in the window is still not in the list — "customers
        # active in this period" is what the admin date picker has always meant
        # and the E2 dashboard drill-through depends on it. Both UIs label the
        # control "active in period"; see docs/acefuels/20-api-contracts.md §14.
        dormant = Customer.create!(name: "Dormant Balance", phone_number: "9333300005")
        dormant.points_ledgers.create!(points: 5_000, entry_type: :earn,
                                       created_at: Time.zone.local(2025, 3, 1))
        active = Customer.create!(name: "Active Balance", phone_number: "9333300006")
        active.points_ledgers.create!(points: 5_000, entry_type: :earn,
                                      created_at: Time.zone.local(2025, 3, 1))
        add_visit(Date.new(2026, 7, 12), customer: active, litres: 40, number: "TN33CC0006")

        # All time: both clear the lifetime balance threshold.
        all_time = cohort_ids({ points_balance: 5_000 })
        assert_includes all_time, dormant.id
        assert_includes all_time, active.id

        # With a period: the balance is still the lifetime 5,000 for both, but
        # only the one who actually fuelled in July is listed.
        july = cohort_ids({ points_balance: 5_000 }, range: JULY)
        assert_includes july, active.id
        assert_not_includes july, dormant.id,
          "a period lists only customers active in it, even for the lifetime balance cohort"

        # The figure itself is untouched by the window — it is membership, not the
        # metric, that the period changed.
        assert_equal 5_000, metrics_for(dormant, range: JULY)[:points_balance]
      end

      test "the period windows visits on entry_date and transactions on created_at" do
        add_visit(Date.new(2026, 6, 30))          # outside
        add_visit(Date.new(2026, 7, 2))           # inside
        add_transaction(Date.new(2026, 7, 3))     # inside
        add_transaction(Date.new(2026, 8, 1))     # outside

        assert_equal 4, metrics_for[:visit_count]
        assert_equal 2, metrics_for(range: JULY)[:visit_count]
      end

      # ---- other cohort filters ---------------------------------------------

      test "cohort still honours status and account type" do
        fleet = Customer.create!(name: "Fleet Filter", phone_number: "9333300003", customer_type: "otp")
        dormant = Customer.create!(name: "Dormant Filter", phone_number: "9333300004", active: false)

        assert_includes cohort_ids({}, customer_type: "otp"), fleet.id
        assert_not_includes cohort_ids({}, customer_type: "otp"), dormant.id
        assert_includes cohort_ids({}, status: "inactive"), dormant.id
        assert_not_includes cohort_ids({}, status: "inactive"), fleet.id
        # An unrecognised value is ignored rather than returning nothing.
        assert_includes cohort_ids({}, customer_type: "nonsense", status: "whatever"), fleet.id
      end

      test "cohort search matches a vehicle number without duplicating the customer" do
        vehicle(@customer, number: "TN33AA0001")
        ids = CustomerMetrics.new.cohort(query: "TN33AA0001").pluck(:id)

        assert_includes ids, @customer.id
        # The old LEFT JOIN onto vehicles returned one row per vehicle; the
        # subquery cannot, which is what lets the list be counted and paged.
        assert_equal 1, ids.count(@customer.id)
      end

      # ---- param parsing -----------------------------------------------------

      test "thresholds_from ignores blank, negative and unparseable values" do
        parsed = CustomerMetrics.thresholds_from(
          min_visits: "3", min_litres: "12.5", min_discount: "",
          min_contacts: "not a number", min_points_earned: "-4", min_points_balance: "0"
        )

        assert_equal 3, parsed[:visit_count]
        assert_equal BigDecimal("12.5"), parsed[:litres_total]
        assert_nil parsed[:discount_total]
        assert_nil parsed[:contact_count]
        assert_nil parsed[:points_earned], "a negative threshold is not a filter"
        assert_equal 0, parsed[:points_balance]
      end

      test "threshold_params round-trips without scientific notation" do
        parsed = CustomerMetrics.thresholds_from(min_visits: "3", min_litres: "12.5")

        assert_equal({ min_visits: "3", min_litres: "12.5" }, CustomerMetrics.threshold_params(parsed))
      end

      test "values_for is safe on a record selected without the metric columns" do
        assert_equal 0, CustomerMetrics.values_for(@customer)[:visit_count]
      end
    end
  end
end
