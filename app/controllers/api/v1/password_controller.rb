module Api
  module V1
    # PATCH /api/v1/password  { current_password, password, password_confirmation }
    # Self-service change via Devise's update_with_password. JWTs are stateless,
    # so existing tokens remain valid until they expire.
    class PasswordController < Api::V1::BaseController
      def update
        attrs = resource_params(:user)
        updated = current_user.update_with_password(
          current_password: attrs[:current_password],
          password: attrs[:password],
          password_confirmation: attrs[:password_confirmation],
        )

        if updated
          render json: { message: "Password updated successfully." }, status: :ok
        else
          render_error(status: 422, code: "validation_failed",
                       message: current_user.errors.full_messages.to_sentence.presence || "Could not update password.",
                       details: current_user.errors.messages)
        end
      end
    end
  end
end
