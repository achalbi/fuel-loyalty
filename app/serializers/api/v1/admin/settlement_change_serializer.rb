module Api
  module V1
    module Admin
      # D9 audit row — who/when/reason/diffs, plus whether the edit recomputed
      # loyalty points. `on_behalf_of` is the FSM an admin entered the edit for
      # (Admin-12); `changed_by` stays the admin who made it.
      class SettlementChangeSerializer
        def self.call(change)
          {
            id: change.id,
            changed_by: change.changed_by&.display_name,
            on_behalf_of: change.on_behalf_of&.display_name,
            on_behalf_of_id: change.on_behalf_of_id,
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
