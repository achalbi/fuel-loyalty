module Api
  module V1
    # Base for all /api/v1 controllers: token authentication, Pundit
    # authorization, and a uniform JSON error envelope:
    #   { "error": { "code": "...", "message": "...", "details": {...} } }
    class BaseController < ActionController::API
      include Pundit::Authorization

      # Request bodies are read via #resource_params; disable Rails' implicit
      # params wrapping so nested vs top-level is explicit and predictable.
      wrap_parameters false

      before_action :authenticate_api_user!

      rescue_from Api::TokenService::InvalidToken, with: :render_unauthorized
      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::RecordNotUnique, with: :render_record_not_unique
      rescue_from ActiveRecord::RecordNotDestroyed, with: :render_record_not_destroyed
      rescue_from ActiveRecord::DeleteRestrictionError, with: :render_delete_restricted
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

      private

      attr_reader :current_user

      def pundit_user
        current_user
      end

      # Canonical request-body shape is nested under the resource key (doc-11:
      # `model[...]`). Returns the first nested key present; falls back to the
      # top-level params (compat with the initial flat client). Combine with
      # `.permit(...)`. GET/query filters should keep reading top-level params.
      def resource_params(*keys)
        keys.each do |key|
          value = params[key]
          return value if value.is_a?(ActionController::Parameters)
        end
        params
      end

      def authenticate_api_user!
        token = bearer_token
        raise Api::TokenService::InvalidToken, "missing bearer token" if token.blank?

        user = Api::TokenService.user_from_access(token)
        raise Api::TokenService::InvalidToken, "unknown user" if user.nil?
        raise Api::TokenService::InvalidToken, "account inactive" unless user.active_for_authentication?

        @current_user = user
      end

      def bearer_token
        request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1]
      end

      # --- error renderers -------------------------------------------------

      def render_error(status:, code:, message:, details: nil)
        payload = { code:, message: }
        payload[:details] = details if details.present?
        render json: { error: payload }, status:
      end

      def render_unauthorized(_error)
        render_error(status: :unauthorized, code: "unauthorized",
                     message: "Authentication is required.")
      end

      def render_forbidden(_error)
        render_error(status: :forbidden, code: "forbidden",
                     message: "You are not authorized to perform that action.")
      end

      def render_not_found(_error)
        render_error(status: :not_found, code: "not_found",
                     message: "The requested resource was not found.")
      end

      def render_parameter_missing(error)
        render_error(status: :bad_request, code: "parameter_missing", message: error.message)
      end

      def render_delete_restricted(_error)
        render_error(status: :conflict, code: "delete_restricted",
                     message: "This record cannot be removed because related history exists.")
      end

      # A unique-index violation that slipped past a model uniqueness validation
      # (a concurrent insert racing the same key) — a conflict, not a 500.
      def render_record_not_unique(_error)
        render_error(status: :conflict, code: "already_exists",
                     message: "That record already exists.")
      end

      def render_record_not_destroyed(error)
        record = error.record
        render_error(
          status: :conflict,
          code: "delete_restricted",
          message: record.errors.full_messages.to_sentence.presence ||
            "This record cannot be removed because related history exists.",
        )
      end

      # Service objects (PointsRedeemer, TransactionCreator, …) and models raise
      # ActiveRecord::RecordInvalid on failure — serialize the model errors.
      def render_record_invalid(error)
        record = error.record
        render_error(
          status: 422,
          code: "validation_failed",
          message: record.errors.full_messages.to_sentence.presence || "Validation failed.",
          details: record.errors.messages,
        )
      end
    end
  end
end
