module Api
  module V1
    module Admin
      # Admin staff-member payload: reuses the shared Api::V1::UserSerializer for
      # the base user fields and augments it with the currently-assigned shift
      # template + cycle (resolved via User#current_shift_template / #current_shift_cycle).
      class StaffMemberSerializer
        def self.call(user)
          Api::V1::UserSerializer.call(user).merge(
            current_shift_template: current_template_json(user),
            current_shift_cycle: current_cycle_json(user),
          )
        end

        def self.current_template_json(user)
          template = user.current_shift_template
          return if template.nil?

          Api::V1::Admin::ShiftTemplateSerializer.call(template)
        end

        def self.current_cycle_json(user)
          cycle = user.current_shift_cycle
          return if cycle.nil?

          { id: cycle.id, name: cycle.name, sequence_label: cycle.sequence_label }
        end
      end
    end
  end
end
