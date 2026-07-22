require "test_helper"

module Admin
  module Crm
    class CadenceTest < ActiveSupport::TestCase
      AS_OF = Time.zone.local(2026, 7, 22, 12, 0, 0)

      test "no visits is classified new with zero count" do
        result = Cadence.call([], as_of: AS_OF)
        assert_equal "new", result.cadence_class
        assert_equal 0, result.visit_count
        assert_nil result.median_gap_days
        assert_nil result.expected_next_visit_on
      end

      test "fewer than three visits is new" do
        dates = [Date.new(2026, 7, 10), Date.new(2026, 7, 17)]
        assert_equal "new", Cadence.call(dates, as_of: AS_OF).cadence_class
      end

      test "daily cadence for one-day gaps" do
        dates = (15..21).map { |d| Date.new(2026, 7, d) }
        result = Cadence.call(dates, as_of: AS_OF)
        assert_equal "daily", result.cadence_class
        assert_equal 1, result.median_gap_days
      end

      test "weekly cadence and expected next visit" do
        dates = [Date.new(2026, 7, 1), Date.new(2026, 7, 8), Date.new(2026, 7, 15)]
        result = Cadence.call(dates, as_of: AS_OF)
        assert_equal "weekly", result.cadence_class
        assert_equal 7, result.median_gap_days
        assert_equal Date.new(2026, 7, 22), result.expected_next_visit_on
        assert_equal 7, result.days_since_last_visit
      end

      test "biweekly cadence" do
        dates = [Date.new(2026, 5, 20), Date.new(2026, 6, 3), Date.new(2026, 6, 17), Date.new(2026, 7, 1)]
        assert_equal "biweekly", Cadence.call(dates, as_of: AS_OF).cadence_class
      end

      test "monthly cadence" do
        dates = [Date.new(2026, 4, 1), Date.new(2026, 5, 1), Date.new(2026, 6, 1), Date.new(2026, 7, 1)]
        assert_equal "monthly", Cadence.call(dates, as_of: AS_OF).cadence_class
      end

      test "occasional cadence for very sparse visits" do
        dates = [Date.new(2025, 10, 1), Date.new(2025, 12, 15), Date.new(2026, 3, 1)]
        assert_equal "occasional", Cadence.call(dates, as_of: AS_OF).cadence_class
      end

      test "duplicate same-day visits collapse to one visit day" do
        dates = [Date.new(2026, 7, 1), Date.new(2026, 7, 1), Date.new(2026, 7, 8), Date.new(2026, 7, 15)]
        result = Cadence.call(dates, as_of: AS_OF)
        assert_equal 3, result.visit_count
      end
    end
  end
end
