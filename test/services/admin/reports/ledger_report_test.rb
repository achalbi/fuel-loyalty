require "test_helper"

module Admin
  module Reports
    class LedgerReportTest < ActiveSupport::TestCase
      setup do
        @pump = fuel_pumps(:one)
        @staff = users(:two)
        @customer = customers(:one)
        Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 100)

        # Two same-transporter visits in July, one in a different month.
        VisitEntry.create!(user: @staff, fuel_pump: @pump, customer: @customer, entry_date: Date.new(2026, 7, 5),
                           vehicle_number: "KA01AA0001", litres: 40, discount_amount: 100, fuel_type_code: "petrol",
                           transport_name: "NL Roadways", driver_name: "Rao")
        VisitEntry.create!(user: @staff, fuel_pump: @pump, customer: @customer, entry_date: Date.new(2026, 7, 20),
                           vehicle_number: "KA01AA0002", litres: 60, discount_amount: 50, fuel_type_code: "petrol",
                           transport_name: "NL Roadways", driver_name: "Singh")
        VisitEntry.create!(user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 6, 10),
                           vehicle_number: "KA01AA0003", litres: 10, discount_amount: 0, fuel_type_code: "petrol",
                           transport_name: "Other")

        # A reward redemption in July → the customer's "gifts".
        @customer.points_ledgers.create!(entry_type: :redeem, points: -100, cash_reward_amount: 75, created_at: Time.zone.local(2026, 7, 10))
      end

      test "aggregates by transporter/month with derived amount, discount and gifts" do
        report = LedgerReport.new(dimension: "transporter", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        nl = report.rows.find { |r| r.key == "NL Roadways" }

        assert_equal "2026-07", nl.period
        assert_equal 100.0, nl.litres          # 40 + 60
        assert_equal 10000.0, nl.amount        # (40+60) × ₹100
        assert_equal 150.0, nl.discount        # 100 + 50
        assert_equal 75.0, nl.gifts            # the July redemption
        assert_equal 2, nl.visits

        assert_equal 100.0, report.totals[:litres]
        assert_nil report.rows.find { |r| r.key == "Other" }, "June visit excluded from July range"
      end

      test "driver dimension splits the two visits" do
        report = LedgerReport.new(dimension: "driver", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        assert_equal %w[Rao Singh], report.rows.map(&:key).sort
      end

      test "amount is blank when no catalog price exists for the fuel" do
        Product.where(category: "fuel").update_all(active: false)
        report = LedgerReport.new(dimension: "vehicle", grain: "day", start_date: "2026-07-05", end_date: "2026-07-05")
        assert_nil report.rows.first.amount
        assert_equal 40.0, report.rows.first.litres
      end

      test "CSV export has a header, rows and a total line" do
        report = LedgerReport.new(dimension: "transporter", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        csv = report.to_csv
        assert_includes csv, "key,label,period,litres,amount,discount,gifts,visits"
        assert_includes csv, "NL Roadways"
        assert_includes csv, "TOTAL"
      end
    end
  end
end
