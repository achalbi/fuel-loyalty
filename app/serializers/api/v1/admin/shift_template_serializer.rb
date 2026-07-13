module Api
  module V1
    module Admin
      # Admin shift-template payload (docs/native-handoff backend-map:
      # subsystem-models-shift-attendance -> ShiftTemplate). Exposes both the
      # persisted duration_minutes and the derived duration_hours virtual value.
      class ShiftTemplateSerializer
        def self.call(shift_template)
          {
            id: shift_template.id,
            name: shift_template.name,
            active: shift_template.active,
            start_time: shift_template.start_time,
            start_time_label: shift_template.start_time_label,
            duration_minutes: shift_template.duration_minutes,
            duration_hours: shift_template.duration_hours,
            duration_label: shift_template.duration_label,
            schedule_label: shift_template.schedule_label,
            created_at: shift_template.created_at&.iso8601,
            updated_at: shift_template.updated_at&.iso8601,
          }
        end
      end
    end
  end
end
