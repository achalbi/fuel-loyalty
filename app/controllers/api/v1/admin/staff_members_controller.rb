module Api
  module V1
    module Admin
      # Admin staff-member management (mirrors web Admin::StaffMembersController).
      # Scope is always kept (not soft-deleted) users with role :staff.
      class StaffMembersController < Api::V1::Admin::BaseController
        # GET /api/v1/admin/staff_members
        def index
          authorize User, :index?
          staff_members = staff_members_scope
          render json: {
            staff_members: staff_members.map { |staff_member| StaffMemberSerializer.call(staff_member) },
            stats: {
              active: staff_members.count(&:active?),
              inactive: staff_members.count { |staff_member| !staff_member.active? },
              unassigned: staff_members.count { |staff_member| staff_member.current_shift_template.blank? },
              total: staff_members.size,
            },
          }, status: :ok
        end

        # PATCH /api/v1/admin/staff_members/:id  { user: { name, active, employee_code, subtitle } }
        def update
          staff_member = User.kept.where(role: :staff).find(params[:id])
          authorize staff_member, :update?
          staff_member.update!(staff_member_params)
          render json: StaffMemberSerializer.call(staff_member), status: :ok
        end

        # DELETE /api/v1/admin/staff_members/:id  (soft delete; historical records kept)
        def destroy
          staff_member = User.kept.where(role: :staff).find(params[:id])
          authorize staff_member, :destroy?
          staff_member.soft_delete!
          render json: StaffMemberSerializer.call(staff_member), status: :ok
        end

        # GET /api/v1/admin/staff_members/:id/pump — default or date-specific override + catalog (A10)
        def pump
          staff_member = staff_member_for_pump
          authorize staff_member, :assign_pump?
          render json: MyPumpSerializer.call(staff_member, on: assignment_date, assignment_mode: assignment_mode), status: :ok
        end

        # PATCH /api/v1/admin/staff_members/:id/pump  { user: { assignment_mode, assignment_date, fuel_pump_id, assigned_fuel_pump_nozzle_ids: [] } }
        def update_pump
          staff_member = staff_member_for_pump
          authorize staff_member, :assign_pump?
          return render_past_override_error if past_override?

          saved = if assignment_mode == "default"
            staff_member.update_default_pump_assignment(pump_assignment_params)
          else
            staff_member.update_pump_assignment(pump_assignment_params, on: assignment_date, assigned_by: current_user)
          end

          if saved
            render json: MyPumpSerializer.call(staff_member.reload, on: assignment_date, assignment_mode: assignment_mode)
              .merge(message: "#{assignment_mode == "default" ? "Default pump" : "Daily pump override"} updated for #{staff_member.name}."), status: :ok
          else
            render_error(
              status: 422,
              code: "validation_failed",
              message: staff_member.errors.full_messages.to_sentence.presence || "Could not update the pump assignment.",
              details: staff_member.errors.messages,
            )
          end
        end

        private

        def staff_member_for_pump
          User.kept.where(role: :staff).find(params[:id])
        end

        def pump_assignment_params
          resource_params(:user).permit(:assignment_mode, :fuel_pump_id, :assignment_date, assigned_fuel_pump_nozzle_ids: [])
        end

        def assignment_mode
          raw = params[:assignment_mode].presence || resource_params(:user)[:assignment_mode].presence
          return raw if %w[default override].include?(raw)

          date_requested = params[:assignment_date].presence || resource_params(:user)[:assignment_date].presence
          date_requested.present? ? "override" : "default"
        end

        def assignment_date
          raw = params[:assignment_date].presence || resource_params(:user)[:assignment_date].presence
          Date.iso8601(raw.to_s)
        rescue ArgumentError, TypeError
          Date.current
        end

        def past_override?
          assignment_mode == "override" && assignment_date < Date.current
        end

        def render_past_override_error
          render_error(status: 422, code: "past_assignment_date",
                       message: ::Admin::StaffMembersController::PAST_OVERRIDE_MESSAGE)
        end

        def staff_members_scope
          User.kept.where(role: :staff)
              .includes(shift_assignments: [{ shift_template: { shift_cycles: { shift_cycle_steps: :shift_template } } }, { shift_cycle: { shift_cycle_steps: :shift_template } }])
              .order(:name, :username, :phone_number)
        end

        def staff_member_params
          resource_params(:user).permit(:name, :active, :employee_code, :subtitle)
        end
      end
    end
  end
end
