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
      @customer = Customer.new(phone_number: normalized_phone)
      authorize @customer
      @customer.name = customer_params[:name] if customer_params[:name].present?

      if persist_customer_with_vehicle
        redirect_to customer_path(@customer), notice: "Customer created successfully."
      else
        load_index_state(form_customer: @customer)
        render :index, status: :unprocessable_entity
      end
    end

    def lookup
      authorize Customer, :lookup?
      reward_setting = RewardSetting.current

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
            rewards_paused: customer.rewards_paused?,
            rewards_status_label: customer.rewards_status_label,
            status_label: customer.status_label,
            total_points: customer.total_points,
            cash_value_per_point: reward_setting.cash_value_per_point&.to_f,
            total_points_cash_reward: reward_setting.cash_value_for_points(customer.total_points)&.to_f,
            minimum_redeemable_points: customer.minimum_redeemable_points,
            redemption_increment: reward_setting.redemption_increment,
            max_redeemable_points: customer.max_redeemable_points,
            max_redeemable_cash_reward: reward_setting.cash_value_for_points(customer.max_redeemable_points)&.to_f,
            vehicles: customer.vehicles.map do |vehicle|
              {
                id: vehicle.id,
                vehicle_number: vehicle.vehicle_number,
                fuel_type_code: vehicle.fuel_type,
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

    def pause_rewards
      update_rewards_paused!(true, "Rewards paused for this customer.")
    end

    def resume_rewards
      update_rewards_paused!(false, "Rewards resumed for this customer.")
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
      params.require(:customer).permit(
        :name,
        :phone_number,
        :vehicle_number,
        :fuel_type,
        :vehicle_kind,
        :commercial_company_name,
        :commercial_contact_name,
        :commercial_contact_phone_number,
        :commercial_address,
        :commercial_notes
      )
    end

    def save_vehicle
      vehicle = @customer.vehicles.find_or_initialize_by(vehicle_number: Vehicle.normalize_vehicle_number(customer_params[:vehicle_number]))
      return vehicle if vehicle.persisted?

      vehicle.assign_attributes(
        fuel_type: customer_params[:fuel_type],
        vehicle_kind: customer_params[:vehicle_kind],
        commercial_company_name: customer_params[:commercial_company_name],
        commercial_contact_name: customer_params[:commercial_contact_name],
        commercial_contact_phone_number: customer_params[:commercial_contact_phone_number],
        commercial_address: customer_params[:commercial_address],
        commercial_notes: customer_params[:commercial_notes]
      )

      vehicle.save.tap do |saved|
        next if saved

        vehicle.errors.each do |error|
          @customer.errors.add(error.attribute, error.message)
        end
      end
    end

    def persist_customer_with_vehicle
      return false unless initial_vehicle_fields_present?

      success = false

      Customer.transaction do
        unless @customer.save && save_vehicle
          raise ActiveRecord::Rollback
        end

        success = true
      end

      success
    end

    def initial_vehicle_fields_present?
      @customer.valid?

      required_fields = {
        vehicle_number: customer_params[:vehicle_number],
        fuel_type: customer_params[:fuel_type],
        vehicle_kind: customer_params[:vehicle_kind]
      }

      required_fields.each do |field, value|
        @customer.errors.add(field, "can't be blank") if value.blank?
      end

      @customer.errors.none?
    end

    def update_status!(active, notice_message)
      customer = Customer.find(params[:id])
      authorize customer, active ? :activate? : :deactivate?
      customer.update!(active: active)

      redirect_to customer_path(customer), notice: notice_message
    end

    def update_rewards_paused!(paused, notice_message)
      customer = Customer.find(params[:id])
      authorize customer, paused ? :pause_rewards? : :resume_rewards?
      customer.update!(rewards_paused: paused)

      redirect_back fallback_location: customer_path(customer), notice: notice_message
    end
  end
end
