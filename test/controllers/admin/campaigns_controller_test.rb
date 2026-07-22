require "test_helper"

module Admin
  class CampaignsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @staff = users(:two)
    end

    def valid_params
      {
        campaign: {
          name: "Weekend", reward_kind: "bonus_points", bonus_points: 150,
          min_purchase_amount: 800, period: "rolling_days", period_days: 30,
          target_type: "all", channels: %w[push],
        },
      }
    end

    test "admin can open the new-campaign form" do
      sign_in @admin
      get new_admin_campaign_path
      assert_response :success
      assert_select "form"
    end

    test "admin creates a campaign and lands on its page" do
      sign_in @admin
      assert_difference -> { Campaign.count }, 1 do
        post admin_campaigns_path, params: valid_params
      end
      assert_redirected_to admin_campaign_path(Campaign.order(:id).last)
    end

    test "invalid campaign re-renders with errors" do
      sign_in @admin
      post admin_campaigns_path, params: { campaign: { name: "", reward_kind: "gift", period: "weekly", target_type: "all" } }
      assert_response :unprocessable_entity
    end

    test "run redirects with a summary" do
      sign_in @admin
      campaign = Campaign.create!(name: "R", reward_kind: :bonus_points, bonus_points: 50, min_purchase_amount: 100,
                                  period: :rolling_days, period_days: 30, target_type: :all, channels: "push", status: :active)
      post run_admin_campaign_path(campaign), params: { notify: "false" }
      assert_redirected_to admin_campaign_path(campaign)
    end

    test "activate + pause flip status" do
      sign_in @admin
      campaign = Campaign.create!(name: "S", reward_kind: :bonus_points, bonus_points: 50, min_purchase_amount: 100,
                                  period: :rolling_days, period_days: 30, target_type: :all, channels: "push")
      patch activate_admin_campaign_path(campaign)
      assert campaign.reload.active?
      patch pause_admin_campaign_path(campaign)
      assert campaign.reload.paused?
    end

    test "non-admin is bounced" do
      sign_in @staff
      get admin_campaigns_path
      assert_response :redirect
    end
  end
end
