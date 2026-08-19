require "test_helper"

module Admin
  module Crm
    class CustomerInsightTest < ActiveSupport::TestCase
      AS_OF = Time.zone.local(2026, 7, 22, 12, 0, 0)

      setup do
        # A fresh customer with no fixture transactions, so the visit history under
        # test is exactly what each case creates.
        @customer = Customer.create!(name: "Cadence Cust", phone_number: "9111100001")
        @staff = users(:two)
        @pump = fuel_pumps(:one)
      end

      def add_visit(date)
        VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: @pump, entry_date: date,
                           vehicle_number: "TN01AA1111", litres: 30)
      end

      test "derives weekly cadence and recency from visit history" do
        [Date.new(2026, 7, 1), Date.new(2026, 7, 8), Date.new(2026, 7, 15)].each { |d| add_visit(d) }
        data = CustomerInsight.new(@customer, as_of: AS_OF).to_h

        assert_equal "weekly", data[:cadence_class]
        assert_equal 3, data[:visit_count]
        assert_equal Date.new(2026, 7, 15), data[:last_visited_on]
        assert_equal Date.new(2026, 7, 1), data[:first_visited_on]
        assert_equal 7, data[:days_since_last_visit]
        assert_equal Date.new(2026, 7, 22), data[:expected_next_visit_on]
        assert_operator data[:conversion_probability], :>, 0
      end

      test "unions transaction dates with visit-entry dates" do
        add_visit(Date.new(2026, 7, 8))
        add_visit(Date.new(2026, 7, 15))
        vehicle = Vehicle.create!(customer: @customer, vehicle_number: "TN09XX0001", fuel_type: "petrol", vehicle_kind: "two_wheeler")
        Transaction.create!(customer: @customer, user: @staff, fuel_pump: @pump, vehicle: vehicle,
                            fuel_amount: 500, payment_mode: "cash", created_at: Time.zone.local(2026, 7, 1, 9))
        data = CustomerInsight.new(@customer, as_of: AS_OF).to_h
        assert_equal 3, data[:visit_count]
        assert_equal Date.new(2026, 7, 1), data[:first_visited_on]
      end

      test "summarises contacts and feedback" do
        add_visit(Date.new(2026, 7, 15))
        ContactLog.create!(customer: @customer, user: @staff, channel: "call", outcome: "reached",
                           contacted_at: Time.zone.local(2026, 7, 20, 10))
        CustomerFeedback.create!(customer: @customer, rating: 4, source: "staff")
        CustomerFeedback.create!(customer: @customer, rating: 5, source: "admin", comment: "Great")

        data = CustomerInsight.new(@customer, as_of: AS_OF).to_h
        assert_equal 1, data[:contacts][:count]
        assert_equal "reached", data[:contacts][:last_outcome]
        assert_equal 2, data[:feedback][:count]
        assert_equal 4.5, data[:feedback][:avg_rating]
      end

      test "lost is true once past the expected next visit" do
        # weekly cadence, last visit 30 days before as_of → overdue
        [Date.new(2026, 6, 1), Date.new(2026, 6, 8), Date.new(2026, 6, 15)].each { |d| add_visit(d) }
        data = CustomerInsight.new(@customer, as_of: AS_OF).to_h
        assert data[:is_lost]
      end

      # ---- Item 5: the rewards rollup ------------------------------------

      def add_visit_with_discount(date, discount)
        VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: @pump, entry_date: date,
                           vehicle_number: "TN01AA1111", litres: 30, discount_amount: discount)
      end

      # F1 gift: granting stamps reward_granted_at and writes no ledger row, so
      # the stamp is the only trace that anything was handed over.
      def grant_gift(description: "Steel bottle", name: "Monsoon gift", kind: :gift,
                     granted_at: Time.zone.local(2026, 7, 12), period_start: Date.new(2026, 7, 1))
        campaign = Campaign.create!(name: name, reward_kind: kind,
                                    gift_description: (description if kind == :gift),
                                    bonus_points: (50 if kind == :bonus_points),
                                    min_purchase_litres: 20, period: :monthly, status: :active)
        campaign.campaign_qualifications.create!(customer: @customer, period_start: period_start,
                                                 period_end: period_start.end_of_month,
                                                 reward_granted_at: granted_at)
      end

      test "rewards report discount paid, points redeemed and gifts handed over" do
        add_visit_with_discount(Date.new(2026, 7, 8), 45)
        add_visit_with_discount(Date.new(2026, 7, 15), 30)
        @customer.points_ledgers.create!(entry_type: :redeem, points: -120, cash_reward_amount: 60)
        @customer.points_ledgers.create!(entry_type: :redeem, points: -80, cash_reward_amount: 40)
        grant_gift

        rewards = CustomerInsight.new(@customer, as_of: AS_OF).to_h[:rewards]

        assert_equal 75.0, rewards[:discount_total]
        assert_equal 100.0, rewards[:redemption_value]
        assert_equal 200, rewards[:redemption_points]
        assert_equal 2, rewards[:redemption_count]
        assert_equal 1, rewards[:gift_count]
        assert_equal ["Steel bottle"], rewards[:gift_descriptions]
      end

      test "discount_total is Customer#discount_total, so a linked capture and its transaction count once" do
        vehicle = Vehicle.create!(customer: @customer, vehicle_number: "TN09XX0002", fuel_type: "petrol", vehicle_kind: "two_wheeler")
        # VisitEntryRecorder copies the capture's discount onto the transaction it
        # creates and back-links it; summing both sides would double the figure.
        txn = Transaction.create!(customer: @customer, user: @staff, fuel_pump: @pump, vehicle: vehicle,
                                  fuel_amount: 900, payment_mode: "cash", discount_amount: 40,
                                  created_at: Time.zone.local(2026, 7, 9, 9))
        VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: @pump, fuel_transaction: txn,
                           entry_date: Date.new(2026, 7, 9), vehicle_number: "TN09XX0002",
                           litres: 20, discount_amount: 40)

        rewards = CustomerInsight.new(@customer, as_of: AS_OF).to_h[:rewards]

        assert_equal 40.0, rewards[:discount_total], "the linked pair is one discount, not two"
        assert_equal @customer.discount_total.to_f, rewards[:discount_total],
          "the rollup must reuse Customer#discount_total rather than restate the rule"
      end

      test "redeemed points read positive even though redeem rows store them negative" do
        # PointsRedeemer writes redemptions as a negative `points` movement.
        @customer.points_ledgers.create!(entry_type: :redeem, points: -250, cash_reward_amount: 125)
        # Earnings are not redemptions and must not leak into either figure.
        @customer.points_ledgers.create!(entry_type: :earn, points: 300, cash_reward_amount: 150)

        rewards = CustomerInsight.new(@customer, as_of: AS_OF).to_h[:rewards]

        assert_equal 250, rewards[:redemption_points]
        assert_equal 125.0, rewards[:redemption_value]
        assert_equal 1, rewards[:redemption_count]
      end

      test "gifts count only granted qualifications on gift campaigns, and name each gift once" do
        grant_gift(name: "July gift", period_start: Date.new(2026, 7, 1))
        # Same gift won again in a later period: two handovers, one description.
        grant_gift(name: "August gift", period_start: Date.new(2026, 8, 1),
                   granted_at: Time.zone.local(2026, 8, 12))
        # Granted, but the campaign hands out points — not a physical gift.
        grant_gift(kind: :bonus_points, name: "Points push")
        # A gift campaign qualified for but never actually handed over.
        pending = Campaign.create!(name: "Pending gift", reward_kind: :gift, gift_description: "Cap",
                                   min_purchase_litres: 20, period: :monthly, status: :active)
        pending.campaign_qualifications.create!(customer: @customer, period_start: Date.new(2026, 7, 1),
                                                period_end: Date.new(2026, 7, 31), reward_granted_at: nil)

        rewards = CustomerInsight.new(@customer, as_of: AS_OF).to_h[:rewards]

        assert_equal 2, rewards[:gift_count]
        assert_equal ["Steel bottle"], rewards[:gift_descriptions]
      end

      test "rewards stay all-time while the metrics follow the selected period" do
        add_visit_with_discount(Date.new(2026, 6, 10), 200)
        add_visit_with_discount(Date.new(2026, 7, 10), 50)
        grant_gift(granted_at: Time.zone.local(2026, 6, 12), period_start: Date.new(2026, 6, 1))

        july = Time.zone.local(2026, 7, 1)..Time.zone.local(2026, 7, 31).end_of_day
        data = CustomerInsight.new(@customer, as_of: AS_OF, range: july).to_h

        assert_equal 50.0, data[:metrics][:discount], "the period card is windowed"
        assert_equal 250.0, data[:rewards][:discount_total], "what we have ever paid out is not"
        assert_equal 1, data[:rewards][:gift_count], "a gift given in June did not un-happen in July"
      end

      test "reward_value_configured follows the cash-per-point setting" do
        RewardSetting.current.update!(cash_value_per_point: nil)
        assert_not CustomerInsight.new(@customer, as_of: AS_OF).to_h[:rewards][:reward_value_configured],
          "with no rate every redemption stored a NULL amount, so a ₹0 total is structural"

        RewardSetting.current.update!(cash_value_per_point: 0.5)
        assert CustomerInsight.new(@customer, as_of: AS_OF).to_h[:rewards][:reward_value_configured]
      end
    end
  end
end
