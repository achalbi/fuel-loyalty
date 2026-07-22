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
      end
    end
  end
end
