require "test_helper"

module Api
  module V1
    module Staff
      class CustomerFeedbacksControllerTest < ActionDispatch::IntegrationTest
        setup do
          @staff = users(:two)
          @customer = Customer.create!(name: "Pump Cust", phone_number: "9555500001")
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "an FSM records feedback at the pump with source staff" do
          assert_difference -> { @customer.customer_feedbacks.count }, 1 do
            post api_v1_staff_customer_feedbacks_path(@customer),
              params: { feedback: { rating: 4, comment: "Friendly" } },
              headers: auth_headers(@staff)
          end
          assert_response :created
          body = response.parsed_body
          assert_equal "staff", body["source"]
          assert_equal @staff.display_name, body["recorded_by"]
        end

        test "requires authentication" do
          post api_v1_staff_customer_feedbacks_path(@customer), params: { feedback: { rating: 4 } }
          assert_response :unauthorized
        end

        test "cannot attach feedback to another customer's transaction (IDOR)" do
          other = Customer.create!(name: "Victim", phone_number: "9555500777")
          other_txn = Transaction.create!(customer: other, user: @staff, fuel_pump: fuel_pumps(:one),
                                          vehicle: vehicles(:one), fuel_amount: 400, payment_mode: "cash")
          assert_no_difference -> { CustomerFeedback.count } do
            post api_v1_staff_customer_feedbacks_path(@customer),
              params: { feedback: { rating: 1, transaction_id: other_txn.id } },
              headers: auth_headers(@staff)
          end
          assert_response :unprocessable_entity
          # The victim's own feedback slot for that transaction stays available.
          assert other.customer_feedbacks.create(rating: 5, source: "staff", fuel_transaction: other_txn).persisted?
        end

        test "a bogus transaction id is a 422, not a 500" do
          post api_v1_staff_customer_feedbacks_path(@customer),
            params: { feedback: { rating: 3, transaction_id: 999_999_999 } },
            headers: auth_headers(@staff)
          assert_response :unprocessable_entity
        end
      end
    end
  end
end
