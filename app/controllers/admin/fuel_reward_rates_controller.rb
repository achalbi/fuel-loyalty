module Admin
  class FuelRewardRatesController < BaseController
    def show
      authorize FuelRewardRate
      authorize VehicleType, :index?
      @reward_setting = RewardSetting.current
      authorize @reward_setting
      load_settings
    end

    def update
      authorize FuelRewardRate
      authorize VehicleType, :update?
      @reward_setting = RewardSetting.current
      authorize @reward_setting

      if reward_setting_params.present?
        @reward_setting.update!(reward_setting_params)
        redirect_to admin_fuel_reward_rates_path, notice: "Reward settings updated successfully."
        return
      end

      if permitted_vehicle_type_rate_params.present?
        update_vehicle_type_reward_rates!
        redirect_to admin_fuel_reward_rates_path, notice: "Vehicle-type reward rates updated successfully."
        return
      end

      update_fuel_reward_rates!
      redirect_to admin_fuel_reward_rates_path, notice: "Fuel reward rates updated successfully."
    rescue ActiveRecord::RecordInvalid => e
      load_settings
      attach_record_errors(e.record)
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    private

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

    def attach_record_errors(record)
      if record.is_a?(VehicleType)
        target = @vehicle_types.find { |vehicle_type| vehicle_type.code == record.code }
      else
        target = @fuel_reward_rates.find { |rate| rate.fuel_type == record.fuel_type }
      end

      return if target.blank?

      record.errors.each do |error|
        target.errors.add(error.attribute, error.message)
      end
    end

    def permitted_vehicle_type_rate_params
      permitted_attributes = VehicleType.for_settings.map(&:code).index_with { [:reward_points_per_100] }

      params.fetch(:vehicle_type_reward_rates, ActionController::Parameters.new).permit(permitted_attributes).to_h.deep_symbolize_keys
    end

    def permitted_rate_params
      permitted_attributes = FuelRewardRate.setting_fuel_type_values.index_with { [:points_per_100] }

      params.fetch(:fuel_reward_rates, ActionController::Parameters.new).permit(permitted_attributes).to_h.deep_symbolize_keys
    end

    def reward_setting_params
      params.fetch(:reward_setting, ActionController::Parameters.new).permit(:rupees_per_reward_unit, :cash_value_per_point, :minimum_redeemable_points)
    end
  end
end
