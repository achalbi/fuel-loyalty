module Api
  module V1
    module Staff
      # Full customer profile (hero + vehicles + recent transactions), reusing the
      # lookup hero fields. Ledger is paginated via its own endpoint.
      class CustomerProfileSerializer
        def self.call(customer, reward_setting)
          hero = CustomerLookupSerializer.call(customer, reward_setting)
          hero.merge(
            points_until_redeemable: customer.points_until_redeemable,
            joined_at: customer.created_at.iso8601,
            visits_count: customer.transactions.size,
            # B1/E4 — account taxonomy + the fleet/transport master fields.
            customer_type: customer.customer_type,
            customer_type_label: customer_type_label(customer.customer_type),
            transport_name: customer.transport_name,
            approx_vehicle_count: customer.approx_vehicle_count,
            info_note: customer.info_note,
            contacts: customer.customer_contacts.active.map { |contact| contact_json(contact) },
            vehicles: customer.vehicles.map { |vehicle| vehicle_json(vehicle) },
            recent_transactions: customer.recent_transactions(3).map { |txn| transaction_json(txn) },
            transactions_count: customer.transactions.size,
          )
        end

        def self.customer_type_label(customer_type)
          { "otp" => "OTP / Fleet", "credit" => "Credit", "drive_in" => "Drive-in" }[customer_type.to_s]
        end

        def self.contact_json(contact)
          {
            id: contact.id,
            role: contact.role,
            role_label: contact.display_role,
            name: contact.name,
            phone_number: contact.phone_number,
            contacted: contact.contacted?,
            contacted_at: contact.contacted_at&.iso8601,
            notes: contact.notes,
          }
        end

        def self.vehicle_json(vehicle)
          json = {
            id: vehicle.id,
            vehicle_number: vehicle.vehicle_number,
            fuel_type_code: vehicle.fuel_type,
            fuel_type: vehicle.display_fuel_type,
            vehicle_kind_code: vehicle.vehicle_kind,
            vehicle_kind: vehicle.display_vehicle_kind,
            display_name: vehicle.display_name,
            commercial: Vehicle::COMMERCIAL_VEHICLE_KINDS.include?(vehicle.vehicle_kind),
          }
          if json[:commercial]
            json[:commercial_company_name] = vehicle.commercial_company_name
            json[:commercial_contact_name] = vehicle.commercial_contact_name
            json[:commercial_contact_phone_number] = vehicle.commercial_contact_phone_number
            json[:commercial_address] = vehicle.commercial_address
            json[:commercial_notes] = vehicle.commercial_notes
          end
          json
        end

        def self.transaction_json(txn)
          ledger = txn.points_ledger
          {
            id: txn.id,
            vehicle_number: txn.vehicle&.vehicle_number,
            handled_by: txn.user&.display_name,
            pump: txn.fuel_pump&.display_name,
            nozzle: txn.fuel_pump_nozzle&.display_name,
            points_earned: ledger&.points,
            cash_reward: ledger&.recorded_cash_reward_amount&.to_f,
            fuel_amount: txn.fuel_amount.to_f,
            payment_mode: txn.payment_mode,
            created_at: txn.created_at.iso8601,
          }
        end
      end
    end
  end
end
