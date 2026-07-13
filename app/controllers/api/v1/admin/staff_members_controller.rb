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

        private

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
