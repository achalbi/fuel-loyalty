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
            customer_type_label: customer.customer_type_label,
            whatsapp_opt_in: customer.whatsapp_opt_in,
            sms_opt_in: customer.sms_opt_in,
            transport_name: customer.transport_name,
            approx_vehicle_count: customer.approx_vehicle_count,
            # `info_note` stays as the most recent entry for older app builds;
            # `notes` is the full dated log (item 13).
            info_note: customer.info_note,
            notes: customer.customer_notes.map { |note| note_json(note) },
            contacts: customer.customer_contacts.active.map { |contact| contact_json(contact) },
            vehicles: customer.vehicles.map { |vehicle| vehicle_json(vehicle) },
            recent_transactions: customer.recent_transactions(3).map { |txn| transaction_json(txn) },
            transactions_count: customer.transactions.size,
          )
        end

        def self.note_json(note)
          {
            id: note.id,
            body: note.body,
            author: note.author_label,
            created_at: note.created_at.iso8601,
          }
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
            # Item 5 — the ₹ knocked off this fuelling, so the app can show a
            # single transaction's discount and not just the customer rollup.
            discount_amount: txn.discount_amount.to_f,
            payment_mode: txn.payment_mode,
            created_at: txn.created_at.iso8601,
          }
        end
      end
    end
  end
end
