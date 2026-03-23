require "test_helper"

module Analytics
  class EventsControllerTest < ActionDispatch::IntegrationTest
    test "records supported install analytics events" do
      assert_difference("AnalyticsEvent.count", 1) do
        post analytics_events_path, params: {
          name: "pwa_install_cta_clicked",
          page_path: new_user_session_path,
          properties: {
            source: "login_page",
            prompt_available: true
          }
        }, as: :json
      end

      assert_response :accepted

      analytics_event = AnalyticsEvent.order(:id).last
      assert_equal "pwa_install_cta_clicked", analytics_event.name
      assert_equal new_user_session_path, analytics_event.page_path
      assert_equal "login_page", analytics_event.properties["source"]
      assert_equal true, analytics_event.properties["prompt_available"]
    end

    test "rejects unsupported analytics events" do
      assert_no_difference("AnalyticsEvent.count") do
        post analytics_events_path, params: {
          name: "page_view",
          page_path: new_user_session_path,
          properties: {
            source: "login_page"
          }
        }, as: :json
      end

      assert_response :unprocessable_entity
    end
  end
end
