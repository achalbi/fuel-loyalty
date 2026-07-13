module Api
  module V1
    module Auth
      # Token auth for the native app. Reuses Devise credential resolution
      # (username / email / phone, scoped to non-soft-deleted users) and the
      # same active/soft-delete gates as the web sign-in.
      class SessionsController < Api::V1::BaseController
        skip_before_action :authenticate_api_user!, only: %i[create refresh destroy]

        # POST /api/v1/auth/login  { login, password }
        def create
          login = params[:login].to_s
          password = params[:password].to_s

          user = User.find_for_database_authentication(login: login)
          if user.nil? || !user.valid_password?(password)
            return render_error(status: :unauthorized, code: "invalid_credentials",
                                message: I18n.t("devise.failure.invalid", authentication_keys: "Login"))
          end

          unless user.active_for_authentication?
            return render_error(status: :forbidden, code: "account_inactive",
                                message: I18n.t("devise.failure.inactive"))
          end

          render json: auth_payload(user), status: :created
        end

        # POST /api/v1/auth/refresh  { refresh_token }
        def refresh
          user = Api::TokenService.user_from_refresh(params[:refresh_token])
          if user.nil? || !user.active_for_authentication?
            raise Api::TokenService::InvalidToken, "refresh token no longer valid"
          end

          render json: auth_payload(user), status: :ok
        end

        # DELETE /api/v1/auth/logout — stateless; client discards its tokens.
        def destroy
          head :no_content
        end

        # GET /api/v1/auth/me — current authenticated user.
        def me
          render json: { user: Api::V1::UserSerializer.call(current_user) }, status: :ok
        end

        private

        def auth_payload(user)
          Api::TokenService.issue_for(user).merge(user: Api::V1::UserSerializer.call(user))
        end
      end
    end
  end
end
