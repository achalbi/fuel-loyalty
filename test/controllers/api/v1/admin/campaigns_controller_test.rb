require "test_helper"

module Api
  module V1
    module Admin
      class CampaignsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        def create_params
          {
            campaign: {
              name: "Weekend fills", reward_kind: "bonus_points", bonus_points: 150,
              min_purchase_amount: 800, period: "rolling_days", period_days: 30,
              target_type: "selected", channels: %w[push whatsapp],
              target_customer_ids: [customers(:one).id],
            },
          }
        end

        test "admin creates a campaign with targets and channels" do
          assert_difference -> { Campaign.count }, 1 do
            post api_v1_admin_campaigns_path, params: create_params, headers: auth_headers(@admin)
          end
          assert_response :created
          body = response.parsed_body
          assert_equal %w[push whatsapp], body["channels"]
          assert_equal [customers(:one).id], body["target_customer_ids"]
        end

        test "preview returns a dry-run count without granting" do
          customers(:one).transactions.create!(user: @staff, vehicle: vehicles(:one), fuel_amount: 900, payment_mode: "cash")
          post api_v1_admin_campaigns_path, params: create_params, headers: auth_headers(@admin)
          id = response.parsed_body["id"]

          assert_no_difference -> { PointsLedger.count } do
            post preview_api_v1_admin_campaign_path(id), headers: auth_headers(@admin)
          end
          assert_response :ok
          assert_operator response.parsed_body["qualifying_count"], :>=, 1
        end

        test "run grants and reports delivery" do
          customers(:one).transactions.create!(user: @staff, vehicle: vehicles(:one), fuel_amount: 900, payment_mode: "cash")
          post api_v1_admin_campaigns_path, params: create_params, headers: auth_headers(@admin)
          id = response.parsed_body["id"]
          patch activate_api_v1_admin_campaign_path(id), headers: auth_headers(@admin) # only active campaigns grant

          post run_api_v1_admin_campaign_path(id), params: { notify: false }, headers: auth_headers(@admin)
          assert_response :ok
          assert_equal 1, response.parsed_body["rewarded"]
        end

        test "activate and pause flip status" do
          post api_v1_admin_campaigns_path, params: create_params, headers: auth_headers(@admin)
          id = response.parsed_body["id"]
          patch activate_api_v1_admin_campaign_path(id), headers: auth_headers(@admin)
          assert_equal "active", response.parsed_body["status"]
          patch pause_api_v1_admin_campaign_path(id), headers: auth_headers(@admin)
          assert_equal "paused", response.parsed_body["status"]
        end

        test "staff cannot manage campaigns" do
          get api_v1_admin_campaigns_path, headers: auth_headers(@staff)
          assert_response :forbidden
        end

        test "an invalid campaign is rejected 422" do
          post api_v1_admin_campaigns_path,
            params: { campaign: { name: "", reward_kind: "gift", period: "weekly", target_type: "all" } },
            headers: auth_headers(@admin)
          assert_response :unprocessable_entity
        end
      end
    end
  end
end
