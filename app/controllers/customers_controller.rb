class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_customer, only: %i[show edit update]

  def show
    authorize @customer
    @vehicle = Vehicle.new
  end

  def edit
    authorize @customer
  end

  def update
    authorize @customer
    @customer.assign_attributes(customer_params)
    @customer.phone_number = Customer.normalize_phone_number(customer_params[:phone_number])

    if @customer.save
      redirect_to customer_path(@customer), notice: "Customer updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def customer_params
    params.require(:customer).permit(:name, :phone_number)
  end

  def set_customer
    @customer = Customer.includes(:vehicles, transactions: %i[user vehicle], points_ledgers: []).find(params[:id])
  end
end
