require "test_helper"

module Staff
  class CustomersControllerTest < ActionDispatch::IntegrationTest
    test "staff can browse top three customers by points and search customers" do
      sign_in users(:two)

      low = Customer.create!(name: "Low Points", phone_number: "9000000101")
      mid = Customer.create!(name: "Mid Points", phone_number: "9000000102")
      high = Customer.create!(name: "High Points", phone_number: "9000000103")
      top = Customer.create!(name: "Top Points", phone_number: "9000000104")

      { low => 120, mid => 260, high => 410, top => 650 }.each do |customer, points|
        customer.points_ledgers.create!(points:, entry_type: :earn)
      end

      get staff_customers_path
      assert_response :success
      assert_equal "private, no-store", response.headers["Cache-Control"]
      assert_select "h1", "Customers"
      assert_select "button.admin-customers-create-action[data-bs-toggle='modal'][data-bs-target='#addCustomerModal'][aria-label='Add Customer']", text: /\+ Add Customer/
      assert_select "#addCustomerModal"
      assert_select ".admin-customer-item", 3

      names = css_select(".admin-customer-item__name").map(&:text)
      assert_equal ["Top Points", "High Points", "Mid Points"], names
      assert_select ".admin-customer-item__points", text: /650 pts/
      assert_select ".admin-customer-item__status", text: "Active"
      assert_select "a[aria-label='View Top Points']"
      refute_includes names, "Low Points"

      get staff_customers_path, params: { q: "9000000002" }
      assert_response :success
      assert_select ".admin-customer-item__name", text: "Meena"
      assert_select ".admin-customer-item__phone", text: /\+91 9000000002/
      assert_select ".admin-customer-item", 1
    end

    test "staff create failure re-renders index modal with errors" do
      sign_in users(:two)

      assert_no_difference -> { Customer.count } do
        post staff_customers_path, params: {
          customer: {
            name: "",
            phone_number: "123",
            vehicle_number: "TN 22 CD 1234",
            fuel_type: "",
            vehicle_kind: ""
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "#addCustomerModal[data-auto-open-modal='true']"
      assert_select "#addCustomerModal .alert.alert-danger"
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
      assert_select "input[type='radio'][name='customer[fuel_type]'][value='petrol']", 1
      assert_select "input[type='radio'][name='customer[fuel_type]'][value='diesel']", 1
      assert_select "select[name='customer[fuel_type]']", 0
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='two_wheeler']", 1
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='three_wheeler']", 1
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='lmv']", 1
      assert_select "label[for='customer_vehicle_kind_two_wheeler'] i.ti.ti-bike", 1
      assert_select "label[for='customer_vehicle_kind_three_wheeler'] [data-vehicle-type-icon='custom-tuk-tuk']", 1
      assert_select "select[name='customer[vehicle_kind]']", 0
      assert_select "button[data-cancel-back-button='true'][data-fallback-path='#{staff_customers_path}']", text: "Cancel"
      assert_includes response.body, "window.history.back()"
    end

    test "staff new customer screen hides inactive fuel types" do
      sign_in users(:two)
      fuel_types(:diesel).update!(active: false)

      get new_staff_customer_path

      assert_response :success
      assert_select "input[type='radio'][name='customer[fuel_type]'][value='petrol']", 1
      assert_select "input[type='radio'][name='customer[fuel_type]'][value='diesel']", 0
      assert_select "input[type='radio'][name='customer[fuel_type]'][value='cng_lpg']", 1
    end

    test "staff new customer screen hides inactive vehicle types" do
      sign_in users(:two)
      vehicle_types(:lmv).update!(active: false)

      get new_staff_customer_path

      assert_response :success
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='two_wheeler']", 1
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='lmv']", 0
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='lcv']", 1
      assert_select "select[name='customer[vehicle_kind]']", 0
    end

    test "staff new customer screen shows dynamically added vehicle types" do
      sign_in users(:two)
      VehicleType.create!(name: "Mini Van", short_name: "MV", app_label_source: "short_name", icon_name: "ti-car", active: true)

      get new_staff_customer_path

      assert_response :success
      assert_select "input[type='radio'][name='customer[vehicle_kind]'][value='mini_van']", 1
      assert_select "label[for='customer_vehicle_kind_mini_van']", text: "MV"
      assert_select "label[for='customer_vehicle_kind_mini_van'] i.ti.ti-car", 1
    end

    test "staff new customer screen can show full vehicle type name when configured" do
      sign_in users(:two)
      VehicleType.create!(name: "Pickup Truck", short_name: "PT", app_label_source: "name", icon_name: "custom-pickup-truck", active: true)

      get new_staff_customer_path

      assert_response :success
      assert_select "label[for='customer_vehicle_kind_pickup_truck']", text: "Pickup Truck"
      assert_select "label[for='customer_vehicle_kind_pickup_truck'] [data-vehicle-type-icon='custom-pickup-truck']", 1
    end

    test "staff new customer screen shows dynamically added fuel types" do
      sign_in users(:two)
      FuelType.create!(name: "EV Charging", active: true)

      get new_staff_customer_path

      assert_response :success
      assert_select "input[type='radio'][name='customer[fuel_type]'][value='ev_charging']", 1
      assert_select "label[for='customer_fuel_type_ev_charging']", text: "EV Charging"
    end

    test "staff new customer screen prefills searched phone and vehicle values" do
      sign_in users(:two)

      get new_staff_customer_path, params: { phone_number: "98888 77777", vehicle_number: "tn 30 ab 1234" }

      assert_response :success
      assert_select "input[name='customer[phone_number]'][value='9888877777']"
      assert_select "input[name='customer[vehicle_number]'][value='TN30AB1234']"
    end
  end
end
