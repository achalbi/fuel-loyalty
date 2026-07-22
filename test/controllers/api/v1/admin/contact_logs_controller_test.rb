require "test_helper"

module Api
  module V1
    module Admin
      class ContactLogsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
          @customer = Customer.create!(name: "Reach Cust", phone_number: "9333300001")
          @contact = @customer.customer_contacts.create!(role: "owner", name: "K Reddy", phone_number: "9800012345")
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "logs an outreach event and echoes it" do
          assert_difference -> { @customer.contact_logs.count }, 1 do
            post api_v1_admin_customer_contact_logs_path(@customer),
              params: { contact_log: { channel: "call", outcome: "reached", contacted_role: "owner", customer_contact_id: @contact.id, notes: "Picked up" } },
              headers: auth_headers(@admin)
          end
          assert_response :created
          body = response.parsed_body
          assert_equal "call", body["channel"]
          assert_equal "reached", body["outcome"]
          assert_equal @admin.display_name, body["logged_by"]
        end

        test "a successful outreach flips the B1 contacted marker" do
          post api_v1_admin_customer_contact_logs_path(@customer),
            params: { contact_log: { channel: "whatsapp", outcome: "converted", customer_contact_id: @contact.id } },
            headers: auth_headers(@admin)
          assert_response :created
          assert @contact.reload.contacted?
          assert_not_nil @contact.contacted_at
        end

        test "an unsuccessful outcome does not flip the marker" do
          post api_v1_admin_customer_contact_logs_path(@customer),
            params: { contact_log: { channel: "call", outcome: "no_answer", customer_contact_id: @contact.id } },
            headers: auth_headers(@admin)
          assert_response :created
          assert_not @contact.reload.contacted?
        end

        test "rejects an unknown channel with 422" do
          post api_v1_admin_customer_contact_logs_path(@customer),
            params: { contact_log: { channel: "smoke_signal", outcome: "reached" } },
            headers: auth_headers(@admin)
          assert_response :unprocessable_entity
          assert_equal "validation_failed", response.parsed_body.dig("error", "code")
        end

        test "lists a customer's outreach history newest first" do
          @customer.contact_logs.create!(user: @admin, channel: "call", outcome: "no_answer", contacted_at: 3.days.ago)
          @customer.contact_logs.create!(user: @admin, channel: "sms", outcome: "reached", contacted_at: 1.hour.ago)
          get api_v1_admin_customer_contact_logs_path(@customer), headers: auth_headers(@admin)
          assert_response :ok
          logs = response.parsed_body["contact_logs"]
          assert_equal 2, logs.size
          assert_equal "sms", logs.first["channel"]
        end

        test "staff cannot log contacts via the admin endpoint" do
          post api_v1_admin_customer_contact_logs_path(@customer),
            params: { contact_log: { channel: "call", outcome: "reached" } },
            headers: auth_headers(@staff)
          assert_response :forbidden
        end
      end
    end
  end
end
