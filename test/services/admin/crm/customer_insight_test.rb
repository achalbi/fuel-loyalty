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

      def add_visit(date, discount: 0, fuel_transaction: nil)
        VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: @pump, entry_date: date,
                           vehicle_number: "TN01AA1111", litres: 30,
                           discount_amount: discount, fuel_transaction: fuel_transaction)
      end

      def vehicle
        @vehicle ||= Vehicle.create!(customer: @customer, vehicle_number: "TN09XX0002",
                                     fuel_type: "petrol", vehicle_kind: "two_wheeler")
      end

      def add_transaction(date, discount: 0, amount: 500)
        Transaction.create!(customer: @customer, user: @staff, fuel_pump: @pump, vehicle: vehicle,
                            fuel_amount: amount, discount_amount: discount, payment_mode: "cash",
                            created_at: date.in_time_zone.change(hour: 9))
      end

      # F1 gift grant: stamping reward_granted_at is the whole record of the hand-over
      # — no ledger row, no ₹ (mirrors the LedgerReport test's helper).
      def grant_gift(kind: :gift, name: "Monsoon gift", description: "Steel bottle",
                     granted_at: Time.zone.local(2026, 7, 12), period_start: Date.new(2026, 7, 1))
        campaign = Campaign.create!(name: name, reward_kind: kind,
                                    gift_description: (description if kind == :gift),
                                    bonus_points: (50 if kind == :bonus_points),
                                    min_purchase_litres: 20, period: :monthly, status: :active)
        campaign.campaign_qualifications.create!(customer: @customer, period_start: period_start,
                                                 period_end: period_start.end_of_month,
                                                 reward_granted_at: granted_at)
      end

      def rewards_for(customer = @customer)
        CustomerInsight.new(customer, as_of: AS_OF).to_h[:rewards]
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

      # ---- Item 5: rewards given (discount, redemptions, gifts) ----------------

      # The double-count trap. VisitEntryRecorder COPIES the visit entry's discount
      # onto the loyalty transaction it links, so a naive
      # `visit_entries.sum + transactions.sum` reports ₹200 for one ₹100 fuelling.
      test "a linked visit and transaction pair counts its discount once" do
        pair = add_transaction(Date.new(2026, 7, 10), discount: 100)
        add_visit(Date.new(2026, 7, 10), discount: 100, fuel_transaction: pair)

        assert_equal 100.0, rewards_for[:discount_total],
          "the discount copied onto the linked transaction must not be counted twice"
      end

      test "standalone visits and standalone transactions both count toward the discount" do
        # A linked pair (₹100, counted once), a capture with no loyalty transaction
        # behind it (₹40), and a counter transaction with no capture (₹25).
        pair = add_transaction(Date.new(2026, 7, 10), discount: 100)
        add_visit(Date.new(2026, 7, 10), discount: 100, fuel_transaction: pair)
        add_visit(Date.new(2026, 7, 12), discount: 40)
        add_transaction(Date.new(2026, 7, 14), discount: 25)

        assert_equal 165.0, rewards_for[:discount_total]
      end

      test "discount_total is zero for a customer who was never given one" do
        add_visit(Date.new(2026, 7, 15))
        add_transaction(Date.new(2026, 7, 16))

        assert_equal 0.0, rewards_for[:discount_total]
      end

      # CustomerInsight only ever asks for the all-time figure, but the cohort
      # screens window it, so the `range:` branch is exercised straight against the
      # model. The interesting case is a BACK-DATED pair: the capture and the
      # transaction it copied the discount onto land on opposite sides of the
      # boundary. The anti-join is scoped to the same WINDOWED visit scope, which
      # is exactly what stops both sides from disowning it.
      test "a windowed discount_total counts a straddling pair once, on whichever side is inside" do
        # Pair A: rung up 1 Jul, its capture back-dated to 30 Jun (outside July).
        pair_a = add_transaction(Date.new(2026, 7, 1), discount: 100)
        add_visit(Date.new(2026, 6, 30), discount: 100, fuel_transaction: pair_a)
        # Pair B: captured 31 Jul, its transaction rung up 1 Aug (outside July).
        pair_b = add_transaction(Date.new(2026, 8, 1), discount: 60)
        add_visit(Date.new(2026, 7, 31), discount: 60, fuel_transaction: pair_b)
        # A pair wholly inside, and a June capture the window must drop entirely.
        pair_c = add_transaction(Date.new(2026, 7, 10), discount: 40)
        add_visit(Date.new(2026, 7, 10), discount: 40, fuel_transaction: pair_c)
        add_visit(Date.new(2026, 6, 5), discount: 500)

        july = Time.zone.local(2026, 7, 1).beginning_of_day..Time.zone.local(2026, 7, 31).end_of_day
        assert_equal 200.0, @customer.discount_total(range: july).to_f,
          "A counted by its transaction, B by its capture, C once, the June capture excluded"
        # If the anti-join used the UNWINDOWED visit scope, A's transaction would be
        # struck out by a capture that is not in the window and its ₹100 would be
        # lost by both sides, leaving ₹100.
        assert_equal 700.0, @customer.discount_total.to_f,
          "un-windowed: every fuelling once, June included"
      end

      # `visit_entries.entry_date` is a DATE and `transactions.created_at` a
      # TIMESTAMP, so the transaction bound has to be coerced. Uncoerced, a Date
      # end casts to 00:00 on the last day and drops everything rung up during it.
      test "a Date range covers the whole of its last day on the transaction side" do
        add_transaction(Date.new(2026, 7, 31), discount: 25) # 09:00 on the last day
        add_visit(Date.new(2026, 7, 31), discount: 15)

        assert_equal 40.0, @customer.discount_total(range: Date.new(2026, 7, 1)..Date.new(2026, 7, 31)).to_f,
          "both halves of the last day are inside the window"
      end

      test "rewards report redemption value, points and count" do
        add_visit(Date.new(2026, 7, 15))
        @customer.points_ledgers.create!(entry_type: :earn, points: 500)
        @customer.points_ledgers.create!(entry_type: :redeem, points: -200, cash_reward_amount: 100)
        @customer.points_ledgers.create!(entry_type: :redeem, points: -100, cash_reward_amount: 50)

        rewards = rewards_for
        assert_equal 150.0, rewards[:redemption_value]
        assert_equal 300, rewards[:redemption_points], "redeem rows store points negative; report the magnitude"
        assert_equal 2, rewards[:redemption_count]
        assert_equal 0, rewards[:gift_count], "a points redemption is not a physical gift"
      end

      # Unlike the E1 report (which buckets a gift on the period it was earned in),
      # the per-customer rollup is all-time: every grant the customer ever received.
      test "gift_count and gift_descriptions report granted physical campaign gifts" do
        grant_gift
        grant_gift(name: "Summer gift", description: "Cap",
                   granted_at: Time.zone.local(2026, 6, 12), period_start: Date.new(2026, 6, 1))

        rewards = rewards_for
        assert_equal 2, rewards[:gift_count]
        assert_equal ["Steel bottle", "Cap"], rewards[:gift_descriptions], "newest grant first"
      end

      test "gift_count ignores ungranted qualifications and non-gift reward kinds" do
        # Granted, but the campaign hands out points — not a physical gift.
        grant_gift(kind: :bonus_points, name: "Points push")
        # A gift the customer qualified for but was never handed.
        campaign = Campaign.create!(name: "Pending gift", reward_kind: :gift, gift_description: "Mug",
                                    min_purchase_litres: 20, period: :monthly, status: :active)
        campaign.campaign_qualifications.create!(customer: @customer, period_start: Date.new(2026, 7, 1),
                                                 period_end: Date.new(2026, 7, 31), reward_granted_at: nil)

        rewards = rewards_for
        assert_equal 0, rewards[:gift_count]
        assert_empty rewards[:gift_descriptions]
      end

      # With no ₹-per-point rate ever configured every redemption stored
      # cash_reward_amount = NULL, so redemption_value is a structural 0 the UIs
      # render as "—" rather than a ₹0.00 that reads as "we gave them nothing".
      test "reward_value_configured mirrors the cash-per-point setting" do
        @customer.points_ledgers.create!(entry_type: :redeem, points: -100)

        rewards = rewards_for
        assert_not rewards[:reward_value_configured], "no RewardSetting row exists, so no rate is configured"
        assert_equal 0.0, rewards[:redemption_value]
        assert_equal 100, rewards[:redemption_points], "the points are real even when the ₹ value is not"

        RewardSetting.create!(cash_value_per_point: 0.5)
        assert rewards_for[:reward_value_configured]
      end

      # The gift figures need `has_many :campaign_qualifications`, and the option it
      # is declared with is the part worth pinning. The ROW disappearing on delete
      # proves nothing — the FK is ON DELETE CASCADE, so it would vanish with no
      # association declared at all — but `customer_id` is NOT NULL, so switching
      # this to the `:nullify` its neighbours use would start raising on a live
      # admin delete. Assert the declaration, then confirm the path still runs.
      test "campaign_qualifications are declared dependent: :destroy, not :nullify" do
        reflection = Customer.reflect_on_association(:campaign_qualifications)
        assert_equal :destroy, reflection.options[:dependent],
          "campaign_qualifications.customer_id is NOT NULL — :nullify would raise on the delete path"

        campaign = grant_gift.campaign
        customer = Customer.create!(name: "Gift Only", phone_number: "9111100002")
        campaign.campaign_qualifications.create!(customer: customer, period_start: Date.new(2026, 7, 1),
                                                 period_end: Date.new(2026, 7, 31),
                                                 reward_granted_at: Time.zone.local(2026, 7, 12))

        assert_difference -> { CampaignQualification.count }, -1 do
          customer.destroy!
        end
      end
    end
  end
end
