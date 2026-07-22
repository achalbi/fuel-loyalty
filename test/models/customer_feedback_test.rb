require "test_helper"

class CustomerFeedbackTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:one)
  end

  def build(attrs = {})
    CustomerFeedback.new({ customer: @customer, rating: 4 }.merge(attrs))
  end

  test "valid with a 1..5 rating" do
    assert build(rating: 1).valid?
    assert build(rating: 5).valid?
  end

  test "rejects ratings outside 1..5" do
    assert_not build(rating: 0).valid?
    assert_not build(rating: 6).valid?
    assert_not build(rating: nil).valid?
  end

  test "defaults source to staff" do
    feedback = build
    feedback.save!
    assert_equal "staff", feedback.source
  end

  test "rejects an unknown source" do
    assert_not build(source: "carrier_pigeon").valid?
  end

  test "at most one feedback per transaction" do
    txn = Transaction.create!(customer: @customer, user: users(:two), fuel_pump: fuel_pumps(:one),
                              vehicle: vehicles(:one), fuel_amount: 400, payment_mode: "cash")
    build(fuel_transaction: txn).save!
    dup = build(fuel_transaction: txn)
    assert_not dup.valid?
  end

  test "allows many feedbacks with no transaction link" do
    build.save!
    assert build.valid?
  end

  test "rejects a transaction that belongs to another customer" do
    other = Customer.create!(name: "Other", phone_number: "9000000123")
    other_txn = Transaction.create!(customer: other, user: users(:two), fuel_pump: fuel_pumps(:one),
                                    vehicle: vehicles(:three), fuel_amount: 300, payment_mode: "cash")
    fb = build(fuel_transaction: other_txn)
    assert_not fb.valid?
    assert_includes fb.errors[:transaction_id], "must belong to the same customer"
  end

  test "rejects a non-existent transaction id (no DB 500)" do
    fb = build
    fb.transaction_id = 999_999_999
    assert_not fb.valid?
    assert_includes fb.errors[:transaction_id], "does not exist"
  end

  test "rejects a visit_entry that belongs to another customer" do
    other = Customer.create!(name: "Other2", phone_number: "9000000124")
    other_visit = VisitEntry.create!(customer: other, user: users(:two), fuel_pump: fuel_pumps(:one),
                                     entry_date: Date.new(2026, 7, 1), vehicle_number: "TN00ZZ0001", litres: 10)
    fb = build(visit_entry: other_visit)
    assert_not fb.valid?
    assert_includes fb.errors[:visit_entry_id], "must belong to the same customer"
  end

  test "accepts a transaction that belongs to the same customer" do
    txn = Transaction.create!(customer: @customer, user: users(:two), fuel_pump: fuel_pumps(:one),
                              vehicle: vehicles(:one), fuel_amount: 300, payment_mode: "cash")
    assert build(fuel_transaction: txn).valid?
  end
end
