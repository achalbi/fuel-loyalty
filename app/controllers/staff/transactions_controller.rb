module Staff
  class TransactionsController < BaseController
    def new
      authorize Transaction
      assign_prefill_values
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
        render json: { found: false, message: "No customer was found for that vehicle number." }, status: :not_found
      end
    end

    def create
      authorize Transaction
      result = TransactionCreator.call(user: current_user, **transaction_params.to_h.symbolize_keys)

      redirect_to customer_path(result.customer), notice: "Transaction recorded. #{result.points_earned} points earned."
    rescue ActiveRecord::RecordInvalid => e
      @errors = e.record.errors.full_messages
      assign_prefill_values
      render :new, status: :unprocessable_entity
    end

    private

    def transaction_params
      params.require(:transaction).permit(:lookup_mode, :phone_number, :vehicle_number, :vehicle_id, :fuel_amount)
    end

    def assign_prefill_values
      @active_lookup_mode = "phone"
      return unless params[:transaction].present?

      @active_lookup_mode = normalized_lookup_mode
      @prefill_phone_number = transaction_params[:phone_number]
      @prefill_vehicle_number = transaction_params[:vehicle_number]
      @prefill_vehicle_id = transaction_params[:vehicle_id]
      @prefill_fuel_amount = transaction_params[:fuel_amount]
    end

    def normalized_lookup_mode
      lookup_mode = transaction_params[:lookup_mode].to_s
      %w[phone vehicle].include?(lookup_mode) ? lookup_mode : "phone"
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
