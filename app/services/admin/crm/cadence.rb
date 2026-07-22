module Admin
  module Crm
    # E3 — classifies a customer's visit rhythm from their visit-day history.
    # Pure: takes an already-loaded array of visit Dates (one per distinct day) so
    # both the per-customer insight and the batch churn list can reuse it without
    # re-querying. "Visit" here means a day on which the customer either recorded a
    # loyalty transaction or had a captured visit_entry (see Customer.visited_between).
    class Cadence
      WINDOW_DAYS = 90
      MIN_VISITS = 3

      # median gap (days) between consecutive visits → cadence class
      CLASSES = [
        [2, "daily"],
        [10, "weekly"],
        [21, "biweekly"],
        [45, "monthly"]
      ].freeze
      OCCASIONAL = "occasional".freeze
      NEW = "new".freeze

      LABELS = {
        "daily" => "Daily", "weekly" => "Weekly", "biweekly" => "Biweekly",
        "monthly" => "Monthly", "occasional" => "Occasional", "new" => "New"
      }.freeze

      Result = Struct.new(
        :cadence_class, :cadence_label, :median_gap_days, :visit_count,
        :first_visited_on, :last_visited_on, :days_since_last_visit,
        :expected_next_visit_on, keyword_init: true
      )

      # dates: Array<Date> (any order, may contain dupes). as_of: Time/Date.
      def self.call(dates, as_of: Time.current)
        new(dates, as_of: as_of).call
      end

      def initialize(dates, as_of: Time.current)
        @dates = Array(dates).compact.map(&:to_date).uniq.sort
        @as_of = as_of.to_date
      end

      def call
        return empty if @dates.empty?

        Result.new(
          cadence_class: cadence_class,
          cadence_label: LABELS.fetch(cadence_class, "New"),
          median_gap_days: median_gap,
          visit_count: @dates.size,
          first_visited_on: @dates.first,
          last_visited_on: @dates.last,
          days_since_last_visit: (@as_of - @dates.last).to_i,
          expected_next_visit_on: expected_next
        )
      end

      private

      def empty
        Result.new(
          cadence_class: NEW, cadence_label: LABELS[NEW], median_gap_days: nil,
          visit_count: 0, first_visited_on: nil, last_visited_on: nil,
          days_since_last_visit: nil, expected_next_visit_on: nil
        )
      end

      def cadence_class
        return NEW if @dates.size < MIN_VISITS

        gap = median_gap
        return NEW if gap.nil?

        CLASSES.each { |threshold, klass| return klass if gap <= threshold }
        OCCASIONAL
      end

      # Median gap between consecutive visits. Prefers the trailing WINDOW_DAYS so a
      # customer's *current* rhythm dominates; falls back to all history when the
      # window is too sparse (a steady monthly customer still classifies).
      def median_gap
        return @median_gap if defined?(@median_gap)

        windowed = @dates.select { |d| d >= @as_of - WINDOW_DAYS }
        basis = windowed.size >= MIN_VISITS ? windowed : @dates
        @median_gap = median_of_gaps(basis)
      end

      def median_of_gaps(dates)
        return nil if dates.size < 2

        gaps = dates.each_cons(2).map { |a, b| (b - a).to_i }
        sorted = gaps.sort
        mid = sorted.size / 2
        if sorted.size.odd?
          sorted[mid]
        else
          ((sorted[mid - 1] + sorted[mid]) / 2.0).round
        end
      end

      def expected_next
        gap = median_gap
        return nil if gap.nil? || @dates.empty?

        @dates.last + gap
      end
    end
  end
end
