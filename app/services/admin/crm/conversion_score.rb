module Admin
  module Crm
    # E5 — a transparent 0..100 conversion-probability heuristic (NOT ML). It blends
    # three signals: how frequently the customer visits, how overdue they are versus
    # their own cadence, and the outcome of the most recent outreach. Documented as a
    # rule so the number is explainable on the dashboard.
    class ConversionScore
      BASE = 50
      FREQUENCY_CAP = 20 # +1 per visit day, capped

      OUTCOME_DELTA = {
        "converted" => 20,
        "reached" => 10,
        "callback_requested" => 5,
        "no_answer" => -5,
        "declined" => -20
      }.freeze

      # cadence: Admin::Crm::Cadence::Result. last_outcome: String or nil.
      def self.call(cadence:, last_outcome: nil)
        new(cadence: cadence, last_outcome: last_outcome).call
      end

      def initialize(cadence:, last_outcome: nil)
        @cadence = cadence
        @last_outcome = last_outcome.to_s.presence
      end

      def call
        return 0 if @cadence.visit_count.to_i.zero?

        score = BASE
        score += [@cadence.visit_count.to_i, FREQUENCY_CAP].min
        score += recency_delta
        score += OUTCOME_DELTA.fetch(@last_outcome, 0)
        score.clamp(0, 100)
      end

      private

      def recency_delta
        days = @cadence.days_since_last_visit.to_i
        gap = @cadence.median_gap_days

        if gap.to_i.positive?
          ratio = days.to_f / gap
          return 15 if ratio <= 1.0   # on schedule or early
          return 0 if ratio <= 2.0    # slipping
          -25                          # long overdue
        else
          # No established cadence — judge on raw recency.
          return 10 if days <= 14
          return 0 if days <= 45
          -15
        end
      end
    end
  end
end
