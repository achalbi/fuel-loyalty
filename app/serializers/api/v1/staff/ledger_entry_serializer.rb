module Api
  module V1
    module Staff
      class LedgerEntrySerializer
        LABELS = {
          "earn" => "Points Earned",
          "redeem" => "Points Redeemed",
          "expire" => "Points Expired",
          "adjust" => "Manual Adjustment",
        }.freeze

        def self.call(entry)
          {
            id: entry.id,
            entry_type: entry.entry_type,
            label: LABELS.fetch(entry.entry_type, entry.entry_type.to_s.titleize),
            points: entry.points,
            cash_reward: entry.recorded_cash_reward_amount&.to_f,
            created_at: entry.created_at.iso8601,
          }
        end
      end
    end
  end
end
