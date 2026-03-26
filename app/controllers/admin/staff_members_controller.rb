module Admin
  class StaffMembersController < BaseController
    def index
      authorize User
      @staff_members = User.where(role: :staff).includes(shift_assignments: [{ shift_template: { shift_cycles: { shift_cycle_steps: :shift_template } } }, { shift_cycle: { shift_cycle_steps: :shift_template } }]).order(:username, :phone_number)
      @edit_staff_member = nil
      @assignment_form_user_id = nil
      @shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)
      @active_staff_count = @staff_members.count(&:active?)
      @inactive_staff_count = @staff_members.count { |staff_member| !staff_member.active? }
      @unassigned_staff_count = @staff_members.count { |staff_member| staff_member.current_shift_template.blank? }
    end

    def update
      @staff_member = User.where(role: :staff).find(params[:id])
      authorize @staff_member

      if @staff_member.update(staff_member_params)
        redirect_to admin_staff_members_path, notice: "Staff member updated successfully."
      else
        @staff_members = User.where(role: :staff).includes(shift_assignments: [{ shift_template: { shift_cycles: { shift_cycle_steps: :shift_template } } }, { shift_cycle: { shift_cycle_steps: :shift_template } }]).order(:username, :phone_number)
        @edit_staff_member = @staff_member
        @assignment_form_user_id = nil
        @shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)
        @active_staff_count = @staff_members.count(&:active?)
        @inactive_staff_count = @staff_members.count { |staff_member| !staff_member.active? }
        @unassigned_staff_count = @staff_members.count { |staff_member| staff_member.current_shift_template.blank? }
        render :index, status: :unprocessable_entity
      end
    end

    private

    def staff_member_params
      params.require(:user).permit(:active, :employee_code, :subtitle)
    end
  end
end
