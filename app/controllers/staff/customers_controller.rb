module Staff
  class CustomersController < BaseController
    def index
      authorize Customer, :lookup?
      load_index_state
    end

    def new
      @customer = Customer.new(new_customer_prefill_attributes)
      authorize @customer
    end

    def create
      normalized_phone = Customer.normalize_phone_number(customer_params[:phone_number])
      @customer = Customer.find_or_initialize_by(phone_number: normalized_phone)
      was_new_record = @customer.new_record?
      authorize @customer
      @customer.phone_number = normalized_phone
      @customer.name = customer_params[:name] if customer_params[:name].present?

      if @customer.save && save_vehicle
        notice = was_new_record ? "Customer created successfully." : "Customer updated successfully."
        redirect_to customer_path(@customer), notice: notice
      else
        load_index_state(form_customer: @customer)
        render :index, status: :unprocessable_entity
      end
    end

    def lookup
      authorize Customer, :lookup?

      normalized_phone = Customer.normalize_phone_number(params[:phone_number])

      unless Customer.valid_phone_number?(normalized_phone)
        return render json: { found: false, message: "Phone number must be a 10 digit number." }, status: :unprocessable_entity
      end

      customer = Customer.includes(:vehicles).find_by(phone_number: normalized_phone)

      if customer
        render json: {
          found: true,
          customer: {
            id: customer.id,
            name: customer.display_name,
            phone_number: customer.phone_number,
            active: customer.active?,
            status_label: customer.status_label,
            total_points: customer.total_points,
            max_redeemable_points: PointsRedeemer.max_redeemable_points(customer.total_points),
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
        }
      else
        render json: {
          found: false,
          message: "Customer not found for that phone number.",
          register_customer_path: register_customer_prefill_path(phone_number: normalized_phone)
        }, status: :not_found
      end
    end

    def activate
      update_status!(true, "Customer activated successfully.")
    end

    def deactivate
      update_status!(false, "Customer marked as inactive.")
    end

    private

    def load_index_state(form_customer: Customer.new)
      @query = params[:q].to_s.strip
      @customers = customer_scope
      @customer = form_customer
    end

    def new_customer_prefill_attributes
      {
        phone_number: Customer.normalize_phone_number(params[:phone_number]).presence,
        vehicle_number: Vehicle.normalize_vehicle_number(params[:vehicle_number]).presence
      }.compact_blank
    end

    def customer_scope
      return top_customers_scope if @query.blank?

      scope = Customer.includes(:vehicles).order(created_at: :desc)

      escaped_query = ActiveRecord::Base.sanitize_sql_like(@query)
      normalized_phone = Customer.normalize_phone_number(@query)
      conditions = ["customers.name ILIKE :name"]
      values = { name: "%#{escaped_query}%" }

      if normalized_phone.present?
        conditions << "customers.phone_number LIKE :phone"
        values[:phone] = "%#{normalized_phone}%"
      end

      scope.where(conditions.join(" OR "), values).limit(50)
    end

    def top_customers_scope
      Customer
        .left_joins(:points_ledgers)
        .includes(:vehicles)
        .select("customers.*, COALESCE(SUM(points_ledgers.points), 0) AS total_points_sum")
        .group("customers.id")
        .order(Arel.sql("COALESCE(SUM(points_ledgers.points), 0) DESC, customers.created_at DESC"))
        .limit(3)
    end

    def customer_params
      params.require(:customer).permit(:name, :phone_number, :vehicle_number, :fuel_type, :vehicle_kind)
    end

    def save_vehicle
      return true if customer_params[:vehicle_number].blank?

      vehicle = @customer.vehicles.find_or_initialize_by(vehicle_number: Vehicle.normalize_vehicle_number(customer_params[:vehicle_number]))
      return true if vehicle.persisted?

      vehicle.assign_attributes(
        fuel_type: customer_params[:fuel_type],
        vehicle_kind: customer_params[:vehicle_kind]
      )

      vehicle.save.tap do |saved|
        next if saved

        vehicle.errors.each do |error|
          @customer.errors.add(error.attribute, error.message)
        end
      end
    end

    def update_status!(active, notice_message)
      customer = Customer.find(params[:id])
      authorize customer, active ? :activate? : :deactivate?
      customer.update!(active: active)

      redirect_to customer_path(customer), notice: notice_message
    end
  end
end
