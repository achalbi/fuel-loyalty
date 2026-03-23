class PasswordsController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update_with_password(password_params)
      bypass_sign_in(@user)
      redirect_to after_password_update_path, notice: "Password updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def after_password_update_path
    current_user.admin? ? admin_dashboard_path : new_staff_transaction_path
  end
end
