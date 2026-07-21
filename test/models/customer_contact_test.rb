require "test_helper"

class CustomerContactTest < ActiveSupport::TestCase
  setup { @customer = customers(:one) }

  test "requires a valid role" do
    contact = @customer.customer_contacts.build(role: "chauffeur", name: "Ravi")
    assert_not contact.valid?
    assert_includes contact.errors[:role], "is not included in the list"
  end

  test "normalizes the phone number and squishes the name" do
    contact = @customer.customer_contacts.create!(role: "driver", name: "  Ravi  Kumar ", phone_number: "90000 11122")
    assert_equal "Ravi Kumar", contact.name
    assert_equal "9000011122", contact.phone_number
  end

  test "stamps contacted_at when marked contacted and clears it when unmarked" do
    contact = @customer.customer_contacts.create!(role: "driver", name: "Ravi", contacted: true)
    assert_not_nil contact.contacted_at

    contact.update!(contacted: false)
    assert_nil contact.contacted_at
  end

  test "display_role humanizes the role" do
    assert_equal "Supervisor", @customer.customer_contacts.build(role: "supervisor").display_role
  end
end
