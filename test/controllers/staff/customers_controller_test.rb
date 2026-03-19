require "test_helper"

module Staff
  class CustomersControllerTest < ActionDispatch::IntegrationTest
    test "staff can browse and search customers" do
      sign_in users(:two)

      get staff_customers_path
      assert_response :success
      assert_select "h1", "Customer Search"
      assert_select "td", text: "Arun"

      get staff_customers_path, params: { q: "9000000002" }
      assert_response :success
      assert_select "td", text: "Meena"
    end

    test "staff can create a customer with an initial vehicle" do
      sign_in users(:two)

      assert_difference -> { Customer.count }, 1 do
        assert_difference -> { Vehicle.count }, 1 do
          post staff_customers_path, params: {
            customer: {
              name: "Kiran",
              phone_number: "98888 77777",
              vehicle_number: "TN 30 AB 1234",
              fuel_type: "petrol",
              vehicle_kind: "two_wheeler"
            }
          }
        end
      end

      customer = Customer.find_by!(phone_number: "9888877777")
      assert_redirected_to customer_path(customer)
      assert_equal "Kiran", customer.name
      assert_equal "TN30AB1234", customer.vehicles.first.vehicle_number
    end

    test "staff can render the new customer screen" do
      sign_in users(:two)

      get new_staff_customer_path

      assert_response :success
    end
  end
end
