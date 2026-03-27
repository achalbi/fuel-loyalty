module Admin
  class UsersController < BaseController
    def index
      authorize User
      load_index_state
    end

    def new
      @user = User.new(role: :staff)
      authorize @user
    end

    def show
      @user = User.kept.find(params[:id])
      authorize @user
    end

    def create
      @user = User.new
      authorize @user
      assign_user_attributes(@user, user_params)

      if @user.save
        redirect_to admin_users_path, notice: "User created successfully."
      else
        load_index_state(new_user: @user)
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      @user = User.kept.find(params[:id])
      authorize @user
    end

    def update
      @user = User.kept.find(params[:id])
      authorize @user

      assign_user_attributes(@user, filtered_update_params)

      if @user.save
        redirect_to admin_users_path, notice: "User updated successfully."
      else
        load_index_state(edit_user: @user)
        render :index, status: :unprocessable_entity
      end
    end

    private

    def load_index_state(new_user: User.new(role: :staff), edit_user: nil)
      @users = User.kept.order(:role, :name, :username, :phone_number)
      @user = new_user
      @edit_user = edit_user
    end

    def user_params
      params.require(:user).permit(:name, :username, :phone_number, :email, :active, :password, :password_confirmation)
    end

    def filtered_update_params
      user_params.tap do |attributes|
        if attributes[:password].blank? && attributes[:password_confirmation].blank?
          attributes.delete(:password)
          attributes.delete(:password_confirmation)
        end
      end
    end

    def assign_user_attributes(user, attributes)
      user.assign_attributes(attributes)

      return unless role_param.present?

      user.role = role_param
    end

    def role_param
      params.require(:user).permit(:role)[:role]
    end
  end
end
