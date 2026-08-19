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

      test "visits count distinct days, not rows" do
        transaction_on(Time.zone.local(2026, 7, 10, 8, 0), litres: 5, discount: 0)
        transaction_on(Time.zone.local(2026, 7, 10, 20, 0), litres: 5, discount: 0)
        capture_on(Date.new(2026, 7, 12), litres: 5, discount: 0)

        assert_equal 2, totals.visits
      end

      test "a late-evening transaction lands on the local day, not the UTC one" do
        # 23:30 IST on the 10th is 18:00 UTC on the 10th; naive ::date would still
        # say the 10th, so use a time that crosses: 05:00 IST = 23:30 UTC previous day.
        transaction_on(Time.zone.local(2026, 7, 11, 5, 0), litres: 5, discount: 0)
        transaction_on(Time.zone.local(2026, 7, 11, 23, 0), litres: 5, discount: 0)

        assert_equal 1, totals.visits
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

      test "thresholds ignore blank, negative, non-numeric and oversized values" do
        normalized = CustomerMetrics.normalize_thresholds(
          min_visits: "3", min_litres: "12.5", min_contacts: "", min_discount: "-4", min_points: "abc"
        )

        assert_equal({ min_visits: 3, min_litres: BigDecimal("12.5") }, normalized)
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
