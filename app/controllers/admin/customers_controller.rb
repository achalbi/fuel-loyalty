module Admin
  class CustomersController < BaseController
    include CustomerPointsLedgerRendering
    include CustomerTransactionHistoryRendering

    def index
      authorize Customer
      load_index_state
    end

    def new
      @customer = Customer.new
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
        redirect_to admin_customer_path(@customer), notice: notice
      else
        load_index_state(form_customer: @customer)
        render :index, status: :unprocessable_entity
      end
    end

    def show
      @customer = Customer.includes(:vehicles, transactions: %i[user vehicle]).find(params[:id])
      authorize @customer
      prepare_show_state
      render "customers/show"
    end

    def edit
      @customer = Customer.find(params[:id])
      authorize @customer
    end

    def update
      @customer = Customer.includes(:vehicles, transactions: %i[user vehicle]).find(params[:id])
      authorize @customer
      @customer.assign_attributes(customer_params.slice(:name, :phone_number))
      @customer.phone_number = Customer.normalize_phone_number(customer_params[:phone_number])

      if @customer.save
        redirect_to admin_customer_path(@customer), notice: "Customer updated successfully."
      else
        prepare_show_state(open_edit_modal: true)
        render "customers/show", status: :unprocessable_entity
      end
    end

    def points_ledger
      @customer = Customer.find(params[:id])
      authorize @customer
      render_points_ledger_for(@customer)
    end

    def transaction_history
      @customer = Customer.find(params[:id])
      authorize @customer
      render_transaction_history_for(@customer)
    end

    def destroy
      @customer = Customer.find(params[:id])
      authorize @customer
      @customer.destroy!

      redirect_to admin_customers_path, notice: "Customer removed successfully."
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to admin_customer_path(@customer), alert: "Customer cannot be removed because transaction history exists."
    end

    private

    def load_index_state(form_customer: Customer.new)
      @query = params[:q].to_s.strip
      @current_status = normalized_status_filter
      @customers = filtered_customers
      @customer = form_customer
    end

    def filtered_customers
      scope = Customer
        .left_joins(:vehicles)
        .select(<<~SQL.squish)
          customers.*,
          COALESCE(
            (
              SELECT SUM(points_ledgers.points)
              FROM points_ledgers
              WHERE points_ledgers.customer_id = customers.id
            ),
            0
          ) AS total_points_sum
        SQL
        .distinct

      if @query.present?
        name_query = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
        phone_query = Customer.normalize_phone_number(@query)
        vehicle_query = Vehicle.normalize_vehicle_number(@query)
        conditions = ["LOWER(customers.name) LIKE :name"]
        values = { name: name_query }

        if phone_query.present?
          values[:phone] = "%#{ActiveRecord::Base.sanitize_sql_like(phone_query)}%"
          conditions << "customers.phone_number LIKE :phone"
        end

        if vehicle_query.present?
          vehicle_like = "%#{ActiveRecord::Base.sanitize_sql_like(vehicle_query)}%"
          values[:legacy_vehicle] = vehicle_like
          values[:vehicle] = vehicle_like
          conditions << "customers.vehicle_number LIKE :legacy_vehicle"
          conditions << "vehicles.vehicle_number LIKE :vehicle"
        end

        scope = scope.where(conditions.join(" OR "), values)
      end

      scope = case @current_status
      when "active"
        scope.where(active: true)
      when "inactive"
        scope.where(active: false)
      else
        scope
      end

      scope.preload(:vehicles).order(created_at: :desc)
    end

    def normalized_status_filter
      status = params[:status].to_s
      %w[all active inactive].include?(status) ? status : "all"
    end

    def prepare_show_state(open_edit_modal: false)
      @vehicle = Vehicle.new
      @customer_update_path = admin_customer_path(@customer)
      @customer_edit_modal_open = open_edit_modal
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
  end
end
