require "test_helper"

module Admin
  class ReportsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @staff = users(:two)
      @customer = customers(:one)
      Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 110, selling_price: 100)
      VisitEntry.create!(user: @staff, fuel_pump: fuel_pumps(:one), entry_date: Date.new(2026, 7, 5),
                         vehicle_number: "KA01AA0001", litres: 40, discount_amount: 100, fuel_type_code: "petrol",
                         transport_name: "NL Roadways", driver_name: "Rao")
    end

    test "renders the report table for an admin" do
      sign_in @admin
      get admin_reports_path, params: { dimension: "transporter", grain: "month", start_date: "2026-07-01", end_date: "2026-07-31" }
      assert_response :success
      assert_select "td", text: "NL Roadways"
    end

    test "csv download returns an attachment" do
      sign_in @admin
      get admin_reports_path(format: :csv), params: { dimension: "vehicle", grain: "day", start_date: "2026-07-05", end_date: "2026-07-05" }
      assert_response :success
      assert_match %r{text/csv}, response.media_type
      assert_includes response.body, "KA01AA0001"
    end

    test "csv header names every column, reward ₹ and gifts apart" do
      sign_in @admin
      get admin_reports_path(format: :csv), params: { dimension: "vehicle", grain: "day", start_date: "2026-07-05", end_date: "2026-07-05" }
      assert_response :success
      assert_includes csv_body, "Key,Label,Period,Litres,Amount ₹,Discount ₹,Reward ₹,Gifts,Visits"
      assert_includes csv_body, "TOTAL"
    end

    test "customer report shows the physical campaign gifts granted" do
      customer_visit
      grant_gift
      sign_in @admin
      get admin_reports_path, params: { dimension: "customer", grain: "month", start_date: "2026-07-01",
                                        end_date: "2026-07-31", customer_id: @customer.id }
      assert_response :success

      assert_select "tbody tr", 1, "customer_id narrows the report to that one customer"
      assert_equal "1", row_cells[6], "the Gifts column counts the granted campaign gift"
      assert_select "th", text: "Gifts"
      assert_select "th", text: "Reward ₹"
    end

    test "reward ₹ renders — when no cash value per point is configured" do
      customer_visit
      sign_in @admin
      get admin_reports_path, params: { dimension: "customer", grain: "month", start_date: "2026-07-01",
                                        end_date: "2026-07-31", customer_id: @customer.id }
      assert_response :success
      # NULL cash_reward_amount on every redemption — a "₹0.00" here would read as
      # a real zero, so the column blanks and the page says why.
      assert_equal "—", row_cells[5]
      assert_select "span.text-warning-emphasis", /no cash value per point is configured/
    end

    test "reward ₹ renders a real zero once a cash value per point exists" do
      customer_visit
      RewardSetting.create!(cash_value_per_point: 0.5)
      sign_in @admin
      get admin_reports_path, params: { dimension: "customer", grain: "month", start_date: "2026-07-01",
                                        end_date: "2026-07-31", customer_id: @customer.id }
      assert_response :success
      assert_equal "₹0.00", row_cells[5]
      assert_select "span.text-warning-emphasis", false
    end

    test "the filter form offers the four free-text lookups and a date range" do
      sign_in @admin
      get admin_reports_path
      assert_response :success

      assert_select "input[name=?]", "transporter"
      assert_select "input[name=?]", "driver_name"
      assert_select "input[name=?]", "driver_phone"
      assert_select "input[name=?]", "vehicle_number"
      assert_select "input[type=date][name=?]", "start_date"
      assert_select "input[type=date][name=?]", "end_date"
    end

    test "a lookup narrows the table and echoes the normalized value back into the form" do
      customer_visit # Fleet Co / Iyer / KA01BB0002
      sign_in @admin
      get admin_reports_path, params: { dimension: "transporter", grain: "month", start_date: "2026-07-01",
                                        end_date: "2026-07-31", transporter: "fleet" }
      assert_response :success

      assert_select "tbody tr", 1
      assert_select "td", text: "Fleet Co"
      assert_select "input[name=transporter][value=?]", "fleet"
      assert_select "a", text: "Clear", count: 1
    end

    test "a vehicle typed with spaces still matches the stored plate" do
      sign_in @admin
      get admin_reports_path, params: { dimension: "vehicle", grain: "month", start_date: "2026-07-01",
                                        end_date: "2026-07-31", vehicle_number: "ka 01 aa 0001" }
      assert_response :success

      assert_select "td", text: "KA01AA0001"
      # The form echoes the NORMALIZED plate — what the query actually ran with.
      assert_select "input[name=vehicle_number][value=?]", "KA01AA0001"
    end

    test "an unmatched lookup says the filters are the reason, not the date range" do
      sign_in @admin
      get admin_reports_path, params: { dimension: "transporter", grain: "month", start_date: "2026-07-01",
                                        end_date: "2026-07-31", driver_name: "nobody" }
      assert_response :success
      assert_select "tbody tr", 0
      assert_select "p", /No captures match these filters/
    end

    test "no Clear link until something is actually filtering" do
      sign_in @admin
      get admin_reports_path, params: { dimension: "vehicle", grain: "month" }
      assert_response :success
      assert_select "a", text: "Clear", count: 0
    end

    test "the CSV export honours the lookups" do
      customer_visit
      sign_in @admin
      get admin_reports_path(format: :csv), params: { dimension: "transporter", grain: "month",
                                                      start_date: "2026-07-01", end_date: "2026-07-31",
                                                      driver_name: "iyer" }
      assert_response :success
      assert_includes csv_body, "Fleet Co"
      assert_not_includes csv_body, "NL Roadways", "the export is the filtered report, not the whole ledger"
    end

    test "non-admin is bounced" do
      sign_in @staff
      get admin_reports_path
      assert_response :redirect
    end

    private

    # The CSV ships with a UTF-8 BOM so Excel renders ₹; re-tag it before matching.
    def csv_body
      response.body.dup.force_encoding("UTF-8")
    end

    # Body cells of the first data row, in column order:
    # label, period, litres, amount, discount, reward ₹, gifts, visits.
    def row_cells
      css_select("tbody tr:first-child td").map { |td| td.text.strip }
    end

    def customer_visit
      VisitEntry.create!(user: @staff, fuel_pump: fuel_pumps(:one), customer: @customer, entry_date: Date.new(2026, 7, 6),
                         vehicle_number: "KA01BB0002", litres: 25, discount_amount: 50, fuel_type_code: "petrol",
                         transport_name: "Fleet Co", driver_name: "Iyer")
    end

    # F1 gift campaign: the grant only stamps reward_granted_at — no ledger, no ₹.
    def grant_gift
      campaign = Campaign.create!(name: "Monsoon gift", reward_kind: :gift, gift_description: "Steel bottle",
                                  min_purchase_litres: 20, period: :monthly, status: :active)
      campaign.campaign_qualifications.create!(customer: @customer, period_start: Date.new(2026, 7, 1),
                                               period_end: Date.new(2026, 7, 31),
                                               reward_granted_at: Time.zone.local(2026, 7, 12))
    end
  end
end
