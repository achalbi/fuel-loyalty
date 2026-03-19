require "test_helper"

module Admin
  class ThemeSettingsControllerTest < ActionDispatch::IntegrationTest
    test "admin can view theme settings" do
      sign_in users(:one)

      get admin_theme_settings_path

      assert_response :success
      assert_select "h1", "Theme Settings"
    end

    test "admin can update the primary color" do
      sign_in users(:one)

      patch admin_theme_settings_path, params: {
        theme_setting: {
          primary_color: "#1F8A4C"
        }
      }

      assert_redirected_to admin_theme_settings_path
      assert_equal "#1F8A4C", theme_settings(:default).reload.primary_color
    end
  end
end
