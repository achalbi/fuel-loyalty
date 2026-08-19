module Api
  module V1
    module Staff
      class TransactionsController < Api::V1::Staff::BaseController
        # GET /api/v1/staff/transactions/lookup?vehicle_number=
        # Returns ALL vehicles matching the plate (a plate may exist under several
        # customers), each with its owning customer.
        def lookup
          authorize Transaction, :new?
          normalized = Vehicle.normalize_vehicle_number(params[:vehicle_number])

          unless Vehicle.valid_vehicle_number?(normalized)
            return render_error(status: 422, code: "invalid_vehicle", message: "Vehicle number is invalid.")
          end

          vehicles = Vehicle.includes(customer: :vehicles)
                            .where(vehicle_number: normalized)
                            .sort_by { |v| [v.customer.display_name.to_s.downcase, v.customer.phone_number.to_s] }

          if vehicles.empty?
            return render_error(status: :not_found, code: "vehicle_not_found",
                                message: "No customer was found for that vehicle number.")
          end

          reward_setting = RewardSetting.current
          render json: {
            matches: vehicles.map { |vehicle| match_json(vehicle, reward_setting) },
          }, status: :ok
        end

        # POST /api/v1/staff/transactions
        # Item 2 — the single counter capture: one post records the loyalty
        # transaction and the visit entry together. CounterEntry runs the whole
        # flow atomically and raises ActiveRecord::RecordInvalid on any rule
        # failure -> 422 via BaseController.
        def create
          authorize Transaction, :new?

          result = CounterEntry.record(user: current_user, params: transaction_params)
          new_total = result.customer&.total_points

          render json: {
            points_earned: result.points_earned,
            rewards_paused: result.rewards_paused,
            new_total: new_total,
            message: create_message(result, new_total),
            visit_skipped_reason: result.visit_skipped_reason,
            customer: result.customer && CustomerLookupSerializer.call(result.customer, RewardSetting.current),
            transaction: result.transaction && {
              id: result.transaction.id,
              fuel_amount: result.transaction.fuel_amount.to_f,
              payment_mode: result.transaction.payment_mode,
              pump: result.transaction.fuel_pump&.display_name,
              nozzle: result.transaction.fuel_pump_nozzle&.display_name,
              created_at: result.transaction.created_at.iso8601,
            },
            visit_entry: result.visit_entry && VisitEntrySerializer.call(result.visit_entry),
          }, status: :created
        end

        # An unregistered plate has no customer to award points to; a fuel with
        # no catalog price records the sale alone (see CounterEntry).
        def create_message(result, new_total)
          return "Visit captured for #{result.visit_entry.vehicle_number}." if result.transaction.nil?
          return "Transaction recorded. Rewards are paused for this customer, so no points were added." if result.rewards_paused

          "+#{result.points_earned} reward points added. Balance updated to #{new_total}."
        end

        # POST /api/v1/staff/transactions/recognize_plate  { image_data: "data:image/jpeg;base64,..." }
        # Proxies to the Plate Recognizer service. The client (CameraX) captures
        # the frame; on-device OCR fallback is the native ML Kit layer (doc 09).
        def recognize_plate
          authorize Transaction, :new?
          image_data = params.dig(:plate_scan, :image_data).presence ||
                       resource_params(:plate_scan)[:image_data].presence ||
                       params[:image_data]
          result = VehiclePlateRecognizer.call(image_data: image_data)

          if result.found
            render json: result.as_json, status: :ok
          else
            render_error(status: 422, code: "no_plate_detected",
                         message: "No clear vehicle number could be recognized. Please retake the photo.")
          end
        rescue VehiclePlateRecognizer::ConfigurationError => e
          render_error(status: :service_unavailable, code: "recognizer_unconfigured", message: e.message)
        rescue VehiclePlateRecognizer::RecognitionError => e
          render_error(status: :bad_gateway, code: "recognizer_error", message: e.message)
        end

        # POST /api/v1/staff/transactions/register_customer
        # { name, phone_number, vehicle_number, fuel_type, vehicle_kind, commercial_* }
        # Find-or-build a customer by phone, then attach the vehicle, persisting
        # customer + vehicle atomically (mirrors the web Staff registration modal).
        # Returns the customer (CustomerLookupSerializer) plus a `registration` note
        # describing whether the customer was created, the vehicle added, or an
        # existing customer loaded.
        def register_customer
          customer = build_registration_customer
          existing_customer = customer.persisted?
          authorize customer, existing_customer ? :update? : :create?

          registration_saved, saved_vehicle = persist_registration_customer_with_vehicle(customer, existing_customer:)

          if registration_saved
            render json: {
              registration: registration_note(existing_customer:, vehicle: saved_vehicle),
              customer: CustomerLookupSerializer.call(customer.reload, RewardSetting.current),
            }, status: :created
          else
            render_error(status: 422, code: "validation_failed",
                         message: customer.errors.full_messages.to_sentence.presence || "Validation failed.",
                         details: customer.errors.messages)
          end
        end

        private

        def match_json(vehicle, reward_setting)
          {
            vehicle_id: vehicle.id,
            vehicle_number: vehicle.vehicle_number,
            fuel_type_code: vehicle.fuel_type,
            fuel_type: vehicle.display_fuel_type,
            vehicle_kind_code: vehicle.vehicle_kind,
            vehicle_kind: vehicle.display_vehicle_kind,
            customer: CustomerLookupSerializer.call(vehicle.customer, reward_setting),
          }
        end

        def transaction_params
          resource_params(:transaction).permit(*CounterEntry::PERMITTED_FIELDS)
        end

        # --- register_customer helpers ---------------------------------------

        def build_registration_customer
          attrs = resource_params(:customer)
          normalized_phone = Customer.normalize_phone_number(attrs[:phone_number])
          existing_customer = Customer.find_by(phone_number: normalized_phone)
          return existing_customer if existing_customer.present?

          customer = Customer.new(phone_number: normalized_phone)
          customer.name = attrs[:name] if attrs[:name].present?
          customer.vehicle_number = Vehicle.normalize_vehicle_number(attrs[:vehicle_number]) if customer.respond_to?(:vehicle_number=)
          customer
        end

        def persist_registration_customer_with_vehicle(customer, existing_customer:)
          return [false, nil] unless registration_fields_present?(customer, existing_customer:)

          saved_vehicle = nil
          success = false

          Customer.transaction do
            raise ActiveRecord::Rollback unless existing_customer || customer.save

            saved_vehicle = save_registration_vehicle(customer)
            raise ActiveRecord::Rollback if saved_vehicle == false

            success = true
          end

          [success, saved_vehicle]
        end

        # Requires name/phone_number/vehicle_number/fuel_type/vehicle_kind; runs the
        # customer's own validations too (unless it already exists).
        def registration_fields_present?(customer, existing_customer:)
          customer.valid? unless existing_customer

          attrs = resource_params(:customer)
          {
            name: attrs[:name],
            phone_number: attrs[:phone_number],
            vehicle_number: attrs[:vehicle_number],
            fuel_type: attrs[:fuel_type],
            vehicle_kind: attrs[:vehicle_kind],
          }.each do |field, value|
            customer.errors.add(field, "can't be blank") if value.blank?
          end

          customer.errors.none?
        end

        def save_registration_vehicle(customer)
          attrs = resource_params(:customer)
          normalized = Vehicle.normalize_vehicle_number(attrs[:vehicle_number])
          vehicle = customer.vehicles.find_or_initialize_by(vehicle_number: normalized)
          return vehicle if vehicle.persisted?

          vehicle.assign_attributes(
            fuel_type: attrs[:fuel_type],
            vehicle_kind: attrs[:vehicle_kind],
            commercial_company_name: attrs[:commercial_company_name],
            commercial_contact_name: attrs[:commercial_contact_name],
            commercial_contact_phone_number: attrs[:commercial_contact_phone_number],
            commercial_address: attrs[:commercial_address],
            commercial_notes: attrs[:commercial_notes],
          )
          return vehicle if vehicle.save

          vehicle.errors.each { |error| customer.errors.add(error.attribute, error.message) }
          false
        end

        def registration_note(existing_customer:, vehicle:)
          return "Customer created successfully. Continue recording the transaction." unless existing_customer
          return "Vehicle added to the existing customer. Continue recording the transaction." if vehicle&.previously_new_record?

          "Existing customer details loaded. Continue recording the transaction."
        end
      end
    end
  end
end
