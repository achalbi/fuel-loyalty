class DashboardController < ApplicationController
  def show
    if user_signed_in?
      redirect_to(current_user.admin? ? admin_dashboard_path : new_staff_transaction_path)
    else
      redirect_to new_loyalty_path
    end
  end
end
