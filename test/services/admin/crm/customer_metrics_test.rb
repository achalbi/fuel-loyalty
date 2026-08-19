require "test_helper"

module Admin
  module Crm
    class CustomerMetricsTest < ActiveSupport::TestCase
      setup do
        @staff = users(:two)
        @pump = fuel_pumps(:one)
        @customer = Customer.create!(name: "Metrics Meena", phone_number: "9333300010")
        @vehicle = @customer.vehicles.create!(vehicle_number: "TN09MM0001", fuel_type: :petrol, vehicle_kind: :two_wheeler)
      end

      def transaction_on(at, litres:, discount:)
        Transaction.create!(customer: @customer, user: @staff, vehicle: @vehicle, fuel_amount: 1000,
                            litres: litres, discount_amount: discount, created_at: at)
      end

      def capture_on(date, litres:, discount:, transaction: nil)
        VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: @pump, entry_date: date,
                           vehicle_number: @vehicle.vehicle_number, litres: litres,
                           discount_amount: discount, fuel_transaction: transaction)
      end

      def totals(period_range: nil)
        CustomerMetrics.for(@customer, period_range: period_range)
      end

      # The ids the "at least X" filters actually return, which is the only way to
      # tell two thresholds apart: Totals reports one number per metric, a filter
      # decides who is in the list.
      def cohort_ids(period_range: nil, **thresholds)
        CustomerMetrics.new(period_range: period_range, thresholds: thresholds).cohort.pluck(:id)
      end

      test "sums litres and discount across transactions and unlinked captures" do
        transaction_on(Time.zone.local(2026, 7, 10, 9, 0), litres: 10, discount: 5)
        capture_on(Date.new(2026, 7, 11), litres: 20, discount: 7)

        result = totals

        assert_equal 30.0, result.litres
        assert_equal 12.0, result.discount
        assert_equal 2, result.visits
      end

      test "a capture linked to its transaction is counted once, not twice" do
        linked = transaction_on(Time.zone.local(2026, 7, 10, 9, 0), litres: 10, discount: 5)
        capture_on(Date.new(2026, 7, 10), litres: 10, discount: 5, transaction: linked)

        result = totals

        assert_equal 10.0, result.litres
        assert_equal 5.0, result.discount
        assert_equal 1, result.visits
      end

      # The regression that made visits contradict litres and discount on the same
      # A linked pair is ONE row in the stream: the visit-entry branch of the union
      # is gated `transaction_id IS NULL`, so the capture is dropped and its
      # transaction carries the figures. Regression guard on that gate — it is what
      # stops a back-dated fleet capture (30 Jun) whose transaction landed after
      # midnight (1 Jul) from being counted twice.
      test "a linked pair is one visit, and litres and discount agree with it" do
        linked = transaction_on(Time.zone.local(2026, 7, 1, 0, 20), litres: 20, discount: 100)
        capture_on(Date.new(2026, 6, 30), litres: 20, discount: 100, transaction: linked)

        result = totals

        assert_equal 1, result.visits, "one fuelling, counted once"
        assert_equal 20.0, result.litres
        assert_equal 100.0, result.discount
      end

      # A visit is a DAY SERVED, matching what Cadence reports on the profile, so a
      # customer whose profile reads "2 visits" is found by a "visited at least 2
      # times" filter. Litres and discount are sums over every row, so they and the
      # visit count deliberately answer different questions on the same line.
      test "two fuellings on one day are one visit, matching the profile" do
        transaction_on(Time.zone.local(2026, 7, 10, 8, 0), litres: 5, discount: 1)
        transaction_on(Time.zone.local(2026, 7, 10, 20, 0), litres: 5, discount: 1)
        capture_on(Date.new(2026, 7, 12), litres: 5, discount: 1)

        result = totals

        assert_equal 2, result.visits, "10 Jul and 12 Jul — days served, not fuellings"
        assert_equal 15.0, result.litres, "but litres sum all three fuellings"
        assert_equal 3.0, result.discount
        assert_equal 2, CustomerInsight.new(@customer).cadence.visit_count,
          "the cohort filter and the profile must agree, or a filtered list contradicts the page it links to"
      end

      test "anonymous captures belong to nobody" do
        VisitEntry.create!(customer: nil, user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 10),
                           vehicle_number: "TN09ZZ9999", litres: 40, discount_amount: 9)

        assert_equal 0.0, totals.litres
      end

      test "gifts are the rupee value of redemptions and points are the running balance" do
        @customer.points_ledgers.create!(entry_type: :earn, points: 120, cash_reward_amount: 0)
        @customer.points_ledgers.create!(entry_type: :redeem, points: -50, cash_reward_amount: 75)

        result = totals

        assert_equal 75.0, result.gifts
        assert_equal 70, result.points
      end

      test "contacts count outreach events" do
        2.times do |index|
          @customer.contact_logs.create!(user: @staff, channel: "call", outcome: "reached",
                                         contacted_at: Time.zone.local(2026, 7, 10 + index, 10, 0))
        end

        assert_equal 2, totals.contacts
      end

      test "a period narrows the flows but never the points balance" do
        transaction_on(Time.zone.local(2026, 7, 10, 9, 0), litres: 10, discount: 5)
        transaction_on(Time.zone.local(2026, 8, 10, 9, 0), litres: 30, discount: 11)
        @customer.points_ledgers.create!(entry_type: :earn, points: 200, cash_reward_amount: 0,
                                         created_at: Time.zone.local(2026, 8, 10, 9, 0))
        @customer.points_ledgers.create!(entry_type: :redeem, points: -20, cash_reward_amount: 40,
                                         created_at: Time.zone.local(2026, 7, 10, 9, 0))

        july = Time.zone.local(2026, 7, 1).beginning_of_day..Time.zone.local(2026, 7, 31).end_of_day
        result = totals(period_range: july)

        assert_equal 10.0, result.litres
        assert_equal 5.0, result.discount
        assert_equal 1, result.visits
        assert_equal 40.0, result.gifts
        assert_equal 180, result.points, "the balance is a stock and stays lifetime"
      end

      test "a customer with no activity reports zeroes rather than nils" do
        result = totals

        assert_equal 0, result.visits
        assert_equal 0.0, result.litres
        assert_equal 0.0, result.discount
        assert_equal 0.0, result.gifts
        assert_equal 0, result.contacts
        assert_equal 0, result.points
      end

      # "Accumulated x reward points" has two honest readings, so it is two
      # filters. This customer is the proof they are not aliases of each other:
      # 5,000 earned, 4,800 spent, 200 left. The earned filter finds them; the
      # balance filter — which is what min_points has always meant — cannot.
      test "the earned and balance point thresholds are genuinely different filters" do
        @customer.points_ledgers.create!(entry_type: :earn, points: 5_000)
        @customer.points_ledgers.create!(entry_type: :redeem, points: -4_800, cash_reward_amount: 1_200)

        assert_equal 200, totals.points, "the balance is what is left"

        assert_includes cohort_ids(min_points_earned: 5_000), @customer.id
        assert_not_includes cohort_ids(min_points: 5_000), @customer.id
        assert_includes cohort_ids(min_points: 200), @customer.id
        assert_not_includes cohort_ids(min_points_earned: 5_001), @customer.id
      end

      test "points earned follow the selected period while the balance stays lifetime" do
        transaction_on(Time.zone.local(2026, 7, 10, 9, 0), litres: 10, discount: 0)
        @customer.points_ledgers.create!(entry_type: :earn, points: 200,
                                         created_at: Time.zone.local(2026, 7, 10, 9, 0))
        @customer.points_ledgers.create!(entry_type: :earn, points: 300,
                                         created_at: Time.zone.local(2026, 8, 10, 9, 0))

        july = Time.zone.local(2026, 7, 1).beginning_of_day..Time.zone.local(2026, 7, 31).end_of_day

        assert_includes cohort_ids(period_range: july, min_points_earned: 200), @customer.id
        assert_not_includes cohort_ids(period_range: july, min_points_earned: 201), @customer.id,
          "August's 300 points were not earned in July"
        assert_includes cohort_ids(period_range: july, min_points: 500), @customer.id,
          "the balance is a stock and is never windowed, even when a period is set"
      end

      # docs/acefuels/13-spec-customer-crm-capture.md pins these two to the same
      # rule: Customer#discount_total owns it for one customer, this class owns the
      # set-wise twin for a whole list. Change one and change the other.
      test "the set-wise discount rule agrees with Customer#discount_total" do
        linked = transaction_on(Time.zone.local(2026, 7, 10, 9, 0), litres: 10, discount: 5)
        capture_on(Date.new(2026, 7, 10), litres: 10, discount: 5, transaction: linked)
        transaction_on(Time.zone.local(2026, 7, 11, 9, 0), litres: 8, discount: 3)
        capture_on(Date.new(2026, 7, 12), litres: 6, discount: 7)

        assert_equal @customer.discount_total.to_f, totals.discount
        assert_equal 15.0, totals.discount
      end

      test "thresholds ignore blank, negative, non-numeric and oversized values" do
        normalized = CustomerMetrics.normalize_thresholds(
          min_visits: "3", min_litres: "12.5", min_contacts: "", min_discount: "-4",
          min_points: "abc", min_points_earned: "750"
        )

        assert_equal({ min_visits: 3, min_litres: BigDecimal("12.5"), min_points_earned: 750 }, normalized)
        assert_empty CustomerMetrics.normalize_thresholds(min_litres: "12345678901234")
      end

      test "counting thresholds are read as decimal and stay inside what Postgres can compare" do
        assert_equal({ min_visits: 10 }, CustomerMetrics.normalize_thresholds(min_visits: "010"))
        assert_empty CustomerMetrics.normalize_thresholds(min_visits: "0x10")
        assert_empty CustomerMetrics.normalize_thresholds(min_points: "9223372036854775808")
      end
    end
  end
end
