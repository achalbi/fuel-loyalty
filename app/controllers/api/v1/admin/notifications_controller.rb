module Api
  module V1
    module Admin
      # Admin JSON endpoint for ad-hoc push broadcasts.
      #
      # Authorization is the admin-only gate in Api::V1::Admin::BaseController (the
      # web Admin::NotificationDeliveriesController used AdminApiAuthenticatable with
      # no Pundit policy). The bearer-token path is intentionally NOT implemented.
      class NotificationsController < Api::V1::Admin::BaseController
        # POST /api/v1/admin/notifications/send  (action named `deliver` to avoid
        # shadowing Object#send). notification[title, message]. Returns the
        # FirebasePushService result hash.
        def deliver
          notification_params = params.fetch(:notification, params).permit(:title, :message)
          notification_params.require(:title)   # ParameterMissing -> base renders 400
          notification_params.require(:message)

          result = FirebasePushService.new.broadcast(
            title: notification_params[:title],
            message: notification_params[:message],
          )
          render json: result.as_json, status: :ok
        rescue FirebaseAppConfig::ConfigurationError => error
          render_error(status: 422, code: "configuration_error", message: error.message)
        end
      end
    end
  end
end
