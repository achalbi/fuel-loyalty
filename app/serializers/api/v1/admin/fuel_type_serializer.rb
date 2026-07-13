module Api
  module V1
    module Admin
      # Admin fuel-type payload (mirrors the web Admin::FuelTypesController rows).
      # `code` is auto-generated from `name` on first save and immutable after.
      class FuelTypeSerializer
        def self.call(fuel_type)
          {
            id: fuel_type.id,
            code: fuel_type.code,
            name: fuel_type.name,
            active: fuel_type.active?,
            created_at: fuel_type.created_at&.iso8601,
            updated_at: fuel_type.updated_at&.iso8601,
          }
        end
      end
    end
  end
end
