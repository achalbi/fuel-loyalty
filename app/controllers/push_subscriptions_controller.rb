class PushSubscriptionsController < ApplicationController
  # JSON registration endpoint for both the web PWA and the native app. The native
  # client authenticates with a JWT and has no session cookie / CSRF token, so the
  # inherited forgery check would 422 every cookieless POST. The payload is just an
  # FCM registration token (no cookie-based state to protect), so skip CSRF here.
  skip_before_action :verify_authenticity_token

  def create
    token = PushSubscription.normalize_token(subscription_params.fetch(:token))
    existing = PushSubscription.exists?(token: token)

    # `platform` is optional: some clients (e.g. the native app via kotlinx, which
    # drops default-valued fields) omit it. The model coerces a blank/unknown value
    # to "unknown", so only the token is truly required.
    subscription = PushSubscription.register!(
      token: token,
      platform: subscription_params[:platform],
      last_used_at: Time.current
    )

    render json: {
      id: subscription.id,
      active: subscription.active,
      platform: subscription.platform
    }, status: existing ? :ok : :created
  rescue ActionController::ParameterMissing => error
    render json: { error: error.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    subscription = PushSubscription.find_by(token: PushSubscription.normalize_token(params.require(:token)))
    subscription&.deactivate!

    head :no_content
  rescue ActionController::ParameterMissing => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  private

  def subscription_params
    params.permit(:token, :platform)
  end
end
