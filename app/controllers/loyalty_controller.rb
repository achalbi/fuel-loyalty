class LoyaltyController < ApplicationController
  def new; end

  def show
    @phone_number = Customer.normalize_phone_number(params[:phone_number])
    @customer = Customer.find_by(phone_number: @phone_number)

    if @customer
      @full_history = params[:full_history] == "1"
      @activities = @customer.loyalty_activities(limit: @full_history ? nil : 5)
      @show_full_history_button = !@full_history && @customer.loyalty_activities_count > 5
    else
      flash.now[:alert] = "No customer found for that phone number."
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @phone_number = Customer.normalize_phone_number(loyalty_params[:phone_number])
    redirect_to loyalty_result_path(phone_number: @phone_number)
  end

  private

  def loyalty_params
    params.require(:loyalty).permit(:phone_number)
  end
end
