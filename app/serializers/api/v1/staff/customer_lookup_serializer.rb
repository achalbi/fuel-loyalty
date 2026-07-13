module Api
  module V1
    module Staff
      # The staff customer-lookup payload (docs/native-handoff/11). Reused by
      # redeem, transactions, and points-adjustment flows.
      class CustomerLookupSerializer
        def self.call(customer, reward_setting)
          total = customer.total_points
          max_redeemable = customer.max_redeemable_points
          {
            id: customer.id,
            name: customer.display_name,
            phone_number: customer.phone_number,
            active: customer.active?,
            rewards_paused: customer.rewards_paused?,
            status_label: customer.status_label,
            rewards_status_label: customer.rewards_status_label,
            total_points: total,
            cash_value_per_point: reward_setting.cash_value_per_point&.to_f,
            total_points_cash_reward: reward_setting.cash_value_for_points(total)&.to_f,
            minimum_redeemable_points: customer.minimum_redeemable_points,
            redemption_increment: reward_setting.redemption_increment,
            max_redeemable_points: max_redeemable,
            max_redeemable_cash_reward: reward_setting.cash_value_for_points(max_redeemable)&.to_f,
            vehicles: customer.vehicles.map { |vehicle| vehicle_json(vehicle) },
          }
        end

        def self.vehicle_json(vehicle)
          {
            id: vehicle.id,
            vehicle_number: vehicle.vehicle_number,
            fuel_type_code: vehicle.fuel_type,
            fuel_type: vehicle.display_fuel_type,
            vehicle_kind: vehicle.display_vehicle_kind,
            display_name: vehicle.display_name,
          }
        end
      end
    end
  end
end
