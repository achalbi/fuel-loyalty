module Admin
  class CustomersController < BaseController
    def index
      authorize Customer
      @customers = Customer.includes(:vehicles).order(created_at: :desc)
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
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @customer = Customer.includes(:vehicles, transactions: %i[user vehicle], points_ledgers: []).find(params[:id])
      @vehicle = Vehicle.new
      authorize @customer
      render "customers/show"
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
