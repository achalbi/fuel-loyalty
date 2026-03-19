module Staff
  class TransactionsController < BaseController
    def new
      authorize Transaction
      assign_prefill_values
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
      params.require(:transaction).permit(:phone_number, :vehicle_id, :fuel_amount)
    end

    def assign_prefill_values
      return unless params[:transaction].present?

      @prefill_phone_number = transaction_params[:phone_number]
      @prefill_vehicle_id = transaction_params[:vehicle_id]
      @prefill_fuel_amount = transaction_params[:fuel_amount]
    end
  end
end
