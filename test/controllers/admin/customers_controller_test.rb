require "test_helper"

module Admin
  class CustomersControllerTest < ActionDispatch::IntegrationTest
    test "admin can view customer management screens" do
      sign_in users(:one)

      get new_admin_customer_path
      assert_response :success

      get admin_customer_path(customers(:one))
      assert_response :success
    end

    test "admin can create a customer with an initial vehicle" do
      sign_in users(:one)

      assert_difference -> { Customer.count }, 1 do
        assert_difference -> { Vehicle.count }, 1 do
          post admin_customers_path, params: {
            customer: {
              name: "Suresh",
              phone_number: "91234 56789",
              vehicle_number: "TN 22 CD 1234",
              fuel_type: "petrol",
              vehicle_kind: "lmv"
            }
          }
        end
      end

      customer = Customer.find_by!(phone_number: "9123456789")
      assert_redirected_to admin_customer_path(customer)
      assert_equal "Suresh", customer.name
      assert customer.active?
      assert_equal "TN22CD1234", customer.vehicles.first.vehicle_number
    end

    test "admin can delete a customer without transaction history" do
      sign_in users(:one)
      customer = Customer.create!(name: "Disposable", phone_number: "9012345678")

      assert_difference -> { Customer.count }, -1 do
        delete admin_customer_path(customer)
      end

      assert_redirected_to admin_customers_path
    end

    test "staff cannot delete a customer" do
      sign_in users(:two)

      delete admin_customer_path(customers(:one))

      assert_redirected_to root_path
      assert Customer.exists?(customers(:one).id)
    end
  end
end
