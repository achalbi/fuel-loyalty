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
      end
    end
  end
end
