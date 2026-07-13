module Api
  module V1
    module Admin
      # Admin shift-cycle CRUD + activate/deactivate (mirrors web
      # Admin::ShiftCyclesController). Steps are rebuilt destructively on every
      # save inside a transaction; position is 1-based.
      class ShiftCyclesController < Api::V1::Admin::BaseController
        # GET /api/v1/admin/shift_cycles
        def index
          authorize ShiftCycle, :index?
          shift_cycles = ShiftCycle.includes(:shift_assignments, shift_cycle_steps: :shift_template).order(:name, :starts_on)
          render json: {
            shift_cycles: shift_cycles.map { |shift_cycle| ShiftCycleSerializer.call(shift_cycle) },
          }, status: :ok
        end

        # POST /api/v1/admin/shift_cycles
        # { shift_cycle: { name, starts_on, active, step_shift_template_ids: [] } }
        def create
          shift_cycle = ShiftCycle.new
          authorize shift_cycle, :create?

          if save_shift_cycle(shift_cycle, step_template_ids)
            render json: ShiftCycleSerializer.call(shift_cycle), status: :created
          else
            render_validation_error(shift_cycle)
          end
        end

        # PATCH /api/v1/admin/shift_cycles/:id
        def update
          shift_cycle = ShiftCycle.find(params[:id])
          authorize shift_cycle, :update?

          if save_shift_cycle(shift_cycle, step_template_ids)
            render json: ShiftCycleSerializer.call(shift_cycle), status: :ok
          else
            render_validation_error(shift_cycle)
          end
        end

        # DELETE /api/v1/admin/shift_cycles/:id
        def destroy
          shift_cycle = ShiftCycle.find(params[:id])
          authorize shift_cycle, :destroy?

          if shift_cycle.deletable?
            shift_cycle.destroy!
            head :no_content
          else
            render_error(status: :conflict, code: "delete_restricted",
                         message: "This shift cycle already has staff assignment history. Deactivate it instead of deleting it.")
          end
        end

        # PATCH /api/v1/admin/shift_cycles/:id/activate
        def activate
          update_active_state!(true)
        end

        # PATCH /api/v1/admin/shift_cycles/:id/deactivate
        def deactivate
          update_active_state!(false)
        end

        private

        def update_active_state!(active)
          shift_cycle = ShiftCycle.find(params[:id])
          authorize shift_cycle, :update?
          shift_cycle.update!(active: active)
          render json: ShiftCycleSerializer.call(shift_cycle), status: :ok
        end

        def save_shift_cycle(shift_cycle, selected_step_ids)
          shift_cycle.assign_attributes(shift_cycle_params)

          if selected_step_ids.empty?
            shift_cycle.errors.add(:base, "Choose at least one shift in the cycle.")
            return false
          end

          ShiftCycle.transaction do
            shift_cycle.shift_cycle_steps.destroy_all
            selected_step_ids.each_with_index do |shift_template_id, index|
              shift_cycle.shift_cycle_steps.build(shift_template_id: shift_template_id, position: index + 1)
            end
            shift_cycle.save!
          end

          true
        rescue ActiveRecord::RecordInvalid
          false
        end

        def shift_cycle_params
          resource_params(:shift_cycle).permit(:name, :starts_on, :active)
        end

        def step_template_ids
          attrs = resource_params(:shift_cycle)
          Array(attrs[:step_shift_template_ids]).map(&:presence).compact
        end

        def render_validation_error(record)
          render_error(status: 422, code: "validation_failed",
                       message: record.errors.full_messages.to_sentence.presence || "Validation failed.",
                       details: record.errors.messages)
        end
      end
    end
  end
end
