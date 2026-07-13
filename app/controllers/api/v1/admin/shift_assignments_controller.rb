module Api
  module V1
    module Admin
      # Admin shift-assignment create, nested under a staff member (04.10 logic):
      # build with effective_from = now truncated to the minute, link the template's
      # current cycle, close any overlapping active assignments 1s before the new one,
      # then save — all inside a transaction.
      class ShiftAssignmentsController < Api::V1::Admin::BaseController
        # POST /api/v1/admin/staff_members/:staff_member_id/shift_assignments
        # { shift_assignment: { shift_template_id, notes } }
        def create
          staff_member = User.kept.where(role: :staff).find(params[:staff_member_id])
          shift_assignment = staff_member.shift_assignments.build(notes: shift_assignment_params[:notes], active: true)
          shift_assignment.shift_template = ShiftTemplate.find_by(id: shift_assignment_params[:shift_template_id])
          shift_assignment.effective_from = Time.zone.now.change(sec: 0)
          shift_assignment.shift_cycle = shift_assignment.shift_template&.current_shift_cycle(at: shift_assignment.effective_from)
          authorize shift_assignment, :create?

          validate_shift_assignment!(shift_assignment)

          ShiftAssignment.transaction do
            close_current_assignments!(staff_member, shift_assignment)
            shift_assignment.save!
          end

          render json: ShiftAssignmentSerializer.call(shift_assignment), status: :created
        end

        private

        def shift_assignment_params
          resource_params(:shift_assignment).permit(:shift_template_id, :notes)
        end

        def validate_shift_assignment!(shift_assignment)
          shift_assignment.errors.add(:shift_template, "must be selected") if shift_assignment.shift_template.blank?
          if shift_assignment.shift_template.present? && shift_assignment.effective_from.blank?
            shift_assignment.errors.add(:effective_from, "must be present")
          end
          raise ActiveRecord::RecordInvalid, shift_assignment if shift_assignment.errors.any?
        end

        def close_current_assignments!(staff_member, shift_assignment)
          effective_from = shift_assignment.effective_from
          staff_member.shift_assignments.active.effective_at(effective_from).find_each do |assignment|
            assignment.update!(effective_to: effective_from - 1.second)
          end
        end
      end
    end
  end
end
