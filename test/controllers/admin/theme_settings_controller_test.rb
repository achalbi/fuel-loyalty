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
      purger_singleton = Cdn::Purger.singleton_class
      original_call = purger_singleton.instance_method(:call)

      purger_singleton.define_method(:call) do |paths: Cdn::Purger::PUBLIC_CACHE_PATHS|
        :ok
      end

      begin
        patch admin_theme_settings_path, params: {
          theme_setting: {
            primary_color: "#1F8A4C"
          }
        }
      ensure
        purger_singleton.define_method(:call, original_call)
      end

      assert_redirected_to admin_theme_settings_path
      assert_equal "#1F8A4C", theme_settings(:default).reload.primary_color
    end

    test "theme updates trigger a public cache purge" do
      sign_in users(:one)

      captured = nil
      purger_singleton = Cdn::Purger.singleton_class
      original_call = purger_singleton.instance_method(:call)

      purger_singleton.define_method(:call) do |paths: Cdn::Purger::PUBLIC_CACHE_PATHS|
        captured = paths
        :ok
      end

      begin
        patch admin_theme_settings_path, params: {
          theme_setting: {
            primary_color: "#2A8F56"
          }
        }
      ensure
        purger_singleton.define_method(:call, original_call)
      end

      assert_redirected_to admin_theme_settings_path
      assert_equal Cdn::Purger::PUBLIC_CACHE_PATHS, captured
    end
  end
end
