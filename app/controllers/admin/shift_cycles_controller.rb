module Admin
  class ShiftCyclesController < BaseController
    MAX_STEP_SLOTS = 12

    def index
      authorize ShiftCycle
      load_index_state
    end

    def create
      @shift_cycle = ShiftCycle.new
      authorize @shift_cycle

      if save_shift_cycle(@shift_cycle, step_template_ids)
        redirect_to admin_shift_cycles_path, notice: "Shift cycle created successfully."
      else
        load_index_state(new_shift_cycle: @shift_cycle, new_step_template_ids: step_template_ids)
        render :index, status: :unprocessable_entity
      end
    end

    def update
      @shift_cycle = ShiftCycle.find(params[:id])
      authorize @shift_cycle

      if save_shift_cycle(@shift_cycle, step_template_ids)
        redirect_to admin_shift_cycles_path, notice: "Shift cycle updated successfully."
      else
        load_index_state(edit_shift_cycle: @shift_cycle, edit_step_template_ids: step_template_ids)
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      @shift_cycle = ShiftCycle.find(params[:id])
      authorize @shift_cycle

      if @shift_cycle.deletable?
        @shift_cycle.destroy!
        redirect_to admin_shift_cycles_path, notice: "Shift cycle deleted successfully."
      else
        redirect_to admin_shift_cycles_path, alert: "This shift cycle already has staff assignment history. Deactivate it instead of deleting it."
      end
    end

    def activate
      update_active_state!(true, "Shift cycle activated successfully.")
    end

    def deactivate
      update_active_state!(false, "Shift cycle deactivated successfully.")
    end

    private

    def load_index_state(new_shift_cycle: ShiftCycle.new(active: true, starts_on: Date.current),
      edit_shift_cycle: nil,
      new_step_template_ids: nil,
      edit_step_template_ids: nil)
      @shift_templates = ShiftTemplate.active.order(:name, :start_time, :duration_minutes)
      @shift_cycles = ShiftCycle.includes(:shift_assignments, shift_cycle_steps: :shift_template).order(:name, :starts_on)
      @shift_cycle = new_shift_cycle
      @edit_shift_cycle = edit_shift_cycle
      @new_shift_cycle_step_ids = padded_step_ids(new_step_template_ids)
      @edit_shift_cycle_step_ids = padded_step_ids(edit_step_template_ids || edit_shift_cycle&.shift_cycle_steps&.map(&:shift_template_id))
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
      params.require(:shift_cycle).permit(:name, :starts_on, :active)
    end

    def step_template_ids
      Array(params.dig(:shift_cycle, :step_shift_template_ids)).map(&:presence).compact
    end

    def padded_step_ids(ids)
      step_ids = Array(ids).map(&:presence).compact
      step_ids.first(MAX_STEP_SLOTS).tap do |padded|
        padded << nil while padded.length < MAX_STEP_SLOTS
      end
    end

    def update_active_state!(active, notice_message)
      @shift_cycle = ShiftCycle.find(params[:id])
      authorize @shift_cycle, :update?
      @shift_cycle.update!(active: active)
      redirect_to admin_shift_cycles_path, notice: notice_message
    end
  end
end
