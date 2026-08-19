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

    # A7 — reveal the full Aadhaar (admin-only, audited); rendered transiently on
    # the show page, never placed in flash/URL/logs.
    def reveal_aadhaar
      @user = User.kept.find(params[:id])
      authorize @user, :view_aadhaar?
      PiiAccessLog.record!(actor: current_user, target: @user, field: "aadhaar", ip: request.remote_ip)
      @revealed_aadhaar = @user.aadhaar_number
      render :show
    end

    # A7 — authenticated redirect to the ID-card image (admin-only). Never a
    # permanent public URL.
    def id_card_photo
      @user = User.kept.find(params[:id])
      authorize @user, :view_id_card?
      return redirect_to admin_user_path(@user), alert: "No ID card on file." unless @user.id_card_present?

      PiiAccessLog.record!(actor: current_user, target: @user, field: "id_card", ip: request.remote_ip)
      redirect_to rails_blob_path(@user.id_card_photo, disposition: "inline"), allow_other_host: false
    end

    def purge_kyc
      @user = User.kept.find(params[:id])
      authorize @user, :purge_kyc?
      @user.purge_kyc!
      redirect_to admin_user_path(@user), notice: "KYC data purged."
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

    # Active accounts sort to the top of the directory (admin feedback): an admin
    # scanning the list is almost always looking for someone who can still sign in.
    def load_index_state(new_user: User.new(role: :staff), edit_user: nil)
      @users = User.kept.order(active: :desc).order(:role, :name, :username, :phone_number)
      @user = new_user
      @edit_user = edit_user
    end

    def user_params
      sanitize_kyc(
        params.require(:user).permit(
          :name, :username, :phone_number, :email, :active, :password, :password_confirmation,
          :address, :aadhaar_number, :profile_photo, :id_card_photo
        )
      )
    end

    def filtered_update_params
      user_params.tap do |attributes|
        if attributes[:password].blank? && attributes[:password_confirmation].blank?
          attributes.delete(:password)
          attributes.delete(:password_confirmation)
        end
      end
    end

    # A7 — a blank Aadhaar / unselected file keeps the stored value; don't let an
    # empty form field clear an attachment or the encrypted number.
    def sanitize_kyc(attributes)
      attributes.delete(:aadhaar_number) if attributes[:aadhaar_number].blank?
      attributes.delete(:profile_photo) if attributes[:profile_photo].blank?
      attributes.delete(:id_card_photo) if attributes[:id_card_photo].blank?
      attributes
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
