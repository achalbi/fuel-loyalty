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

    # GET /admin/staff_members/:id/pump — admin assigns the operator default or a daily override (A10).
    def pump
      @staff_member = staff_member_for_pump
      authorize @staff_member, :assign_pump?
      load_pump_form_state
    end

    # PATCH /admin/staff_members/:id/pump
    def update_pump
      @staff_member = staff_member_for_pump
      authorize @staff_member, :assign_pump?

      saved = if assignment_mode == "default"
        @staff_member.update_default_pump_assignment(pump_assignment_params)
      else
        @staff_member.update_pump_assignment(pump_assignment_params, on: assignment_date, assigned_by: current_user)
      end

      if saved
        redirect_to admin_staff_members_path, notice: "#{assignment_mode == "default" ? "Default pump" : "Daily pump override"} updated for #{@staff_member.name}."
      else
        load_pump_form_state
        render :pump, status: :unprocessable_entity
      end
    end

    private

    def staff_member_for_pump
      User.kept.where(role: :staff).find(params[:id])
    end

    def load_pump_form_state
      @assignable_fuel_pumps = FuelPump.includes(nozzles: :fuel_type_record).ordered.to_a
      @assignable_fuel_pump_nozzles = @assignable_fuel_pumps.index_with do |fuel_pump|
        fuel_pump.nozzles.active.ordered.to_a
      end
      @assignment_mode = assignment_mode
      @assignment_date = assignment_date
      @daily_pump_assignment = @assignment_mode == "override" ? @staff_member.pump_assignment_for(on: @assignment_date) : nil
    end

    def pump_assignment_params
      params.require(:user).permit(:fuel_pump_id, :assignment_date, assigned_fuel_pump_nozzle_ids: [])
    end

    def assignment_mode
      raw = params[:assignment_mode].presence || params.dig(:user, :assignment_mode).presence
      return raw if %w[default override].include?(raw)

      date_requested = params[:assignment_date].presence || params.dig(:user, :assignment_date).presence
      date_requested.present? ? "override" : "default"
    end

    def assignment_date
      raw = params[:assignment_date].presence || params.dig(:user, :assignment_date).presence
      Date.iso8601(raw.to_s)
    rescue ArgumentError, TypeError
      Date.current
    end

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
