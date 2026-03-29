module Admin
  class FuelRewardRatesController < BaseController
    def show
      authorize FuelRewardRate
      load_settings
    end

    def update
      authorize FuelRewardRate

      ActiveRecord::Base.transaction do
        permitted_rate_params.each do |fuel_type, attributes|
          rate = FuelRewardRate.find_or_initialize_by(fuel_type: fuel_type)
          rate.points_per_100 = attributes[:points_per_100]
          rate.save!
        end
      end

      redirect_to admin_fuel_reward_rates_path, notice: "Reward rates updated successfully."
    rescue ActiveRecord::RecordInvalid => e
      load_settings
      attach_record_errors(e.record)
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    private

    def load_settings
      @fuel_reward_rates = FuelRewardRate.for_settings
    end

    def attach_record_errors(record)
      target = @fuel_reward_rates.find { |rate| rate.fuel_type == record.fuel_type }
      return if target.blank?

      record.errors.each do |error|
        target.errors.add(error.attribute, error.message)
      end
    end

    def permitted_rate_params
      permitted_attributes = FuelRewardRate.setting_fuel_type_values.index_with { [:points_per_100] }

      params.fetch(:fuel_reward_rates, ActionController::Parameters.new).permit(permitted_attributes).to_h.deep_symbolize_keys
    end
  end
end
