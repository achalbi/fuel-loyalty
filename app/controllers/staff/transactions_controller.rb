module Staff
  class TransactionsController < BaseController
    def new
      authorize Transaction
      assign_prefill_values
      prepare_registration_modal
    end

    def lookup
      authorize Transaction, :new?

      normalized_vehicle_number = Vehicle.normalize_vehicle_number(params[:vehicle_number])

      unless Vehicle.valid_vehicle_number?(normalized_vehicle_number)
        return render json: { found: false, message: "Vehicle number is invalid." }, status: :unprocessable_entity
      end

      matches = Vehicle
        .includes(customer: :vehicles)
        .where(vehicle_number: normalized_vehicle_number)
        .sort_by { |vehicle| [vehicle.customer.display_name.to_s.downcase, vehicle.customer.phone_number.to_s] }

      if matches.any?
        render json: {
          found: true,
          matches: matches.map do |vehicle|
            {
              vehicle_id: vehicle.id,
              vehicle_number: vehicle.vehicle_number,
              fuel_type: vehicle.display_fuel_type,
              vehicle_kind: vehicle.display_vehicle_kind,
              customer: customer_payload(vehicle.customer)
            }
          end
        }
      else
        render json: {
          found: false,
          message: "No customer was found for that vehicle number.",
          register_customer_path: register_customer_prefill_path(vehicle_number: normalized_vehicle_number)
        }, status: :not_found
      end
    end

    def create
      authorize Transaction
      result = TransactionCreator.call(user: current_user, **transaction_params.to_h.symbolize_keys)

      redirect_to customer_path(result.customer), flash: {
        transaction_summary: {
          points_earned: result.points_earned,
          current_points: result.customer.total_points
        }
      }
    rescue ActiveRecord::RecordInvalid => e
      @errors = e.record.errors.full_messages
      assign_prefill_values
      prepare_registration_modal
      render :new, status: :unprocessable_entity
    end

    def register_customer
      customer = build_registration_customer
      was_new_record = customer.new_record?
      authorize customer, :create?

      saved_vehicle = save_registration_vehicle(customer) if customer.save

      if customer.persisted? && saved_vehicle != false
        notice = was_new_record ? "Customer created successfully. Continue recording the transaction." : "Customer updated successfully. Continue recording the transaction."
        redirect_to new_staff_transaction_path(transaction: transaction_prefill_for_registered_customer(customer, saved_vehicle)), notice:
      else
        assign_prefill_values
        prepare_registration_modal(customer:, open: true)
        render :new, status: :unprocessable_entity
      end
    end

    private

    def transaction_params
      params.require(:transaction).permit(:lookup_mode, :phone_number, :vehicle_number, :vehicle_id, :fuel_amount)
    end

    def assign_prefill_values
      prefill_source = transaction_prefill_source
      @active_lookup_mode = "vehicle"
      return if prefill_source.blank?

      @active_lookup_mode = normalized_lookup_mode(prefill_source[:lookup_mode])
      @prefill_phone_number = prefill_source[:phone_number]
      @prefill_vehicle_number = prefill_source[:vehicle_number]
      @prefill_vehicle_id = prefill_source[:vehicle_id]
      @prefill_fuel_amount = prefill_source[:fuel_amount]
    end

    def transaction_prefill_source
      if params[:transaction].present?
        transaction_params
      elsif params[:transaction_lookup].present?
        transaction_lookup_params
      else
        {}
      end
    end

    def normalized_lookup_mode(lookup_mode_value = nil)
      lookup_mode = lookup_mode_value.to_s
      %w[phone vehicle].include?(lookup_mode) ? lookup_mode : "vehicle"
    end

    def prepare_registration_modal(customer: Customer.new, open: false)
      @registration_customer = customer
      @transaction_registration_modal_open = open
    end

    def registration_customer_params
      params.require(:customer).permit(:name, :phone_number, :vehicle_number, :fuel_type, :vehicle_kind)
    end

    def transaction_lookup_params
      params.require(:transaction_lookup).permit(:lookup_mode, :phone_number, :vehicle_number, :fuel_amount)
    end

    def build_registration_customer
      normalized_phone = Customer.normalize_phone_number(registration_customer_params[:phone_number])
      Customer.find_or_initialize_by(phone_number: normalized_phone).tap do |customer|
        customer.phone_number = normalized_phone
        customer.name = registration_customer_params[:name] if registration_customer_params[:name].present?
        customer.vehicle_number = Vehicle.normalize_vehicle_number(registration_customer_params[:vehicle_number]) if customer.respond_to?(:vehicle_number=)
      end
    end

    def save_registration_vehicle(customer)
      normalized_vehicle_number = Vehicle.normalize_vehicle_number(registration_customer_params[:vehicle_number])
      return nil if normalized_vehicle_number.blank?

      vehicle = customer.vehicles.find_or_initialize_by(vehicle_number: normalized_vehicle_number)
      return vehicle if vehicle.persisted?

      vehicle.assign_attributes(
        fuel_type: registration_customer_params[:fuel_type],
        vehicle_kind: registration_customer_params[:vehicle_kind]
      )

      return vehicle if vehicle.save

      vehicle.errors.each do |error|
        customer.errors.add(error.attribute, error.message)
      end

      false
    end

    def transaction_prefill_for_registered_customer(customer, vehicle)
      fuel_amount = transaction_lookup_params[:fuel_amount]
      lookup_mode = normalized_lookup_mode(transaction_lookup_params[:lookup_mode])

      if lookup_mode == "vehicle" && vehicle.present?
        {
          lookup_mode: "vehicle",
          vehicle_number: vehicle.vehicle_number,
          vehicle_id: vehicle.id,
          fuel_amount:
        }.compact_blank
      else
        {
          lookup_mode: "phone",
          phone_number: customer.phone_number,
          vehicle_id: vehicle&.id,
          fuel_amount:
        }.compact_blank
      end
    end

    def customer_payload(customer)
      {
        id: customer.id,
        name: customer.display_name,
        phone_number: customer.phone_number,
        active: customer.active?,
        status_label: customer.status_label,
        total_points: customer.total_points,
        vehicles: customer.vehicles.map do |vehicle|
          {
            id: vehicle.id,
            vehicle_number: vehicle.vehicle_number,
            fuel_type: vehicle.display_fuel_type,
            vehicle_kind: vehicle.display_vehicle_kind,
            display_name: vehicle.display_name
          }
        end
      }
    end
  end
end
