require "test_helper"

module Api
  module V1
    module Admin
      class CustomerFeedbacksControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
          @customer = Customer.create!(name: "Rating Cust", phone_number: "9444400001")
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "records admin feedback with source admin" do
          assert_difference -> { @customer.customer_feedbacks.count }, 1 do
            post api_v1_admin_customer_feedbacks_path(@customer),
              params: { feedback: { rating: 5, comment: "Quick service" } },
              headers: auth_headers(@admin)
          end
          assert_response :created
          body = response.parsed_body
          assert_equal 5, body["rating"]
          assert_equal "admin", body["source"]
        end

        test "rejects an out-of-range rating" do
          post api_v1_admin_customer_feedbacks_path(@customer),
            params: { feedback: { rating: 6 } }, headers: auth_headers(@admin)
          assert_response :unprocessable_entity
        end

        test "lists feedback with an average rating" do
          @customer.customer_feedbacks.create!(rating: 4, source: "staff")
          @customer.customer_feedbacks.create!(rating: 2, source: "admin")
          get api_v1_admin_customer_feedbacks_path(@customer), headers: auth_headers(@admin)
          assert_response :ok
          body = response.parsed_body
          assert_equal 2, body["count"]
          assert_equal 3.0, body["avg_rating"]
        end

        test "staff cannot use the admin feedback endpoint" do
          post api_v1_admin_customer_feedbacks_path(@customer),
            params: { feedback: { rating: 4 } }, headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
