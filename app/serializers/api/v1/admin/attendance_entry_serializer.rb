module Api
  module V1
    module Admin
      # A single per-person attendance row within an AttendanceRun. Used by the
      # planner (unsaved built rows) and by run show/create/list responses.
      class AttendanceEntrySerializer
        def self.call(entry)
          {
            id: entry.id,
            status: entry.status, # string enum value ("present", "absent", ...)
            worker_name: entry.worker_name,
            scheduled_user: user_json(entry.scheduled_user),
            actual_user: user_json(entry.actual_user),
            replacement_user: user_json(entry.replacement_user),
            external_replacement_name: entry.external_replacement_name,
            check_in_at: entry.check_in_at&.iso8601,
            check_out_at: entry.check_out_at&.iso8601,
            overridden: entry.overridden,
            notes: entry.notes,
          }
        end

        def self.user_json(user)
          return nil if user.nil?

          Api::V1::UserSerializer.call(user)
        end
      end
    end
  end
end
