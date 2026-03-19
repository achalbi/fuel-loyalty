require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  test "staff can edit customer details" do
    sign_in users(:two)

    get edit_customer_path(customers(:one))
    assert_response :success

    patch customer_path(customers(:one)), params: {
      customer: {
        name: "Arun Kumar",
        phone_number: "90000 00011"
      }
    }

    assert_redirected_to customer_path(customers(:one))
    assert_equal "Arun Kumar", customers(:one).reload.name
    assert_equal "9000000011", customers(:one).reload.phone_number
  end
end
