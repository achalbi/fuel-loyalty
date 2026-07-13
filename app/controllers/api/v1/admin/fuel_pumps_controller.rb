module Api
  module V1
    module Admin
      # JSON mirror of the web Admin::FuelPumpsController (docs/native-handoff
      # backend-map subsystem-controllers-admin-catalogs -> FuelPumps).
      #
      # index/create/update/destroy manage pumps + their nested nozzles
      # (accepts_nested_attributes_for :nozzles, allow_destroy). feature_settings
      # toggles RewardSetting.current#nozzle_feature_enabled (singleton fetch).
      #
      # Validation failures raise ActiveRecord::RecordInvalid -> base renders 422.
      # A destroy blocked by the pump's before_destroy (transactions still use it)
      # returns false rather than raising, so it is surfaced here as 409.
      class FuelPumpsController < Api::V1::Admin::BaseController
        before_action :set_fuel_pump, only: %i[update destroy]

        # GET /api/v1/admin/fuel_pumps
        def index
          authorize FuelPump, :index?
          reward_setting = RewardSetting.current
          authorize reward_setting, :show?

          render json: {
            fuel_pumps: FuelPump.for_settings.map { |pump| FuelPumpSerializer.call(pump) },
            reward_setting: reward_setting_json(reward_setting),
          }, status: :ok
        end

        # POST /api/v1/admin/fuel_pumps
        # { active, nozzles_attributes: [{ id, fuel_type_code, active, _destroy }] }
        def create
          authorize FuelPump, :create?
          fuel_pump = FuelPump.new(fuel_pump_params)
          fuel_pump.save!
          render json: FuelPumpSerializer.call(reload_fuel_pump(fuel_pump.id)), status: :created
        end

        # PATCH/PUT /api/v1/admin/fuel_pumps/:id
        def update
          authorize @fuel_pump, :update?
          @fuel_pump.update!(fuel_pump_params)
          render json: FuelPumpSerializer.call(reload_fuel_pump(@fuel_pump.id)), status: :ok
        end

        # DELETE /api/v1/admin/fuel_pumps/:id
        # Blocked (409) while transactions still reference the pump or a nozzle.
        def destroy
          authorize @fuel_pump, :destroy?
          pump_name = @fuel_pump.display_name

          if @fuel_pump.destroy
            render json: { message: "#{pump_name} removed successfully." }, status: :ok
          else
            render_error(
              status: :conflict,
              code: "delete_restricted",
              message: @fuel_pump.errors.full_messages.to_sentence.presence ||
                @fuel_pump.transaction_remove_error_message,
            )
          end
        end

        # PATCH /api/v1/admin/fuel_pumps/feature_settings
        # { reward_setting: { nozzle_feature_enabled } }
        def feature_settings
          reward_setting = RewardSetting.current
          authorize reward_setting, :update?

          reward_setting.update!(feature_setting_params)
          render json: {
            message: "Pump transaction settings updated successfully.",
            reward_setting: reward_setting_json(reward_setting),
          }, status: :ok
        end

        private

        def set_fuel_pump
          @fuel_pump = FuelPump.includes(nozzles: :fuel_type_record).find(params[:id])
        end

        def reload_fuel_pump(id)
          FuelPump.includes(nozzles: :fuel_type_record).find(id)
        end

        def reward_setting_json(reward_setting)
          { nozzle_feature_enabled: reward_setting.nozzle_feature_enabled? }
        end

        def fuel_pump_params
          resource_params(:fuel_pump).permit(
            :active,
            nozzles_attributes: %i[id fuel_type_code active _destroy],
          )
        end

        def feature_setting_params
          resource_params(:reward_setting).permit(:nozzle_feature_enabled)
        end
      end
    end
  end
end
