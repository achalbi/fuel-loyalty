module Api
  module V1
    module Admin
      # Admin shift-cycle payload with its ordered steps (position 1-based).
      # cycle length is derived from summed step durations (period_days unused).
      class ShiftCycleSerializer
        def self.call(shift_cycle)
          {
            id: shift_cycle.id,
            name: shift_cycle.name,
            active: shift_cycle.active,
            starts_on: shift_cycle.starts_on&.iso8601,
            starts_at_label: shift_cycle.starts_at_label,
            sequence_label: shift_cycle.sequence_label,
            schedule_label: shift_cycle.schedule_label,
            cycle_duration_minutes: shift_cycle.cycle_duration_minutes,
            cycle_duration_label: shift_cycle.cycle_duration_label,
            deletable: shift_cycle.deletable?,
            steps: shift_cycle.shift_cycle_steps.map { |step| step_json(step) },
            created_at: shift_cycle.created_at&.iso8601,
            updated_at: shift_cycle.updated_at&.iso8601,
          }
        end

        def self.step_json(step)
          {
            position: step.position,
            shift_template_id: step.shift_template_id,
            shift_template_name: step.shift_template&.name,
          }
        end
      end
    end
  end
end
