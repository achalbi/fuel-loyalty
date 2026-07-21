require "test_helper"

class FuelTypeTest < ActiveSupport::TestCase
  test "default fuel types use the outlet's MS / HSD terminology with stable codes" do
    defaults = FuelType::DEFAULT_OPTIONS.to_h.invert

    assert_equal "MS (Petrol)", defaults["petrol"]
    assert_equal "HSD (Diesel)", defaults["diesel"]
    assert_equal "MS (Petrol)", FuelType.default_label_for("petrol")
    assert_equal "HSD (Diesel)", FuelType.default_label_for("diesel")
    # Codes are unchanged so vehicles / nozzles / reward rates keep resolving.
    assert_equal %w[petrol diesel cng_lpg], FuelType::DEFAULT_CODES
  end
end
