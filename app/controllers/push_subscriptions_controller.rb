class PushSubscriptionsController < ApplicationController
  def create
    token = PushSubscription.normalize_token(subscription_params.fetch(:token))
    existing = PushSubscription.exists?(token: token)

    subscription = PushSubscription.register!(
      token: token,
      platform: subscription_params.fetch(:platform),
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
