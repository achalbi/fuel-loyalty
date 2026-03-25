require "digest"

module AdminApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    skip_before_action :block_unsupported_browser
    protect_from_forgery with: :null_session
    before_action :authenticate_admin_request!
  end

  private

  def authenticate_admin_request!
    return if current_user&.admin?
    return if valid_bearer_token?

    respond_to do |format|
      format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
      format.html { head :unauthorized }
      format.any { head :unauthorized }
    end
  end

  def valid_bearer_token?
    expected = ENV["ADMIN_NOTIFICATION_API_TOKEN"].to_s
    provided = bearer_token.to_s
    return false if expected.blank? || provided.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(provided),
      Digest::SHA256.hexdigest(expected)
    )
  end

  def bearer_token
    request.authorization.to_s[/\ABearer (.+)\z/i, 1]
  end
end
