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
end
