module Api
  module V1
    # Current user's pump/nozzle assignment + the full pump catalog for the picker
    # (docs/native-handoff/06.5). Powers nozzle-mode transactions.
    class MyPumpSerializer
      def self.call(user)
        {
          fuel_pump_id: user.fuel_pump_id,
          assigned_fuel_pump_nozzle_ids: user.assigned_fuel_pump_nozzle_ids,
          ready: user.transaction_pump_ready?,
          pumps: FuelPump.includes(nozzles: :fuel_type_record).ordered.map { |pump| pump_json(pump) },
        }
      end

      def self.pump_json(pump)
        {
          id: pump.id,
          display_name: pump.display_name,
          active: pump.active,
          nozzles: pump.nozzles.ordered.map { |nozzle| nozzle_json(nozzle) },
        }
      end

      def self.nozzle_json(nozzle)
        {
          id: nozzle.id,
          display_name: nozzle.display_name,
          fuel_type_code: nozzle.fuel_type_code,
          fuel_type: nozzle.fuel_type_record&.name || nozzle.fuel_type_code.to_s.titleize,
          active: nozzle.active,
        }
      end
    end
  end
end
