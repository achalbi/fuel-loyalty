require "test_helper"

module Admin
  module Reports
    class LedgerReportTest < ActiveSupport::TestCase
      setup do
        @pump = fuel_pumps(:one)
        @staff = users(:two)
        @customer = customers(:one)
        Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 100)

        # Two same-transporter visits in July, one in a different month.
        VisitEntry.create!(user: @staff, fuel_pump: @pump, customer: @customer, entry_date: Date.new(2026, 7, 5),
                           vehicle_number: "KA01AA0001", litres: 40, discount_amount: 100, fuel_type_code: "petrol",
                           transport_name: "NL Roadways", driver_name: "Rao")
        VisitEntry.create!(user: @staff, fuel_pump: @pump, customer: @customer, entry_date: Date.new(2026, 7, 20),
                           vehicle_number: "KA01AA0002", litres: 60, discount_amount: 50, fuel_type_code: "petrol",
                           transport_name: "NL Roadways", driver_name: "Singh")
        VisitEntry.create!(user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 6, 10),
                           vehicle_number: "KA01AA0003", litres: 10, discount_amount: 0, fuel_type_code: "petrol",
                           transport_name: "Other")

        # A reward redemption in July → the customer's "Reward ₹" (`gifts`).
        @customer.points_ledgers.create!(entry_type: :redeem, points: -100, cash_reward_amount: 75, created_at: Time.zone.local(2026, 7, 10))
      end

      # F1 gift campaign: granting stamps reward_granted_at and writes no ledger row.
      def grant_gift(customer: @customer, granted_at: Time.zone.local(2026, 7, 12), kind: :gift, name: "Monsoon gift")
        campaign = Campaign.create!(name: name, reward_kind: kind, gift_description: ("Steel bottle" if kind == :gift),
                                    bonus_points: (50 if kind == :bonus_points),
                                    min_purchase_litres: 20, period: :monthly, status: :active)
        campaign.campaign_qualifications.create!(customer: customer, period_start: Date.new(2026, 7, 1),
                                                 period_end: Date.new(2026, 7, 31), reward_granted_at: granted_at)
      end

      test "aggregates by transporter/month with derived amount, discount and gifts" do
        report = LedgerReport.new(dimension: "transporter", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        nl = report.rows.find { |r| r.key == "NL Roadways" }

        assert_equal "2026-07", nl.period
        assert_equal 100.0, nl.litres          # 40 + 60
        assert_equal 10000.0, nl.amount        # (40+60) × ₹100
        assert_equal 150.0, nl.discount        # 100 + 50
        assert_equal 75.0, nl.gifts            # the July redemption
        assert_equal 2, nl.visits

        assert_equal 100.0, report.totals[:litres]
        assert_nil report.rows.find { |r| r.key == "Other" }, "June visit excluded from July range"
      end

      # Pins the divergence documented on LedgerReport#scoped_entries. Discount ₹
      # here is `SUM(visit_entries.discount_amount)` flat, so a counter sale with no
      # B2 capture behind it is invisible — while `Customer#discount_total`, the
      # figure on the admin customer card, does count it. Deliberate: a standalone
      # transaction carries no driver, transporter or entry_date to attribute, so
      # folding it in would invent rows on three of the four dimensions.
      test "the discount column reports captures only, unlike the per-customer rollup" do
        Transaction.create!(customer: @customer, user: @staff, fuel_pump: @pump, vehicle: vehicles(:one),
                            fuel_amount: 500, discount_amount: 90, payment_mode: "cash",
                            created_at: Time.zone.local(2026, 7, 18, 9))

        report = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        row = report.rows.find { |r| r.key == @customer.id.to_s }
        assert_equal 150.0, row.discount, "the two July captures only — the counter sale has no visit entry"

        july = Time.zone.local(2026, 7, 1).beginning_of_day..Time.zone.local(2026, 7, 31).end_of_day
        assert_equal 240.0, @customer.discount_total(range: july).to_f,
          "the customer card adds the ₹90 this report has no dimension to hang on"
      end

      test "gift_count counts granted physical campaign gifts on the customer dimension" do
        grant_gift
        report = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        row = report.rows.find { |r| r.key == @customer.id.to_s }

        assert_equal 1, row.gift_count
        assert_equal 1, report.totals[:gift_count]
        assert_equal 75.0, row.gifts, "the ₹ redemption column stays independent of the gift tally"
      end

      # Campaigns::Runner sweeps after the window closes, so a July gift is
      # normally stamped in August. The report must still bill it to July — the
      # month the customer earned it, and the month they actually filled.
      test "gift_count bills a gift to the period earned, not the period swept" do
        grant_gift(granted_at: Time.zone.local(2026, 8, 3))
        july = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")

        assert_equal 1, july.rows.find { |r| r.key == @customer.id.to_s }.gift_count,
          "a gift earned in July belongs to July even though the runner stamped it in August"

        august = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-08-01", end_date: "2026-08-31")
        assert_equal 0, august.totals[:gift_count], "the sweep month must not claim the gift"
      end

      test "gift_count ignores ungranted qualifications and non-gift reward kinds" do
        # Granted, but the campaign hands out points — not a physical gift.
        grant_gift(kind: :bonus_points, name: "Points push")
        # A gift campaign the customer qualified for but was never handed.
        campaign = Campaign.create!(name: "Pending gift", reward_kind: :gift, gift_description: "Cap",
                                    min_purchase_litres: 20, period: :monthly, status: :active)
        campaign.campaign_qualifications.create!(customer: @customer, period_start: Date.new(2026, 7, 1),
                                                 period_end: Date.new(2026, 7, 31), reward_granted_at: nil)

        report = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        assert_equal 0, report.rows.find { |r| r.key == @customer.id.to_s }.gift_count
      end

      test "gift_count is 0 outside the customer dimension — a qualification has no vehicle/driver" do
        grant_gift
        %w[vehicle transporter driver].each do |dimension|
          report = LedgerReport.new(dimension: dimension, grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
          assert_equal 0, report.totals[:gift_count], "#{dimension} cannot attribute a per-customer gift"
        end
      end

      test "customer_id narrows the report to a single customer" do
        VisitEntry.create!(user: @staff, fuel_pump: @pump, customer: customers(:two), entry_date: Date.new(2026, 7, 8),
                           vehicle_number: "KA01AA0009", litres: 15, discount_amount: 5, fuel_type_code: "petrol",
                           transport_name: "NL Roadways", driver_name: "Rao")

        all = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        assert_equal 2, all.rows.size

        scoped = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31",
                                  customer_id: @customer.id)
        assert_equal [@customer.id.to_s], scoped.rows.map(&:key)
        assert_equal 100.0, scoped.totals[:litres], "only the filtered customer's litres count"
      end

      test "reward_value_configured? follows the cash-per-point setting" do
        report = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        assert_not report.reward_value_configured?, "no RewardSetting row exists, so no rate is configured"

        RewardSetting.create!(cash_value_per_point: 0.5)
        assert LedgerReport.new(dimension: "customer", grain: "month").reward_value_configured?
      end

      test "driver dimension splits the two visits" do
        report = LedgerReport.new(dimension: "driver", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        assert_equal %w[Rao Singh], report.rows.map(&:key).sort
      end

      test "amount is blank when no catalog price exists for the fuel" do
        Product.where(category: "fuel").update_all(active: false)
        report = LedgerReport.new(dimension: "vehicle", grain: "day", start_date: "2026-07-05", end_date: "2026-07-05")
        assert_nil report.rows.first.amount
        assert_equal 40.0, report.rows.first.litres
      end

      test "CSV export has a header, rows and a total line" do
        report = LedgerReport.new(dimension: "transporter", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        csv = report.to_csv
        assert_includes csv, "Key,Label,Period,Litres,Amount ₹,Discount ₹,Reward ₹,Gifts,Visits"
        assert_includes csv, "NL Roadways"
        assert_includes csv, "TOTAL"
      end

      test "CSV renders — for the reward column when no cash-per-point rate is configured" do
        # The June row has no customer, so no redemption value — and with no rate
        # configured that ₹0 is structural, not real.
        csv = LedgerReport.new(dimension: "transporter", grain: "month", start_date: "2026-06-01", end_date: "2026-06-30").to_csv
        assert_includes csv, "Other,2026-06,10.0,1000.0,0.0,—,0,1"

        RewardSetting.create!(cash_value_per_point: 0.5)
        configured = LedgerReport.new(dimension: "transporter", grain: "month", start_date: "2026-06-01", end_date: "2026-06-30").to_csv
        assert_includes configured, "Other,2026-06,10.0,1000.0,0.0,0.0,0,1", "a configured rate reports a real ₹0"
      end
    end
  end
end
