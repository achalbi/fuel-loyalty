class CustomersController < ApplicationController
  include CustomerPointsLedgerRendering
  include CustomerTransactionHistoryRendering

  before_action :authenticate_user!
  before_action :set_customer, only: %i[show edit update points_ledger transaction_history]

  def show
    authorize @customer
    prepare_show_state
  end

  def points_ledger
    authorize @customer
    render_points_ledger_for(@customer)
  end

  def transaction_history
    authorize @customer
    render_transaction_history_for(@customer)
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
      prepare_show_state(open_edit_modal: true)
      render :show, status: :unprocessable_entity
    end
  end

  private

  def customer_params
    params.require(:customer).permit(:name, :phone_number)
  end

  def set_customer
    @customer = Customer.includes(:vehicles, transactions: %i[user vehicle]).find(params[:id])
  end

  def prepare_show_state(open_edit_modal: false)
    @vehicle = Vehicle.new
    @customer_update_path = customer_path(@customer)
    @customer_edit_modal_open = open_edit_modal
  end
end
