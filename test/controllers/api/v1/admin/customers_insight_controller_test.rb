require "test_helper"

module Api
  module V1
    module Admin
      class CustomersInsightControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
          @customer = Customer.create!(name: "Insight Cust", phone_number: "9222200001")
          [Date.new(2026, 7, 1), Date.new(2026, 7, 8), Date.new(2026, 7, 15)].each do |date|
            VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: fuel_pumps(:one),
                               entry_date: date, vehicle_number: "TN22AA0001", litres: 25)
          end
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "returns the per-customer insight for an admin" do
          get insight_api_v1_admin_customer_path(@customer), headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body
          assert_equal @customer.id, body["customer_id"]
          assert_equal 3, body["visit_count"]
          assert_equal "weekly", body["cadence_class"]
          assert_equal "2026-07-15", body["last_visited_on"]
          assert body.key?("conversion_probability")
          assert body.key?("contacts")
          assert body.key?("feedback")
        end

        test "staff cannot read customer insight" do
          get insight_api_v1_admin_customer_path(@customer), headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
