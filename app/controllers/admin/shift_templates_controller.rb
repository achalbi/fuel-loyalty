module Admin
  class ShiftTemplatesController < BaseController
    def index
      authorize ShiftTemplate
      load_index_state
    end

    def create
      @shift_template = ShiftTemplate.new
      authorize @shift_template
      @shift_template.assign_attributes(shift_template_params)

      if @shift_template.save
        redirect_to admin_shift_templates_path, notice: "Shift template created successfully."
      else
        load_index_state(new_shift_template: @shift_template)
        render :index, status: :unprocessable_entity
      end
    end

    def update
      @shift_template = ShiftTemplate.find(params[:id])
      authorize @shift_template

      if @shift_template.update(shift_template_params)
        redirect_to admin_shift_templates_path, notice: "Shift template updated successfully."
      else
        load_index_state(edit_shift_template: @shift_template)
        render :index, status: :unprocessable_entity
      end
    end

    private

    def load_index_state(new_shift_template: ShiftTemplate.new(active: true), edit_shift_template: nil)
      @shift_templates = ShiftTemplate.order(:name, :duration_minutes)
      @shift_template = new_shift_template
      @edit_shift_template = edit_shift_template
    end

    def shift_template_params
      params.require(:shift_template).permit(:name, :start_time, :duration_hours, :duration_minutes, :active)
    end
  end
end
