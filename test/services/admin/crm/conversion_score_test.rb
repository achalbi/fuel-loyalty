require "test_helper"

module Admin
  module Crm
    class ConversionScoreTest < ActiveSupport::TestCase
      AS_OF = Time.zone.local(2026, 7, 22, 12, 0, 0)

      def cadence_for(dates)
        Cadence.call(dates, as_of: AS_OF)
      end

      test "no visits scores zero" do
        assert_equal 0, ConversionScore.call(cadence: cadence_for([]))
      end

      test "on-schedule frequent customer scores above base" do
        # weekly, last visit 7 days ago == on schedule → base 50 + freq 3 + recency 15
        dates = [Date.new(2026, 7, 1), Date.new(2026, 7, 8), Date.new(2026, 7, 15)]
        assert_equal 68, ConversionScore.call(cadence: cadence_for(dates))
      end

      test "long-overdue customer is penalised" do
        # weekly cadence but last visit 40+ days ago → recency -25
        dates = [Date.new(2026, 5, 1), Date.new(2026, 5, 8), Date.new(2026, 5, 15)]
        score = ConversionScore.call(cadence: cadence_for(dates))
        assert_operator score, :<, 50
      end

      test "a converted outcome lifts the score and declined drops it" do
        dates = [Date.new(2026, 7, 1), Date.new(2026, 7, 8), Date.new(2026, 7, 15)]
        base = ConversionScore.call(cadence: cadence_for(dates))
        lifted = ConversionScore.call(cadence: cadence_for(dates), last_outcome: "converted")
        dropped = ConversionScore.call(cadence: cadence_for(dates), last_outcome: "declined")
        assert_equal base + 20, lifted
        assert_equal base - 20, dropped
      end

      test "a two-visit customer is scored on raw recency, not a single coincidental gap" do
        # 2 visits 80 days apart, last one 2 days ago. The old code trusted the
        # lone 80-day gap as a cadence (ratio 0.025 → +15). It must instead use raw
        # recency (days<=14 → +10): base 50 + freq 2 + recency 10 = 62, NOT 67.
        cadence = cadence_for([Date.new(2026, 5, 1), Date.new(2026, 7, 20)])
        assert_equal "new", cadence.cadence_class
        assert_equal 62, ConversionScore.call(cadence: cadence)
      end

      test "a two-visit customer long unseen is penalised via raw recency" do
        # 2 visits, last one ~100 days ago → raw recency days>45 → -15.
        cadence = cadence_for([Date.new(2026, 4, 1), Date.new(2026, 4, 6)])
        assert_equal 37, ConversionScore.call(cadence: cadence) # 50 + 2 - 15
      end

      test "score clamps between 0 and 100" do
        dates = (1..30).map { |d| Date.new(2026, 7, 1) + d } # very frequent → high freq
        high = ConversionScore.call(cadence: cadence_for(dates), last_outcome: "converted")
        assert_operator high, :<=, 100
        assert_operator high, :>=, 0
      end
    end
  end
end
