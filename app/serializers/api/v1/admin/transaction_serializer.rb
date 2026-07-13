module Api
  module V1
    module Admin
      # Row payload for the admin transactions list. Field values mirror the web admin
      # transactions screen exactly (app/views/admin/transactions/index.html.erb), including
      # its pump/nozzle summary helpers (ApplicationHelper#transaction_pump_name /
      # #transaction_nozzle_name) and display fallbacks. Decimals -> .to_f, timestamps -> iso8601,
      # payment_mode enum -> its string value. phone_number is returned raw (no "+91" prefix),
      # matching Api::V1::Staff::CustomerLookupSerializer.
      class TransactionSerializer
        def self.call(txn)
          {
            id: txn.id,
            customer_name: txn.customer.display_name.to_s.titleize,
            vehicle_number: txn.vehicle&.vehicle_number || "Vehicle not linked",
            fuel_type: txn.vehicle&.display_fuel_type || "Fuel type unavailable",
            vehicle_kind: txn.vehicle&.display_vehicle_kind || "Vehicle type unavailable",
            pump: pump_name(txn),
            nozzle: nozzle_name(txn),
            fuel_amount: txn.fuel_amount.to_f,
            payment_mode: txn.payment_mode,
            handled_by: txn.user&.display_name,
            phone_number: txn.customer.phone_number,
            created_at: txn.created_at.iso8601,
          }
        end

        # Mirrors ApplicationHelper#transaction_pump_name.
        def self.pump_name(txn)
          txn.fuel_pump&.display_name.presence ||
            txn.fuel_pump_nozzle&.fuel_pump&.display_name.presence
        end

        # Mirrors ApplicationHelper#transaction_nozzle_name.
        def self.nozzle_name(txn)
          nozzle = txn.fuel_pump_nozzle
          return if nozzle.blank?

          [nozzle.display_name, nozzle.fuel_type_name].compact.join(" · ").presence
        end
      end
    end
  end
end
