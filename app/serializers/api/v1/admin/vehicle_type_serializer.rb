module Api
  module V1
    module Admin
      # Admin vehicle-type payload (mirrors the web Admin::VehicleTypesController rows).
      # `code` is set on create only and immutable after. `reward_points_per_100`
      # is read-only here (managed by the fuel-reward-rates endpoint).
      class VehicleTypeSerializer
        def self.call(vehicle_type)
          {
            id: vehicle_type.id,
            code: vehicle_type.code,
            name: vehicle_type.name,
            short_name: vehicle_type.short_name,
            app_label: vehicle_type.app_label,
            app_label_source: vehicle_type.app_label_source,
            icon_name: vehicle_type.icon_name,
            minimum_redeemable_points: vehicle_type.minimum_redeemable_points,
            reward_points_per_100: vehicle_type.reward_points_per_100,
            active: vehicle_type.active?,
            created_at: vehicle_type.created_at&.iso8601,
            updated_at: vehicle_type.updated_at&.iso8601,
          }
        end
      end
    end
  end
end
