module Admin
  class ShiftAssignmentsController < BaseController
    def create
      @staff_member = User.where(role: :staff).find(params[:staff_member_id])
      @shift_assignment = @staff_member.shift_assignments.build(notes: shift_assignment_params[:notes], active: true)
      @shift_assignment.shift_template = ShiftTemplate.find_by(id: shift_assignment_params[:shift_template_id])
      @shift_assignment.effective_from = Time.zone.now.change(sec: 0)
      @shift_assignment.shift_cycle = @shift_assignment.shift_template&.current_shift_cycle(at: @shift_assignment.effective_from)
      authorize @shift_assignment

      validate_shift_assignment!

      ShiftAssignment.transaction do
        close_current_assignments!
        @shift_assignment.save!
      end

      redirect_to admin_staff_members_path, notice: "Shift assigned successfully."
    rescue ActiveRecord::RecordInvalid
      @staff_members = User.where(role: :staff).includes(shift_assignments: [{ shift_template: { shift_cycles: { shift_cycle_steps: :shift_template } } }, { shift_cycle: { shift_cycle_steps: :shift_template } }]).order(:username, :phone_number)
      @edit_staff_member = nil
      @active_staff_count = @staff_members.count(&:active?)
      @inactive_staff_count = @staff_members.count { |staff_member| !staff_member.active? }
      @unassigned_staff_count = @staff_members.count { |staff_member| staff_member.current_shift_template.blank? }
      @shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)
      @assignment_form_user_id = @staff_member.id
      render "admin/staff_members/index", status: :unprocessable_entity
    end

    private

    def shift_assignment_params
      params.require(:shift_assignment).permit(:shift_template_id, :notes)
    end

    def validate_shift_assignment!
      @shift_assignment.errors.add(:shift_template, "must be selected") if @shift_assignment.shift_template.blank?
      @shift_assignment.errors.add(:effective_from, "must be present") if @shift_assignment.shift_template.present? && @shift_assignment.effective_from.blank?
      raise ActiveRecord::RecordInvalid, @shift_assignment if @shift_assignment.errors.any?
    end

    def close_current_assignments!
      effective_from = @shift_assignment.effective_from
      @staff_member.shift_assignments.active.effective_at(effective_from).find_each do |assignment|
        assignment.update!(effective_to: effective_from - 1.second)
      end
    end
  end
end
