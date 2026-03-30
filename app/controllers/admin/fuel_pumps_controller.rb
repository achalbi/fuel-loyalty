module Admin
  class FuelPumpsController < BaseController
    before_action :set_fuel_pump, only: %i[edit update destroy]

    def index
      authorize FuelPump
      load_index_state
    end

    def create
      authorize FuelPump
      @fuel_pump = FuelPump.new(fuel_pump_params)

      if @fuel_pump.save
        redirect_to admin_fuel_pumps_path, notice: "#{@fuel_pump.display_name} added successfully."
      else
        load_index_state(new_fuel_pump: @fuel_pump)
        flash.now[:alert] = @fuel_pump.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      authorize @fuel_pump
      prepare_fuel_pump_form(@fuel_pump)
    end

    def update
      authorize @fuel_pump

      if @fuel_pump.update(fuel_pump_params)
        redirect_to admin_fuel_pumps_path, notice: "#{@fuel_pump.display_name} updated successfully."
      else
        prepare_fuel_pump_form(@fuel_pump)
        flash.now[:alert] = @fuel_pump.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @fuel_pump
      pump_name = @fuel_pump.display_name

      if @fuel_pump.destroy
        redirect_to admin_fuel_pumps_path, notice: "#{pump_name} removed successfully."
      else
        redirect_to admin_fuel_pumps_path, alert: @fuel_pump.errors.full_messages.to_sentence
      end
    end

    private

    def set_fuel_pump
      @fuel_pump = FuelPump.includes(nozzles: :fuel_type_record).find(params[:id])
    end

    def load_index_state(new_fuel_pump: build_new_fuel_pump)
      @fuel_pump = prepare_fuel_pump_form(new_fuel_pump)
      @fuel_pumps = FuelPump.for_settings
    end

    def build_new_fuel_pump
      FuelPump.new(active: true).tap do |fuel_pump|
        fuel_pump.nozzles.build(active: true)
      end
    end

    def prepare_fuel_pump_form(fuel_pump)
      return fuel_pump if fuel_pump.nozzles.reject(&:marked_for_destruction?).any?

      fuel_pump.nozzles.build(active: true)
      fuel_pump
    end

    def fuel_pump_params
      params.require(:fuel_pump).permit(
        :active,
        nozzles_attributes: [
          :id,
          :fuel_type_code,
          :active,
          :_destroy
        ]
      )
    end
  end
end
