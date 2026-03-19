require "test_helper"

class ThemeSettingTest < ActiveSupport::TestCase
  test "normalizes primary color to uppercase hex" do
    theme_setting = ThemeSetting.new(primary_color: "#43b05c")

    assert theme_setting.valid?
    assert_equal "#43B05C", theme_setting.primary_color
  end

  test "builds css variable hashes for light and dark mode" do
    theme_setting = ThemeSetting.new(primary_color: "#228B22")

    assert_equal "#228B22", theme_setting.light_css_variables["--fl-primary"]
    assert_equal "34, 139, 34", theme_setting.light_css_variables["--bs-primary-rgb"]
    assert_match(/\A#[0-9A-F]{6}\z/, theme_setting.dark_css_variables["--fl-primary"])
  end
end
