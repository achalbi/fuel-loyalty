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

      # A rolling_days campaign — the DEFAULT Admin::CampaignsController#new ships
      # (`Campaign.new(period: :rolling_days, period_days: 30)`). Campaigns::Evaluator
      # stores `period_start` = Campaign#qualification_period.begin, which for a
      # rolling window is `rolling_anchor_date` (starts_at || created_at): the
      # campaign's own start date, NOT the start of the aggregation window. The
      # window is `(reference - 29)..reference` and `period_end` is that reference.
      def grant_rolling_gift(customer: @customer, anchor: Date.new(2026, 4, 1), swept_on: Date.new(2026, 7, 25),
                             granted_at: Time.zone.local(2026, 7, 25), name: "Rolling 30-day gift")
        campaign = Campaign.create!(name: name, reward_kind: :gift, gift_description: "Steel bottle",
                                    min_purchase_litres: 20, period: :rolling_days, period_days: 30,
                                    starts_at: anchor.beginning_of_day, status: :active)
        campaign.campaign_qualifications.create!(customer: customer, period_start: anchor, period_end: swept_on,
                                                 reward_granted_at: granted_at)
      end

      # Billing a rolling gift on period_start charges it to the campaign's start
      # date — April here — which is outside a July report altogether, so the gift
      # silently disappears from a report whose whole job is counting gifts handed over.
      test "gift_count bills a rolling-window gift to the sweep date, not the campaign anchor" do
        grant_rolling_gift

        july = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        row = july.rows.find { |r| r.key == @customer.id.to_s }

        assert_equal 1, row.gift_count, "the July sweep is inside the window the customer filled in"
        assert_equal 1, july.totals[:gift_count]
        assert_equal 2, row.visits, "it lands on the customer's real July row, not a materialised one"

        april = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-04-01", end_date: "2026-04-30")
        assert_equal 0, april.totals[:gift_count], "the anchor month is an idempotency key, not an earning period"
      end

      # The other half of the same bug: even when the anchor DOES fall inside the
      # report range it can land in a bucket the customer never filled in, and
      # `gifts_for` only credits customers a bucket already lists — so the gift is
      # dropped rather than misplaced.
      test "a rolling gift is not billed to an anchor period the customer never filled in" do
        grant_rolling_gift(anchor: Date.new(2026, 6, 15), swept_on: Date.new(2026, 7, 25))

        report = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-06-01", end_date: "2026-07-31")
        rows = report.rows.select { |r| r.key == @customer.id.to_s }

        assert_equal [["2026-07", 1]], rows.map { |r| [r.period, r.gift_count] },
          "the customer's only captures are in July — June is the campaign anchor, not an earning period"
        assert_equal 1, report.totals[:gift_count]
      end

      # The calendar branch is untouched: for weekly/monthly/fixed_window the stored
      # [period_start, period_end] IS the aggregation window, so period_start stays
      # the billing date even with the whole quarter in range to choose from.
      test "a calendar monthly gift is still billed to the month it was earned in" do
        grant_gift(granted_at: Time.zone.local(2026, 8, 3))

        report = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-06-01", end_date: "2026-08-31")
        billed = report.rows.select { |r| r.key == @customer.id.to_s && r.gift_count.positive? }

        assert_equal ["2026-07"], billed.map(&:period), "July is the window it was earned in, and the month they filled"
        assert_equal 1, report.totals[:gift_count]
      end

      # Campaigns::Evaluator aggregates `transactions`; this report is built from
      # `visit_entries`. A drive-in customer who qualified purely on transactions has
      # no bucket, so the gift used to be counted nowhere at all — the totals
      # under-reporting what the operator actually handed over. It now materialises
      # its own zero-capture row.
      test "a gift earned purely on transactions is still counted, on a materialised row" do
        drive_in = customers(:two)
        Transaction.create!(customer: drive_in, user: @staff, fuel_pump: @pump, vehicle: vehicles(:three),
                            fuel_amount: 4000, discount_amount: 0, payment_mode: "cash",
                            created_at: Time.zone.local(2026, 7, 14, 10))
        grant_gift(customer: drive_in, granted_at: Time.zone.local(2026, 8, 2), name: "Drive-in gift")

        report = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        row = report.rows.find { |r| r.key == drive_in.id.to_s }

        assert_not_nil row, "a customer with a granted gift but no visit entry must still appear"
        assert_equal "2026-07", row.period
        assert_equal drive_in.display_name, row.label
        assert_equal 1, row.gift_count
        assert_equal 0, row.visits
        assert_equal 0.0, row.litres
        assert_nil row.amount, "no capture behind the row, so there is no litres × price to derive"
        assert_equal 1, report.totals[:gift_count], "the gift is counted once, not lost"
      end

      # Deliberate exception, documented on materialize_gift_rows and in
      # docs/acefuels/15-spec-dashboard-reports.md: a qualification carries no fuel
      # type and no pump, so a filtered slice never invents a row for one.
      test "a fuel-filtered report does not materialise a gift row" do
        drive_in = customers(:two)
        grant_gift(customer: drive_in, name: "Drive-in gift")

        filtered = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01",
                                    end_date: "2026-07-31", fuel_type: "petrol")
        assert_nil filtered.rows.find { |r| r.key == drive_in.id.to_s }
        assert_equal 0, filtered.totals[:gift_count]

        unfiltered = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        assert_equal 1, unfiltered.totals[:gift_count], "the same gift is counted with no slice filter on"
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

      # ------------------------------------------------------------------
      # Free-text lookups (transporter / driver / driver mobile / vehicle).
      # ------------------------------------------------------------------

      test "transporter lookup matches any part of the name, case-insensitively" do
        report = LedgerReport.new(dimension: "transporter", grain: "month", start_date: "2026-06-01",
                                  end_date: "2026-07-31", transporter: "roadways")

        assert_equal ["NL Roadways"], report.rows.map(&:key), "the June \"Other\" transporter is filtered out"
        assert_equal 100.0, report.totals[:litres]
      end

      test "driver lookup matches part of the driver name" do
        report = LedgerReport.new(dimension: "driver", grain: "month", start_date: "2026-07-01",
                                  end_date: "2026-07-31", driver_name: "sin")

        assert_equal ["Singh"], report.rows.map(&:key)
        assert_equal 60.0, report.totals[:litres]
      end

      # VisitEntry stores phone numbers digits-only, so a mobile typed the way an
      # operator reads it off a slip has to be normalized before it can match.
      test "driver mobile lookup normalizes the typed number and matches partials" do
        VisitEntry.create!(user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 9),
                           vehicle_number: "KA01AA0004", litres: 12, discount_amount: 0, fuel_type_code: "petrol",
                           transport_name: "NL Roadways", driver_name: "Naik", driver_phone_number: "9876543210")

        %w[9876543210].each do |exact|
          assert_equal ["Naik"], driver_rows(driver_phone: exact), "an exact number matches"
        end
        assert_equal ["Naik"], driver_rows(driver_phone: "98765 43210"), "spaces are normalized away"
        assert_equal ["Naik"], driver_rows(driver_phone: "+91 98765-43210"), "a dialling prefix and dashes still match"
        assert_equal ["Naik"], driver_rows(driver_phone: "098765 43210"), "a trunk prefix is stripped too"
        assert_equal ["Naik"], driver_rows(driver_phone: "43210"), "a partial number matches"
        assert_empty driver_rows(driver_phone: "9000000000")
      end

      # Same story for plates: stored A-Z0-9 only, so the spaced form on the vehicle
      # would match nothing without normalizing the query the same way.
      test "vehicle lookup normalizes the typed plate and matches partials" do
        assert_equal ["KA01AA0001"], vehicle_rows(vehicle_number: "ka 01 aa 0001")
        assert_equal ["KA01AA0001"], vehicle_rows(vehicle_number: "KA-01-AA-0001")
        assert_equal %w[KA01AA0001 KA01AA0002], vehicle_rows(vehicle_number: "aa000").sort.first(2)
        assert_empty vehicle_rows(vehicle_number: "MH12")
      end

      # AND, not OR: the operator is narrowing one report ("Rao driving for NL
      # Roadways"), not searching for anything that matches either term.
      test "the lookups combine — a row has to match every one supplied" do
        both = LedgerReport.new(dimension: "vehicle", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31",
                                transporter: "NL Roadways", driver_name: "Rao")
        assert_equal ["KA01AA0001"], both.rows.map(&:key), "only Rao's NL Roadways visit"

        none = LedgerReport.new(dimension: "vehicle", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31",
                                transporter: "Other", driver_name: "Rao")
        assert_empty none.rows, "the June transporter never drove with Rao"
      end

      test "blank and whitespace-only lookups are ignored rather than matching nothing" do
        report = LedgerReport.new(dimension: "vehicle", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31",
                                  transporter: "  ", driver_name: "", driver_phone: nil, vehicle_number: "   ")

        assert_equal 2, report.rows.size, "an empty box is not a filter"
        assert_not report.filtered?
      end

      # A transporter really can be called "50% Logistics", and an unescaped % in a
      # LIKE pattern would silently turn the lookup into a match-anything wildcard.
      test "LIKE wildcards typed into a lookup are matched literally" do
        VisitEntry.create!(user: @staff, fuel_pump: @pump, entry_date: Date.new(2026, 7, 11),
                           vehicle_number: "KA01AA0005", litres: 5, discount_amount: 0, fuel_type_code: "petrol",
                           transport_name: "50% Logistics", driver_name: "Bose")

        report = LedgerReport.new(dimension: "transporter", grain: "month", start_date: "2026-07-01",
                                  end_date: "2026-07-31", transporter: "50%")
        assert_equal ["50% Logistics"], report.rows.map(&:key), "the % is literal text, not a wildcard"
      end

      # The lookups echo back NORMALIZED, so the form and the JSON show what was
      # actually queried rather than what the operator happened to type.
      test "the applied lookups are exposed in their normalized form" do
        report = LedgerReport.new(dimension: "vehicle", grain: "month", vehicle_number: "ka 01 aa 0001",
                                  driver_phone: "+91 98765-43210", transporter: " NL Roadways ")

        assert_equal "KA01AA0001", report.vehicle_number
        assert_equal "9876543210", report.driver_phone, "the +91 dialling prefix is dropped, not searched for"
        assert_equal "NL Roadways", report.transporter
        assert_nil report.driver_name
        assert report.filtered?
      end

      # Same rule as the fuel/pump slice, for the same reason: a qualification
      # carries no transporter, driver or vehicle, so a lookup-narrowed report
      # cannot claim a gift belongs inside it.
      test "a lookup-filtered report does not materialise a gift row" do
        drive_in = customers(:two)
        grant_gift(customer: drive_in, name: "Drive-in gift")

        filtered = LedgerReport.new(dimension: "customer", grain: "month", start_date: "2026-07-01",
                                    end_date: "2026-07-31", transporter: "NL Roadways")
        assert_nil filtered.rows.find { |r| r.key == drive_in.id.to_s }
        assert_equal 0, filtered.totals[:gift_count]
      end

      test "filtered? reports whether anything narrows the report beyond its dates" do
        plain = LedgerReport.new(dimension: "vehicle", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31")
        assert_not plain.filtered?

        assert LedgerReport.new(dimension: "vehicle", grain: "month", driver_name: "Rao").filtered?
        assert LedgerReport.new(dimension: "vehicle", grain: "month", fuel_type: "petrol").filtered?
        assert LedgerReport.new(dimension: "vehicle", grain: "month", customer_id: @customer.id).filtered?
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

      private

      def driver_rows(**filters)
        LedgerReport.new(dimension: "driver", grain: "month", start_date: "2026-07-01",
                         end_date: "2026-07-31", **filters).rows.map(&:key)
      end

      def vehicle_rows(**filters)
        LedgerReport.new(dimension: "vehicle", grain: "month", start_date: "2026-07-01",
                         end_date: "2026-07-31", **filters).rows.map(&:key)
      end
    end
  end
end
