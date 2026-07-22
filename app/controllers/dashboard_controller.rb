class DashboardController < ApplicationController
  def show
    return redirect_to new_loyalty_path unless user_signed_in?

    @phone_number = nil
  end
end
