require "test_helper"

module Admin
  # Web console coverage for the E5/E6/E7 CRM surfaces.
  class CrmControllersTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @staff = users(:two)
      @customer = Customer.create!(name: "Web CRM Cust", phone_number: "9777700001")
    end

    # ---- customer show renders the CRM panels (E3/E5/E7) ----
    test "customer show renders the CRM insight, outreach and feedback panels" do
      sign_in @admin
      get admin_customer_path(@customer)
      assert_response :success
      assert_select "h2", text: "CRM Insight"
      assert_select "h2", text: "Outreach"
      assert_select "h2", text: "Feedback"
    end

    test "customer show renders populated outreach and feedback timelines" do
      @customer.contact_logs.create!(user: @admin, channel: "whatsapp", outcome: "reached",
                                     notes: "Sent offer", contacted_at: 2.days.ago)
      @customer.customer_feedbacks.create!(rating: 5, comment: "Excellent", source: "admin")
      sign_in @admin
      get admin_customer_path(@customer)
      assert_response :success
      assert_select ".customer-details-vehicle-row__commercial", text: /Sent offer/
      assert_select ".customer-details-vehicle-row__commercial", text: /Excellent/
    end

    # ---- E5 log a contact ----
    test "admin logs a contact and it appears" do
      sign_in @admin
      contact = @customer.customer_contacts.create!(role: "owner", name: "K", phone_number: "9800011111")
      assert_difference -> { @customer.contact_logs.count }, 1 do
        post admin_customer_contact_logs_path(@customer),
          params: { contact_log: { channel: "call", outcome: "converted", customer_contact_id: contact.id, notes: "Deal" } }
      end
      assert_redirected_to admin_customer_path(@customer)
      assert contact.reload.contacted?
    end

    test "logging an invalid contact redirects with an alert" do
      sign_in @admin
      post admin_customer_contact_logs_path(@customer), params: { contact_log: { channel: "bad", outcome: "reached" } }
      assert_redirected_to admin_customer_path(@customer)
      assert_not_nil flash[:alert]
    end

    # ---- E7 capture feedback ----
    test "admin records feedback" do
      sign_in @admin
      assert_difference -> { @customer.customer_feedbacks.count }, 1 do
        post admin_customer_feedbacks_path(@customer), params: { feedback: { rating: 4, comment: "Good" } }
      end
      assert_redirected_to admin_customer_path(@customer)
      assert_equal "admin", @customer.customer_feedbacks.last.source
    end

    test "invalid feedback rating redirects with an alert" do
      sign_in @admin
      post admin_customer_feedbacks_path(@customer), params: { feedback: { rating: 9 } }
      assert_not_nil flash[:alert]
    end

    # ---- E6 reach-out page ----
    test "reach-out page lists lapsed customers" do
      lost = Customer.create!(name: "Lapsed", phone_number: "9777700099")
      VisitEntry.create!(customer: lost, user: @staff, fuel_pump: fuel_pumps(:one),
                         entry_date: Date.new(2026, 7, 10), vehicle_number: "TN77AA0001", litres: 20)
      sign_in @admin
      get admin_reach_out_index_path, params: { start_date: "2026-07-16", end_date: "2026-07-22" }
      assert_response :success
      assert_select "td", text: /Lapsed/
    end

    test "staff cannot reach the reach-out page" do
      sign_in @staff
      get admin_reach_out_index_path
      assert_response :redirect
    end
  end
end
