module Api
  module V1
    module Staff
      # B2 — a per-visit capture for the FSM review list and the settlement pull.
      class VisitEntrySerializer
        def self.call(visit)
          {
            id: visit.id,
            entry_date: visit.entry_date.iso8601,
            vehicle_number: visit.vehicle_number,
            customer_id: visit.customer_id,
            customer_name: visit.customer&.display_name,
            vehicle_id: visit.vehicle_id,
            fuel_pump_id: visit.fuel_pump_id,
            fuel_pump: visit.fuel_pump&.display_name,
            driver_name: visit.driver_name,
            driver_phone_number: visit.driver_phone_number,
            litres: visit.litres.to_f,
            fuel_type_code: visit.fuel_type_code,
            discount_amount: visit.discount_amount.to_f,
            fleet_otp: visit.fleet_otp,
            transport_name: visit.transport_name,
            manager_name: visit.manager_name,
            manager_phone_number: visit.manager_phone_number,
            owner_name: visit.owner_name,
            owner_phone_number: visit.owner_phone_number,
            approx_vehicle_count: visit.approx_vehicle_count,
            transaction_id: visit.transaction_id,
            created_at: visit.created_at.iso8601,
          }
        end
      end
    end
  end
end
