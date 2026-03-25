module Admin
  class NotificationDeliveriesController < ApplicationController
    include AdminApiAuthenticatable

    def create
      result = FirebasePushService.new.broadcast(**delivery_params.to_h.symbolize_keys)

      respond_to do |format|
        format.json { render json: result.as_json, status: :ok }
        format.html do
          redirect_to admin_notifications_path,
                      notice: "Notification sent. #{result.sent} deliveries succeeded, #{result.failed} failed."
        end
      end
    rescue FirebaseAppConfig::ConfigurationError => error
      respond_with_error(error.message, status: :unprocessable_entity)
    rescue ActionController::ParameterMissing => error
      respond_with_error(error.message, status: :unprocessable_entity)
    end

    private

    def delivery_params
      notification_params = params.fetch(:notification, params).permit(:title, :message)
      notification_params.require(:title)
      notification_params.require(:message)
      notification_params
    end

    def respond_with_error(message, status:)
      respond_to do |format|
        format.json { render json: { error: message }, status: status }
        format.html { redirect_to admin_notifications_path, alert: message }
      end
    end
  end
end
