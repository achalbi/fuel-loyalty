module Admin
  class FuelTypesController < BaseController
    before_action :set_fuel_type, only: %i[edit update destroy]

    def index
      authorize FuelType
      load_index_state
    end

    def create
      authorize FuelType
      @fuel_type = FuelType.new(fuel_type_params)

      if @fuel_type.save
        redirect_to admin_fuel_types_path, notice: "Fuel type added successfully."
      else
        load_index_state(new_fuel_type: @fuel_type)
        flash.now[:alert] = @fuel_type.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      authorize @fuel_type
    end

    def update
      authorize @fuel_type

      if @fuel_type.update(fuel_type_params)
        redirect_to admin_fuel_types_path, notice: "Fuel type updated successfully."
      else
        flash.now[:alert] = @fuel_type.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @fuel_type

      if @fuel_type.destroy
        redirect_to admin_fuel_types_path, notice: "Fuel type removed successfully."
      else
        redirect_to admin_fuel_types_path, alert: @fuel_type.errors.full_messages.to_sentence
      end
    end

    private

    def set_fuel_type
      @fuel_type = FuelType.find(params[:id])
    end

    def load_index_state(new_fuel_type: FuelType.new(active: true))
      @fuel_type = new_fuel_type
      @fuel_types = FuelType.for_settings
    end

    def fuel_type_params
      params.require(:fuel_type).permit(:name, :active)
    end
  end
end
