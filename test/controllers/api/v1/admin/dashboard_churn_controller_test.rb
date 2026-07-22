require "test_helper"

module Api
  module V1
    module Admin
      class DashboardChurnControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
          @lost = Customer.create!(name: "Churned Cust", phone_number: "9666600001")
          VisitEntry.create!(customer: @lost, user: @staff, fuel_pump: fuel_pumps(:one),
                             entry_date: Date.new(2026, 7, 10), vehicle_number: "TN66AA0001", litres: 30)
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "lists customers who lapsed since the previous window" do
          get api_v1_admin_dashboard_churn_path,
            params: { start_date: "2026-07-16", end_date: "2026-07-22" }, headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body
          ids = body["customers"].map { |c| c["id"] }
          assert_includes ids, @lost.id
          row = body["customers"].find { |c| c["id"] == @lost.id }
          assert row.key?("days_overdue")
          assert row.key?("conversion_probability")
        end

        test "staff cannot read the churn list" do
          get api_v1_admin_dashboard_churn_path, headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
