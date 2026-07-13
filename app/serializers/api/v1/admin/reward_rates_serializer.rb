module Api
  module V1
    module Admin
      # Payload for GET/PATCH /api/v1/admin/reward_rates: the global reward
      # settings, per-vehicle-type reward-point overrides, and per-fuel-type
      # fallback rates. Decimals -> float, enums/codes -> string.
      class RewardRatesSerializer
        def self.call(reward_setting, vehicle_types, fuel_reward_rates)
          {
            reward_setting: reward_setting_json(reward_setting),
            vehicle_type_reward_rates: vehicle_types.map { |vehicle_type| vehicle_type_json(vehicle_type) },
            fuel_reward_rates: fuel_reward_rates.map { |rate| fuel_reward_rate_json(rate) },
          }
        end

        def self.reward_setting_json(reward_setting)
          {
            rupees_per_reward_unit: reward_setting.rupees_per_reward_unit,
            cash_value_per_point: reward_setting.cash_value_per_point&.to_f,
            minimum_redeemable_points: reward_setting.minimum_redeemable_points,
            cash_reward_configured: reward_setting.cash_reward_configured?,
            redemption_increment: reward_setting.redemption_increment,
          }
        end

        # Per-vehicle-type override: reward_points_per_100 may be nil (no override).
        def self.vehicle_type_json(vehicle_type)
          {
            id: vehicle_type.id,
            code: vehicle_type.code,
            name: vehicle_type.name,
            label: vehicle_type.app_label,
            reward_points_per_100: vehicle_type.reward_points_per_100,
          }
        end

        # Per-fuel-type fallback rate. id is nil for records not yet persisted
        # (FuelRewardRate.for_settings uses find_or_initialize_by).
        def self.fuel_reward_rate_json(rate)
          {
            id: rate.id,
            fuel_type: rate.fuel_type,
            label: rate.display_name,
            points_per_100: rate.points_per_100,
          }
        end
      end
    end
  end
end
