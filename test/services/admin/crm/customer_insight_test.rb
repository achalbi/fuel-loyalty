require "test_helper"

module Admin
  module Crm
    class CustomerInsightTest < ActiveSupport::TestCase
      AS_OF = Time.zone.local(2026, 7, 22, 12, 0, 0)

      setup do
        # A fresh customer with no fixture transactions, so the visit history under
        # test is exactly what each case creates.
        @customer = Customer.create!(name: "Cadence Cust", phone_number: "9111100001")
        @staff = users(:two)
        @pump = fuel_pumps(:one)
      end

      def add_visit(date)
        VisitEntry.create!(customer: @customer, user: @staff, fuel_pump: @pump, entry_date: date,
                           vehicle_number: "TN01AA1111", litres: 30)
      end

      test "derives weekly cadence and recency from visit history" do
        [Date.new(2026, 7, 1), Date.new(2026, 7, 8), Date.new(2026, 7, 15)].each { |d| add_visit(d) }
        data = CustomerInsight.new(@customer, as_of: AS_OF).to_h

        assert_equal "weekly", data[:cadence_class]
        assert_equal 3, data[:visit_count]
        assert_equal Date.new(2026, 7, 15), data[:last_visited_on]
        assert_equal Date.new(2026, 7, 1), data[:first_visited_on]
        assert_equal 7, data[:days_since_last_visit]
        assert_equal Date.new(2026, 7, 22), data[:expected_next_visit_on]
        assert_operator data[:conversion_probability], :>, 0
      end

      test "unions transaction dates with visit-entry dates" do
        add_visit(Date.new(2026, 7, 8))
        add_visit(Date.new(2026, 7, 15))
        vehicle = Vehicle.create!(customer: @customer, vehicle_number: "TN09XX0001", fuel_type: "petrol", vehicle_kind: "two_wheeler")
        Transaction.create!(customer: @customer, user: @staff, fuel_pump: @pump, vehicle: vehicle,
                            fuel_amount: 500, payment_mode: "cash", created_at: Time.zone.local(2026, 7, 1, 9))
        data = CustomerInsight.new(@customer, as_of: AS_OF).to_h
        assert_equal 3, data[:visit_count]
        assert_equal Date.new(2026, 7, 1), data[:first_visited_on]
      end

      test "summarises contacts and feedback" do
        add_visit(Date.new(2026, 7, 15))
        ContactLog.create!(customer: @customer, user: @staff, channel: "call", outcome: "reached",
                           contacted_at: Time.zone.local(2026, 7, 20, 10))
        CustomerFeedback.create!(customer: @customer, rating: 4, source: "staff")
        CustomerFeedback.create!(customer: @customer, rating: 5, source: "admin", comment: "Great")

        data = CustomerInsight.new(@customer, as_of: AS_OF).to_h
        assert_equal 1, data[:contacts][:count]
        assert_equal "reached", data[:contacts][:last_outcome]
        assert_equal 2, data[:feedback][:count]
        assert_equal 4.5, data[:feedback][:avg_rating]
      end

      test "lost is true once past the expected next visit" do
        # weekly cadence, last visit 30 days before as_of → overdue
        [Date.new(2026, 6, 1), Date.new(2026, 6, 8), Date.new(2026, 6, 15)].each { |d| add_visit(d) }
        data = CustomerInsight.new(@customer, as_of: AS_OF).to_h
        assert data[:is_lost]
      end
    end
  end
end
