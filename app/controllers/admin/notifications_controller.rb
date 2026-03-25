module Admin
  class NotificationsController < BaseController
    include AdminNotificationsPageState

    def show
      load_notifications_page_state
    end
  end
end
