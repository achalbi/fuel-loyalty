require "test_helper"

module Staff
  class VisitEntriesControllerTest < ActionDispatch::IntegrationTest
    test "staff can open the capture form" do
      sign_in users(:two)
      get new_staff_visit_entry_path
      assert_response :success
      assert_select "form[action=?]", staff_visit_entries_path
      assert_select "input[name='visit_entry[litres]']"
    end

    test "staff can record a visit and it links the customer from the plate" do
      sign_in users(:two)

      assert_difference -> { VisitEntry.count }, 1 do
        post staff_visit_entries_path, params: {
          visit_entry: {
            vehicle_number: vehicles(:one).vehicle_number, litres: "55.5", discount_amount: "20",
            fuel_pump_id: fuel_pumps(:one).id, driver_name: "Ravi", driver_phone_number: "9000011122",
            fleet_otp: "1",
          },
        }
      end

      entry = VisitEntry.order(:id).last
      assert_redirected_to staff_visit_entries_path(date: entry.entry_date, fuel_pump_id: entry.fuel_pump_id)
      assert_equal customers(:one).id, entry.customer_id
      assert entry.fleet_otp
    end

    test "invalid capture re-renders the form with errors" do
      sign_in users(:two)
      assert_no_difference -> { VisitEntry.count } do
        post staff_visit_entries_path, params: {
          visit_entry: { vehicle_number: "", litres: "0", fuel_pump_id: fuel_pumps(:one).id },
        }
      end
      assert_response :unprocessable_entity
      assert_select ".alert.alert-danger"
    end

    test "index lists captures for the pump and day" do
      sign_in users(:two)
      VisitEntry.create!(user: users(:two), fuel_pump: fuel_pumps(:one), entry_date: Date.current,
                         vehicle_number: "TN01AA1111", litres: 12)

      get staff_visit_entries_path(fuel_pump_id: fuel_pumps(:one).id, date: Date.current.iso8601)
      assert_response :success
      assert_select "td", text: "TN01AA1111"
    end
  end
end
