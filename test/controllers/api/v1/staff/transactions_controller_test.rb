require "test_helper"

module Api
  module V1
    module Staff
      # Item 2 — the counter endpoint records the loyalty transaction and the
      # visit entry from one post.
      class TransactionsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @staff = users(:two)
          @customer = customers(:one)
          @vehicle = vehicles(:one)
          @nozzle = fuel_pump_nozzles(:one)
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        def price_the_fuel!
          Product.create!(name: "MS", category: "fuel", fuel_type_code: @vehicle.fuel_type,
                          pack_unit: "litre", mrp: 110, selling_price: 100)
        end

        test "one post records both the transaction and the visit entry" do
          price_the_fuel!

          assert_difference -> { Transaction.count }, 1 do
            assert_difference -> { VisitEntry.count }, 1 do
              post api_v1_staff_transactions_path, params: {
                transaction: {
                  lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
                  litres: "20", discount_amount: "100", payment_mode: "credit",
                  fuel_pump_nozzle_id: @nozzle.id, transport_name: "NL Roadways", fleet_otp: "true",
                  driver_name: "Manoj", driver_phone_number: "9800011122"
                },
              }, headers: auth_headers(@staff)
            end
          end

          assert_response :created
          body = response.parsed_body
          assert_equal Transaction.order(:id).last.id, body.dig("transaction", "id")
          assert_equal "credit", body.dig("transaction", "payment_mode")

          visit = body["visit_entry"]
          assert_equal @vehicle.vehicle_number, visit["vehicle_number"]
          assert_equal "NL Roadways", visit["transport_name"]
          assert_equal true, visit["fleet_otp"]
          assert_equal body.dig("transaction", "id"), visit["transaction_id"]
          assert_in_delta 20.0, visit["litres"], 0.001

          # The captured driver joins the customer's contact roster.
          assert_not_nil @customer.customer_contacts.find_by(phone_number: "9800011122")
        end

        test "a typed rupee amount is converted to litres for the visit" do
          price_the_fuel!

          post api_v1_staff_transactions_path, params: {
            transaction: {
              lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
              fuel_amount: "750", fuel_pump_nozzle_id: @nozzle.id
            },
          }, headers: auth_headers(@staff)

          assert_response :created
          assert_in_delta 7.5, response.parsed_body.dig("visit_entry", "litres"), 0.001
        end

        test "with no catalog price the sale is recorded and the skipped visit is explained" do
          assert_difference -> { Transaction.count }, 1 do
            assert_no_difference -> { VisitEntry.count } do
              post api_v1_staff_transactions_path, params: {
                transaction: {
                  lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
                  fuel_amount: "300", fuel_pump_nozzle_id: @nozzle.id
                },
              }, headers: auth_headers(@staff)
            end
          end

          assert_response :created
          body = response.parsed_body
          assert_nil body["visit_entry"]
          assert_match(/set the price in Products/i, body["visit_skipped_reason"])
        end

        test "an invalid capture is rejected without writing either record" do
          price_the_fuel!

          assert_no_difference [-> { Transaction.count }, -> { VisitEntry.count }] do
            post api_v1_staff_transactions_path, params: {
              transaction: {
                lookup_mode: "vehicle", vehicle_number: @vehicle.vehicle_number, vehicle_id: @vehicle.id,
                litres: "10", discount_amount: "99999", fuel_pump_nozzle_id: @nozzle.id
              },
            }, headers: auth_headers(@staff)
          end

          assert_response :unprocessable_entity
        end
      end
    end
  end
end
