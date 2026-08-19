require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "anonymous visitors are sent to the public loyalty lookup" do
    get root_path

    assert_response :redirect
    assert_redirected_to new_loyalty_path
  end

  test "staff users land on Home with the loyalty lookup form" do
    sign_in users(:two)

    get root_path

    assert_response :success
    assert_select "h1", "Home"
    assert_select "h2#home-loyalty-lookup-title", "Loyalty Lookup"
    assert_select "form[action='#{loyalty_path}'][method='post']", 1
    assert_select "input[name='loyalty[phone_number]'][data-phone-number-field='true']", 1
    assert_select "a.nav-link[href='#{root_path}'].active", text: /Home/
    assert_select "a.nav-link[href='#{new_staff_transaction_path}']", text: /New Entry/
  end

  test "admin users land on Home with the loyalty lookup form" do
    sign_in users(:one)

    get root_path

    assert_response :success
    assert_select "h1", "Home"
    assert_select "form[action='#{loyalty_path}'][method='post']", 1
    assert_select "a.nav-link[href='#{root_path}'].active", text: /Home/
    assert_select "a.nav-link[href='#{admin_dashboard_path}']", text: /Dashboard/
  end
end
