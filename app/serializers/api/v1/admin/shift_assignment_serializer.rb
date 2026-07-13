module Api
  module V1
    module Admin
      # Admin shift-assignment payload. effective_from = now truncated to the
      # minute at create time; the linked template + current cycle are embedded.
      class ShiftAssignmentSerializer
        def self.call(shift_assignment)
          {
            id: shift_assignment.id,
            user_id: shift_assignment.user_id,
            active: shift_assignment.active,
            notes: shift_assignment.notes,
            effective_from: shift_assignment.effective_from&.iso8601,
            effective_to: shift_assignment.effective_to&.iso8601,
            shift_template: template_json(shift_assignment.shift_template),
            shift_cycle: cycle_json(shift_assignment.shift_cycle),
            created_at: shift_assignment.created_at&.iso8601,
            updated_at: shift_assignment.updated_at&.iso8601,
          }
        end

        def self.template_json(shift_template)
          return if shift_template.nil?

          Api::V1::Admin::ShiftTemplateSerializer.call(shift_template)
        end

        def self.cycle_json(shift_cycle)
          return if shift_cycle.nil?

          { id: shift_cycle.id, name: shift_cycle.name, sequence_label: shift_cycle.sequence_label }
        end
      end
    end
  end
end
