module Admin
  class FuelRewardRatesController < BaseController
    def show
      authorize FuelRewardRate
      @fuel_reward_rates = FuelRewardRate.for_settings
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
      @fuel_reward_rates = FuelRewardRate.for_settings
      @fuel_reward_rates.each do |rate|
        next unless rate.fuel_type == e.record.fuel_type

        e.record.errors.each do |error|
          rate.errors.add(error.attribute, error.message)
        end
      end
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    private

    def permitted_rate_params
      params.require(:fuel_reward_rates).permit(
        petrol: [:points_per_100],
        diesel: [:points_per_100],
        cng_lpg: [:points_per_100]
      ).to_h.deep_symbolize_keys
    end
  end
end
