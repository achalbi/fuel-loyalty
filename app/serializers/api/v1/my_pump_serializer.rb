module Api
  module V1
    # Current user's pump/nozzle assignment + the full pump catalog for the picker
    # (docs/native-handoff/06.5). Powers nozzle-mode transactions.
    class MyPumpSerializer
      def self.call(user, on: Date.current, assignment_mode: "override")
        default_mode = assignment_mode == "default"
        assignment = default_mode ? nil : user.pump_assignment_for(on:)
        pump = default_mode ? user.assigned_fuel_pump : user.transaction_fuel_pump(on:)
        nozzles = default_mode ? default_nozzles_for(user, pump) : user.transaction_fuel_pump_nozzles(on:)
        {
          assignment_mode: assignment_mode,
          assignment_date: default_mode ? nil : on.iso8601,
          fuel_pump_id: assignment&.fuel_pump_id || (default_mode || on == Date.current ? user.fuel_pump_id : nil),
          assigned_fuel_pump_nozzle_ids: assignment&.assigned_fuel_pump_nozzle_ids || (default_mode || on == Date.current ? user.assigned_fuel_pump_nozzle_ids : []),
          ready: pump.present? && nozzles.exists?,
          pumps: FuelPump.includes(nozzles: :fuel_type_record).ordered.map { |pump| pump_json(pump) },
        }
      end

      def self.default_nozzles_for(user, pump)
        return FuelPumpNozzle.none unless pump

        FuelPumpNozzle
          .includes(:fuel_type_record)
          .where(id: user.assigned_fuel_pump_nozzle_ids, fuel_pump_id: pump.id, active: true)
          .ordered
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
