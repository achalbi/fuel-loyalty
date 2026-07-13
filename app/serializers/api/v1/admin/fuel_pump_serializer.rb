module Api
  module V1
    module Admin
      # Admin fuel-pump payload: the pump plus its ordered nozzles and the
      # display names the web settings screen renders (docs/native-handoff
      # backend-map subsystem-controllers-admin-catalogs -> FuelPumps).
      class FuelPumpSerializer
        def self.call(fuel_pump)
          {
            id: fuel_pump.id,
            display_name: fuel_pump.display_name,
            sequence_number: fuel_pump.sequence_number,
            active: fuel_pump.active,
            active_nozzles_count: fuel_pump.active_nozzles_count,
            nozzles: fuel_pump.nozzles.map { |nozzle| nozzle_json(nozzle) },
            created_at: fuel_pump.created_at&.iso8601,
            updated_at: fuel_pump.updated_at&.iso8601,
          }
        end

        def self.nozzle_json(nozzle)
          {
            id: nozzle.id,
            display_name: nozzle.display_name,
            sequence_number: nozzle.sequence_number,
            fuel_type_code: nozzle.fuel_type_code,
            fuel_type_name: nozzle.fuel_type_name,
            active: nozzle.active,
          }
        end
      end
    end
  end
end
