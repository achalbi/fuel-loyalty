require "test_helper"

module Notifications
  class AudienceResolverTest < ActiveSupport::TestCase
    test "all resolves to every active customer and flags all?" do
      result = AudienceResolver.call(target_type: "all")
      assert result.all?
      assert_includes result.customers, customers(:one)
    end

    test "customer_type filters by the enum value" do
      customers(:one).update!(customer_type: :otp)
      customers(:two).update!(customer_type: :drive_in)
      result = AudienceResolver.call(target_type: "customer_type", target_customer_type: "otp")
      assert_not result.all?
      assert_includes result.customers, customers(:one)
      assert_not_includes result.customers, customers(:two)
    end

    test "an unknown customer_type resolves to nobody" do
      result = AudienceResolver.call(target_type: "customer_type", target_customer_type: "bogus")
      assert_empty result.customers
    end

    test "individual/selected use the supplied ids" do
      result = AudienceResolver.call(target_type: "selected", customer_ids: [customers(:one).id])
      assert_equal [customers(:one).id], result.customers.pluck(:id)
    end
  end
end
