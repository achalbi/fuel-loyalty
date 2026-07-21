require "test_helper"

module Api
  module V1
    module Staff
      class VisitEntriesControllerTest < ActionDispatch::IntegrationTest
        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "captures a visit and links the customer + upserts a contact from the plate" do
          customer = customers(:one)
          vehicle = vehicles(:one)

          assert_difference -> { VisitEntry.count }, 1 do
            post api_v1_staff_visit_entries_path, params: {
              visit_entry: {
                vehicle_number: vehicle.vehicle_number, litres: "136.5", discount_amount: "250",
                fleet_otp: "true", driver_name: "Manoj", driver_phone_number: "9800011111"
              },
            }, headers: auth_headers(users(:two))
          end

          assert_response :created
          body = response.parsed_body["visit_entry"]
          assert_equal vehicle.vehicle_number, body["vehicle_number"]
          assert_equal customer.id, body["customer_id"]
          assert_equal vehicle.id, body["vehicle_id"]
          assert_equal true, body["fleet_otp"]
          assert_in_delta 136.5, body["litres"], 0.001

          # Business rule 2: driver contact upserted + set as primary (first contact).
          contact = customer.customer_contacts.find_by(role: "driver", phone_number: "9800011111")
          assert_not_nil contact
          assert_equal "Manoj", contact.name
          assert_equal contact.id, customer.reload.primary_contact_id
        end

        test "captures an anonymous visit for an unregistered plate" do
          assert_difference -> { VisitEntry.count }, 1 do
            post api_v1_staff_visit_entries_path, params: {
              visit_entry: { vehicle_number: "TN09XY9999", litres: "40", fuel_pump_id: fuel_pumps(:one).id },
            }, headers: auth_headers(users(:two))
          end

          assert_response :created
          assert_nil response.parsed_body["visit_entry"]["customer_id"]
        end

        test "a visit whose driver phone equals the owner phone records one contact, not a 500" do
          vehicle = vehicles(:one)

          assert_difference -> { VisitEntry.count }, 1 do
            post api_v1_staff_visit_entries_path, params: {
              visit_entry: {
                vehicle_number: vehicle.vehicle_number, litres: "50", fuel_pump_id: fuel_pumps(:one).id,
                driver_name: "Ravi", driver_phone_number: "9800022222",
                owner_name: "Ravi (owner)", owner_phone_number: "9800022222"
              },
            }, headers: auth_headers(users(:two))
          end

          assert_response :created
          # The role-agnostic [customer_id, phone_number] index means one row per phone.
          contacts = customers(:one).customer_contacts.where(phone_number: "9800022222")
          assert_equal 1, contacts.count
          assert_equal "driver", contacts.first.role, "the earliest role wins"
        end

        test "rejects a zero-litre capture" do
          assert_no_difference -> { VisitEntry.count } do
            post api_v1_staff_visit_entries_path, params: {
              visit_entry: { vehicle_number: "TN09XY9998", litres: "0", fuel_pump_id: fuel_pumps(:one).id },
            }, headers: auth_headers(users(:two))
          end

          assert_response :unprocessable_entity
        end

        test "index lists a pump's captures for a day" do
          VisitEntry.create!(user: users(:two), fuel_pump: fuel_pumps(:one), entry_date: Date.current,
                             vehicle_number: "TN01AA0001", litres: 10)

          get api_v1_staff_visit_entries_path(fuel_pump_id: fuel_pumps(:one).id, date: Date.current.iso8601),
              headers: auth_headers(users(:two))

          assert_response :ok
          body = response.parsed_body
          assert_equal fuel_pumps(:one).id, body["fuel_pump_id"]
          assert_operator body["visit_entries"].size, :>=, 1
        end

        test "create_transaction links a loyalty transaction and awards points" do
          RewardSetting.current.update!(nozzle_feature_enabled: false)
          # Litres -> ₹ derivation needs an active fuel price for the plate's fuel type.
          Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", mrp: 100, selling_price: 100, active: true)
          vehicle = vehicles(:one)

          assert_difference -> { Transaction.count }, 1 do
            post api_v1_staff_visit_entries_path, params: {
              visit_entry: {
                vehicle_number: vehicle.vehicle_number, vehicle_id: vehicle.id, litres: "20",
                fuel_pump_id: fuel_pumps(:one).id,
              },
              create_transaction: true,
            }, headers: auth_headers(users(:two))
          end

          assert_response :created
          assert_not_nil response.parsed_body["transaction_id"]
          entry = VisitEntry.find(response.parsed_body["visit_entry"]["id"])
          assert_equal response.parsed_body["transaction_id"], entry.transaction_id
        end

        test "requires staff or admin" do
          post api_v1_staff_visit_entries_path, params: { visit_entry: { vehicle_number: "TN01AA0003", litres: "5" } }
          assert_response :unauthorized
        end
      end
    end
  end
end
