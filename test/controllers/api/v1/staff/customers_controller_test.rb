require "test_helper"

module Api
  module V1
    module Staff
      class CustomersControllerTest < ActionDispatch::IntegrationTest
        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "index filters customers by a dashboard period (E2 drill-through)" do
          recent = Customer.create!(name: "Recent Rita", phone_number: "9812300011")
          recent_vehicle = recent.vehicles.create!(vehicle_number: "TN01ZZ0011", fuel_type: :petrol, vehicle_kind: :two_wheeler)
          recent.transactions.create!(user: users(:two), vehicle: recent_vehicle, fuel_amount: 500, created_at: Time.current)

          stale = Customer.create!(name: "Stale Sam", phone_number: "9812300012")
          stale_vehicle = stale.vehicles.create!(vehicle_number: "TN01ZZ0012", fuel_type: :petrol, vehicle_kind: :two_wheeler)
          stale.transactions.create!(user: users(:two), vehicle: stale_vehicle, fuel_amount: 500, created_at: 40.days.ago)

          get api_v1_staff_customers_path(preset: "today"), headers: auth_headers(users(:two))

          assert_response :ok
          names = response.parsed_body["customers"].map { |c| c["name"] }
          assert_includes names, "Recent Rita"
          assert_not_includes names, "Stale Sam"
        end

        test "index without a period keeps the top-3 default" do
          get api_v1_staff_customers_path, headers: auth_headers(users(:two))

          assert_response :ok
          assert_operator response.parsed_body["customers"].size, :<=, 3
        end

        test "index filters by account type (E4)" do
          otp = Customer.create!(name: "Fleet Fran", phone_number: "9812300021", customer_type: :otp)
          otp.vehicles.create!(vehicle_number: "TN01ZZ0021", fuel_type: :petrol, vehicle_kind: :two_wheeler)
          drive = Customer.create!(name: "Walkin Will", phone_number: "9812300022", customer_type: :drive_in)
          drive.vehicles.create!(vehicle_number: "TN01ZZ0022", fuel_type: :petrol, vehicle_kind: :two_wheeler)

          get api_v1_staff_customers_path(type: "otp"), headers: auth_headers(users(:two))

          assert_response :ok
          names = response.parsed_body["customers"].map { |c| c["name"] }
          assert_includes names, "Fleet Fran"
          assert_not_includes names, "Walkin Will"
        end

        test "profile exposes the account type and contacts (B1/E4)" do
          customer = customers(:one)
          customer.update!(customer_type: :otp, transport_name: "Ace Transport")
          customer.customer_contacts.create!(role: "driver", name: "Ravi", phone_number: "9000011122", contacted: true)

          get api_v1_staff_customer_path(customer), headers: auth_headers(users(:two))

          assert_response :ok
          body = response.parsed_body
          assert_equal "otp", body["customer_type"]
          assert_equal "OTP / Fleet", body["customer_type_label"]
          assert_equal "Ace Transport", body["transport_name"]
          assert_equal 1, body["contacts"].size
          contact = body["contacts"].first
          assert_equal "driver", contact["role"]
          assert_equal "Driver", contact["role_label"]
          assert_equal "Ravi", contact["name"]
          assert contact["contacted"]
        end
      end
    end
  end
end
