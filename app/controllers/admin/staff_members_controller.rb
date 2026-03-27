module Admin
  class StaffMembersController < BaseController
    def index
      authorize User
      @staff_members = staff_members_scope
      @edit_staff_member = nil
      @assignment_form_user_id = nil
      @shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)
      @active_staff_count = @staff_members.count(&:active?)
      @inactive_staff_count = @staff_members.count { |staff_member| !staff_member.active? }
      @unassigned_staff_count = @staff_members.count { |staff_member| staff_member.current_shift_template.blank? }
    end

    def update
      @staff_member = User.kept.where(role: :staff).find(params[:id])
      authorize @staff_member

      if @staff_member.update(staff_member_params)
        redirect_to admin_staff_members_path, notice: "Staff member updated successfully."
      else
        @staff_members = staff_members_scope
        @edit_staff_member = @staff_member
        @assignment_form_user_id = nil
        @shift_templates = ShiftTemplate.active.order(:name, :duration_minutes)
        @active_staff_count = @staff_members.count(&:active?)
        @inactive_staff_count = @staff_members.count { |staff_member| !staff_member.active? }
        @unassigned_staff_count = @staff_members.count { |staff_member| staff_member.current_shift_template.blank? }
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      @staff_member = User.kept.where(role: :staff).find(params[:id])
      authorize @staff_member

      @staff_member.soft_delete!
      redirect_to admin_staff_members_path, notice: "Staff member soft deleted successfully. Historical records were kept."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_staff_members_path, alert: @staff_member.errors.full_messages.to_sentence.presence || "Unable to soft delete this staff member."
    end

    private

    def staff_members_scope
      User.kept.where(role: :staff)
        .includes(shift_assignments: [{ shift_template: { shift_cycles: { shift_cycle_steps: :shift_template } } }, { shift_cycle: { shift_cycle_steps: :shift_template } }])
        .order(:name, :username, :phone_number)
    end

    def staff_member_params
      params.require(:user).permit(:name, :active, :employee_code, :subtitle)
    end
  end
end
