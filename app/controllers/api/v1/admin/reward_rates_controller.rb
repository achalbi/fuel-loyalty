module Api
  module V1
    module Admin
      # GET/PATCH /api/v1/admin/reward_rates
      #
      # JSON mirror of the web Admin::FuelRewardRatesController: a single
      # settings endpoint whose PATCH dispatches by which param group is present.
      # Precedence (first non-blank group wins, matching the web):
      #   reward_setting > vehicle_type_reward_rates > fuel_reward_rates
      # Validation failures raise ActiveRecord::RecordInvalid and are rendered as
      # 422 by Api::V1::BaseController.
      class RewardRatesController < Api::V1::Admin::BaseController
        # GET /api/v1/admin/reward_rates
        def show
          authorize FuelRewardRate, :show?
          authorize VehicleType, :index?
          @reward_setting = RewardSetting.current
          authorize @reward_setting, :show?

          load_settings
          render json: reward_rates_payload, status: :ok
        end

        # PATCH /api/v1/admin/reward_rates
        def update
          authorize FuelRewardRate, :update?
          authorize VehicleType, :update?
          @reward_setting = RewardSetting.current
          authorize @reward_setting, :update?

          notice =
            if reward_setting_params.present?
              @reward_setting.update!(reward_setting_params)
              "Reward settings updated successfully."
            elsif permitted_vehicle_type_rate_params.present?
              update_vehicle_type_reward_rates!
              "Vehicle-type reward rates updated successfully."
            else
              update_fuel_reward_rates!
              "Fuel reward rates updated successfully."
            end

          load_settings
          render json: reward_rates_payload.merge(message: notice), status: :ok
        end

        private

        def reward_rates_payload
          Api::V1::Admin::RewardRatesSerializer.call(@reward_setting, @vehicle_types, @fuel_reward_rates)
        end

        def load_settings
          @reward_setting ||= RewardSetting.current
          @vehicle_types = VehicleType.for_settings
          @fuel_reward_rates = FuelRewardRate.for_settings
        end

        def update_vehicle_type_reward_rates!
          ActiveRecord::Base.transaction do
            permitted_vehicle_type_rate_params.each do |vehicle_type_code, attributes|
              vehicle_type = VehicleType.find_by!(code: vehicle_type_code)
              vehicle_type.update!(reward_points_per_100: attributes[:reward_points_per_100])
            end
          end
        end

        def update_fuel_reward_rates!
          ActiveRecord::Base.transaction do
            permitted_rate_params.each do |fuel_type, attributes|
              rate = FuelRewardRate.find_or_initialize_by(fuel_type: fuel_type)
              rate.points_per_100 = attributes[:points_per_100]
              rate.save!
            end
          end
        end

        def permitted_vehicle_type_rate_params
          permitted_attributes = VehicleType.for_settings.map(&:code).index_with { [:reward_points_per_100] }

          params.fetch(:vehicle_type_reward_rates, ActionController::Parameters.new)
                .permit(permitted_attributes).to_h.deep_symbolize_keys
        end

        def permitted_rate_params
          permitted_attributes = FuelRewardRate.setting_fuel_type_values.index_with { [:points_per_100] }

          params.fetch(:fuel_reward_rates, ActionController::Parameters.new)
                .permit(permitted_attributes).to_h.deep_symbolize_keys
        end

        def reward_setting_params
          params.fetch(:reward_setting, ActionController::Parameters.new)
                .permit(:rupees_per_reward_unit, :cash_value_per_point, :minimum_redeemable_points, :rewards_paused)
        end
      end
    end
  end
end
