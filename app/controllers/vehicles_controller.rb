class VehiclesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer
  before_action :set_vehicle, only: %i[edit update destroy]

  def create
    authorize @customer, :update?

    @vehicle = @customer.vehicles.new(vehicle_params)

    if @vehicle.save
      redirect_to customer_path(@customer), notice: "Vehicle added successfully."
    else
      render "customers/show", status: :unprocessable_entity
    end
  end

  def edit
    authorize @customer, :update?
  end

  def update
    authorize @customer, :update?

    if @vehicle.update(vehicle_params)
      redirect_to customer_path(@customer), notice: "Vehicle updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer, :update?
    @vehicle.destroy!

    redirect_to customer_path(@customer), notice: "Vehicle removed successfully."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to customer_path(@customer), alert: "Vehicle cannot be removed because transaction history exists."
  end

  private

  def set_customer
    @customer = Customer.includes(:vehicles, transactions: %i[user vehicle], points_ledgers: []).find(params[:customer_id])
  end

  def set_vehicle
    @vehicle = @customer.vehicles.find(params[:id])
  end

  def vehicle_params
    params.require(:vehicle).permit(:vehicle_number, :fuel_type, :vehicle_kind).to_h.merge(
      vehicle_number: Vehicle.normalize_vehicle_number(params.dig(:vehicle, :vehicle_number))
    )
  end
end
