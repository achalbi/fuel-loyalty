require "test_helper"

module Admin
  module Crm
    class ChurnReportTest < ActiveSupport::TestCase
      AS_OF = Time.zone.local(2026, 7, 22, 12, 0, 0)

      setup do
        @staff = users(:two)
        @pump = fuel_pumps(:one)
        # Fresh customers so fixture transactions (dated ~now) don't count as visits.
        @lost = Customer.create!(name: "Lost Cust", phone_number: "9111100010")
        @active = Customer.create!(name: "Active Cust", phone_number: "9111100011")
      end

      def visit(customer, date)
        VisitEntry.create!(customer: customer, user: @staff, fuel_pump: @pump, entry_date: date,
                           vehicle_number: "TN01ZZ0000", litres: 20)
      end

      # current window = this week (16th–22nd); previous = 9th–15th.
      def report
        ChurnReport.new(start_date: "2026-07-16", end_date: "2026-07-22", as_of: AS_OF).as_json
      end

      test "flags a customer who visited the previous window but not the current one" do
        visit(@lost, Date.new(2026, 7, 10))
        visit(@active, Date.new(2026, 7, 18))

        body = report
        ids = body[:customers].map { |c| c[:id] }
        assert_includes ids, @lost.id
        assert_not_includes ids, @active.id
        assert_equal 1, body[:total]
      end

      test "returns an empty list when there is no prior-period data" do
        # only a current-window visit — nobody visited the previous window
        visit(@active, Date.new(2026, 7, 18))
        assert_equal 0, report[:total]
      end

      test "reports days overdue and a conversion probability per lost customer" do
        visit(@lost, Date.new(2026, 7, 10))
        row = report[:customers].first
        assert_operator row[:days_overdue], :>=, 0
        assert_includes 0..100, row[:conversion_probability]
      end

      test "excludes inactive customers from the reach-out list" do
        @lost.update!(active: false)
        visit(@lost, Date.new(2026, 7, 10))
        assert_equal 0, report[:total]
      end
    end
  end
end
