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
          assert_equal 75.0, body.dig("metrics", "litres")
          assert_equal 0.0, body.dig("metrics", "discount")
          assert_equal 0.0, body.dig("metrics", "gifts")
          assert_equal 3, body.dig("metrics", "visits")
          assert_not body.key?("lifetime_metrics"), "no period was asked for, so there is nothing to compare against"
        end

        test "a period narrows the commercial totals and carries the lifetime ones alongside" do
          @customer.points_ledgers.create!(entry_type: :redeem, points: -20, cash_reward_amount: 60,
                                           created_at: Time.zone.local(2026, 7, 8, 10, 0))

          get insight_api_v1_admin_customer_path(@customer, start_date: "2026-07-08", end_date: "2026-07-08"),
            headers: auth_headers(@admin)

          assert_response :ok
          body = response.parsed_body
          assert_equal 25.0, body.dig("metrics", "litres")
          assert_equal 60.0, body.dig("metrics", "gifts")
          assert_equal 75.0, body.dig("lifetime_metrics", "litres")
        end

        test "the insight carries the rewards rollup: discount paid, redemptions and gifts" do
          RewardSetting.current.update!(cash_value_per_point: 0.5)
          VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: fuel_pumps(:one),
                             entry_date: Date.new(2026, 7, 20), vehicle_number: "TN22AA0001",
                             litres: 20, discount_amount: 80)
          @customer.points_ledgers.create!(entry_type: :redeem, points: -40, cash_reward_amount: 90)
          campaign = Campaign.create!(name: "Monsoon gift", reward_kind: :gift, gift_description: "Steel bottle",
                                      min_purchase_litres: 10, period: :monthly, status: :active)
          campaign.campaign_qualifications.create!(customer: @customer, period_start: Date.new(2026, 7, 1),
                                                   period_end: Date.new(2026, 7, 31),
                                                   reward_granted_at: Time.zone.local(2026, 7, 21))

          get insight_api_v1_admin_customer_path(@customer), headers: auth_headers(@admin)

          assert_response :ok
          rewards = response.parsed_body["rewards"]
          assert_not_nil rewards, "item 5 ships the per-customer rewards block on this endpoint"
          assert_equal 80.0, rewards["discount_total"]
          assert_equal 90.0, rewards["redemption_value"]
          # Redeem rows store points negative; the payload reports the magnitude.
          assert_equal 40, rewards["redemption_points"]
          assert_equal 1, rewards["redemption_count"]
          assert_equal 1, rewards["gift_count"]
          assert_equal ["Steel bottle"], rewards["gift_descriptions"]
          assert_equal true, rewards["reward_value_configured"]
        end

        test "the rewards rollup stays all-time even when a period narrows the metrics" do
          VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: fuel_pumps(:one),
                             entry_date: Date.new(2026, 7, 20), vehicle_number: "TN22AA0001",
                             litres: 20, discount_amount: 80)

          get insight_api_v1_admin_customer_path(@customer, start_date: "2026-07-01", end_date: "2026-07-15"),
            headers: auth_headers(@admin)

          assert_response :ok
          body = response.parsed_body
          assert_equal 0.0, body.dig("metrics", "discount"), "the period totals stop at 15 July"
          assert_equal 80.0, body.dig("rewards", "discount_total"),
            "what the customer has ever been given is not narrowed by the admin's date filter"
        end

        # `reward_value_configured` exists so a structural ₹0 is not read as a real
        # one: with no cash-per-point rate every redemption stored a NULL amount.
        test "reward_value_configured reports whether a cash-per-point rate exists" do
          RewardSetting.current.update!(cash_value_per_point: nil)

          get insight_api_v1_admin_customer_path(@customer), headers: auth_headers(@admin)

          assert_response :ok
          assert_equal false, response.parsed_body.dig("rewards", "reward_value_configured")
          assert_equal 0.0, response.parsed_body.dig("rewards", "redemption_value")
        end

        # Lives here rather than in the staff-API test because this is the other
        # half of item 5 for the SAME admin screen: the Android customer profile
        # renders the rewards rollup above and the per-transaction discount below
        # it, and the profile payload is what carries the per-transaction figure.
        test "the customer profile transaction JSON carries each fuelling's own discount" do
          vehicle = @customer.vehicles.create!(vehicle_number: "TN22DD0001", fuel_type: :petrol, vehicle_kind: :two_wheeler)
          Transaction.create!(customer: @customer, user: @staff, vehicle: vehicle, fuel_pump: fuel_pumps(:one),
                              fuel_amount: 1500, payment_mode: "cash", discount_amount: 35)

          get api_v1_staff_customer_path(@customer), headers: auth_headers(@admin)

          assert_response :ok
          txn = response.parsed_body["recent_transactions"].first
          assert_equal 35.0, txn["discount_amount"]
        end

        test "staff cannot read customer insight" do
          get insight_api_v1_admin_customer_path(@customer), headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
