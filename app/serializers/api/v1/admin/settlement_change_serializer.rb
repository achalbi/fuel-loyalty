module Api
  module V1
    module Admin
      # D9 audit row — who/when/reason/diffs, plus whether the edit recomputed
      # loyalty points.
      class SettlementChangeSerializer
        def self.call(change)
          {
            id: change.id,
            changed_by: change.changed_by&.display_name,
            change_reason: change.change_reason,
            field_diffs: change.field_diffs,
            recomputed_points: change.recomputed_points,
            created_at: change.created_at&.iso8601,
          }
        end
      end
    end
  end
end
