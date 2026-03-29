module Admin
  class VehicleTypesController < BaseController
    before_action :set_vehicle_type, only: %i[edit update destroy]

    def index
      authorize VehicleType
      load_index_state
    end

    def create
      authorize VehicleType
      @vehicle_type = VehicleType.new(vehicle_type_create_params)

      if @vehicle_type.save
        redirect_to admin_vehicle_types_path, notice: "Vehicle type added successfully."
      else
        load_index_state(new_vehicle_type: @vehicle_type)
        flash.now[:alert] = @vehicle_type.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      authorize @vehicle_type
    end

    def update
      authorize @vehicle_type

      if @vehicle_type.update(vehicle_type_update_params)
        redirect_to admin_vehicle_types_path, notice: "Vehicle type updated successfully."
      else
        flash.now[:alert] = @vehicle_type.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @vehicle_type

      if @vehicle_type.destroy
        redirect_to admin_vehicle_types_path, notice: "Vehicle type removed successfully."
      else
        redirect_to admin_vehicle_types_path, alert: @vehicle_type.errors.full_messages.to_sentence
      end
    end

    private

    def set_vehicle_type
      @vehicle_type = VehicleType.find(params[:id])
    end

    def load_index_state(new_vehicle_type: VehicleType.new(active: true))
      @vehicle_type = new_vehicle_type
      @vehicle_types = VehicleType.for_settings
    end

    def vehicle_type_create_params
      params.require(:vehicle_type).permit(:name, :short_name, :app_label_source, :code, :icon_name, :active)
    end

    def vehicle_type_update_params
      params.require(:vehicle_type).permit(:name, :short_name, :app_label_source, :icon_name, :active)
    end
  end
end
