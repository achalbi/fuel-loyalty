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
    #
    # Optional identity (F2 targeting): a signed-in staff user is captured from
    # the session, and an identified customer from an optional `phone_number`.
    subscription = PushSubscription.register!(
      token: token,
      platform: subscription_params[:platform],
      last_used_at: Time.current,
      customer: resolve_customer,
      user: current_user
    )

    # F2 — a customer identifying via their phone on the loyalty PWA is the push
    # opt-in; stamp consent once so a later anonymous re-register doesn't clear it.
    subscription.update_column(:consent_at, Time.current) if subscription.customer_id.present? && subscription.consent_at.nil?

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
    params.permit(:token, :platform, :phone_number)
  end

  # Links the token to a customer when the client supplies a valid, known phone
  # (e.g. a customer who identified on the loyalty PWA). Unknown/blank -> nil,
  # so the subscription stays anonymous rather than erroring.
  def resolve_customer
    phone = Customer.normalize_phone_number(subscription_params[:phone_number])
    return nil unless Customer.valid_phone_number?(phone)

    Customer.find_by(phone_number: phone)
  end
end
