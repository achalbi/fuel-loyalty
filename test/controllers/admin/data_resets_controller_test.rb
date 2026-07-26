require "test_helper"

module Admin
  class DataResetsControllerTest < ActionDispatch::IntegrationTest
    test "staff cannot reach the data reset page" do
      sign_in users(:two)

      get admin_data_reset_path

      assert_redirected_to root_path
    end

    test "admin sees the picker with in-scope row counts" do
      sign_in users(:one)

      get admin_data_reset_path

      assert_response :success
      assert_select "h1", text: "Reset Transaction Data"
      assert_select "input[type=checkbox][name='entities[]'][value=transactions][checked=checked]"
      assert_select "input[type=checkbox][name='entities[]'][value=daily_settlements]"
      assert_select "input[type=checkbox][name='entities[]']", count: ::Admin::DataReset::ENTITIES.size
      assert_select ".form-check", text: /Fuel transactions.*#{Transaction.count} rows in scope/m
      assert_select "form[data-confirm-modal=true] input[type=hidden][name=mode][value=execute]"
      assert_select "form[data-confirm-modal=true] button[type=submit]", text: /Reset data/
    end

    test "the reset form is armed only with what was previewed" do
      sign_in users(:one)

      post admin_data_reset_path, params: { mode: "preview", entities: %w[visit_entries], customer_phone: "" }

      assert_response :success
      assert_select "form[data-confirm-modal=true] input[type=hidden][name='entities[]'][value=visit_entries]"
      assert_select "form[data-confirm-modal=true] input[type=hidden][name='entities[]'][value=transactions]", count: 0
    end

    test "the reset button is disabled until something is selected" do
      sign_in users(:one)

      post admin_data_reset_path, params: { mode: "preview" }

      assert_response :success
      assert_select "form[data-confirm-modal=true] button[type=submit][disabled]"
    end

    test "preview recalculates counts without deleting anything" do
      sign_in users(:one)

      assert_no_difference ["Transaction.count", "PointsLedger.count"] do
        post admin_data_reset_path, params: {
          mode: "preview", entities: %w[transactions], confirmation: "RESET"
        }
      end

      assert_response :success
      assert_select ".alert-info", text: /#{PointsLedger.where.not(transaction_id: nil).count} points ledger/
    end

    test "reset is refused without the confirmation phrase" do
      sign_in users(:one)

      assert_no_difference "Transaction.count" do
        post admin_data_reset_path, params: { mode: "execute", entities: %w[transactions], confirmation: "reset now" }
      end

      assert_response :unprocessable_entity
      assert_select ".alert-danger", text: /Type RESET in the confirmation box/
    end

    test "reset is refused when nothing is selected" do
      sign_in users(:one)

      assert_no_difference "Transaction.count" do
        post admin_data_reset_path, params: { mode: "execute", confirmation: "RESET" }
      end

      assert_response :unprocessable_entity
      assert_select ".alert-danger", text: /Select at least one type of data/
    end

    test "resetting transactions also clears the points ledger rows hanging off them" do
      sign_in users(:one)
      standalone = PointsLedger.create!(customer: customers(:one), points: -3, entry_type: :redeem)

      post admin_data_reset_path, params: {
        mode: "execute", entities: %w[transactions], confirmation: "RESET"
      }

      assert_redirected_to admin_data_reset_path
      assert_equal 0, Transaction.count
      assert_equal [standalone.id], PointsLedger.pluck(:id)
      assert_match(/Reset complete/, flash[:notice])
    end

    test "selecting the ledger clears manual adjustments too and re-arms milestones" do
      sign_in users(:one)
      PointsLedger.create!(customer: customers(:one), points: -3, entry_type: :redeem)
      customers(:one).update_column(:last_milestone_points, 500)

      post admin_data_reset_path, params: {
        mode: "execute", entities: %w[transactions points_ledgers], confirmation: "RESET"
      }

      assert_redirected_to admin_data_reset_path
      assert_equal 0, Transaction.count
      assert_equal 0, PointsLedger.count
      assert_equal 0, customers(:one).reload.last_milestone_points
    end

    test "a customer phone number narrows the reset to that customer" do
      sign_in users(:one)

      post admin_data_reset_path, params: {
        mode: "execute", entities: %w[transactions points_ledgers],
        customer_phone: customers(:one).phone_number, confirmation: "RESET"
      }

      assert_redirected_to admin_data_reset_path
      assert_equal 0, customers(:one).transactions.count
      assert_equal 1, customers(:two).transactions.count
      assert_equal 0, customers(:one).points_ledgers.count
      assert_equal 1, customers(:two).points_ledgers.count
    end

    test "an unknown phone number is reported and deletes nothing" do
      sign_in users(:one)

      assert_no_difference "Transaction.count" do
        post admin_data_reset_path, params: {
          mode: "execute", entities: %w[transactions], customer_phone: "9999999999", confirmation: "RESET"
        }
      end

      assert_response :unprocessable_entity
      assert_select ".alert-danger", text: /No customer found with phone number 9999999999/
    end

    test "a date range limits the reset to transactions inside it" do
      sign_in users(:one)
      transactions(:one).update_column(:created_at, 10.days.ago)
      transactions(:two).update_column(:created_at, Time.current)

      post admin_data_reset_path, params: {
        mode: "execute", entities: %w[transactions],
        start_date: 12.days.ago.to_date.iso8601, end_date: 5.days.ago.to_date.iso8601, confirmation: "RESET"
      }

      assert_redirected_to admin_data_reset_path
      assert_equal [transactions(:two).id], Transaction.pluck(:id)
    end

    test "settlements are skipped while a customer filter is applied" do
      sign_in users(:one)
      settlement = DailySettlement.create!(
        fuel_pump: fuel_pumps(:one), recorded_by: users(:two), business_date: Time.zone.today
      )

      post admin_data_reset_path, params: {
        mode: "execute", entities: %w[daily_settlements], customer_phone: customers(:one).phone_number,
        confirmation: "RESET"
      }

      assert_redirected_to admin_data_reset_path
      assert DailySettlement.exists?(settlement.id)
      assert_match(/Nothing matched those filters/, flash[:notice])
    end

    test "settlements and their child lines go when selected without a customer filter" do
      sign_in users(:one)
      settlement = DailySettlement.create!(
        fuel_pump: fuel_pumps(:one), recorded_by: users(:two), business_date: Time.zone.today
      )
      settlement.cash_denominations.create!(denomination: 500, quantity: 2)

      post admin_data_reset_path, params: {
        mode: "execute", entities: %w[daily_settlements], confirmation: "RESET"
      }

      assert_redirected_to admin_data_reset_path
      assert_not DailySettlement.exists?(settlement.id)
      assert_equal 0, SettlementCashDenomination.where(daily_settlement_id: settlement.id).count
    end
  end
end
