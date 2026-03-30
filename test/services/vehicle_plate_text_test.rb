require "test_helper"

class VehiclePlateTextTest < ActiveSupport::TestCase
  test "normalizes a manual vehicle number" do
    assert_equal "TN01AA1234", VehiclePlateText.normalize("tn 01 aa 1234")
  end

  test "keeps a valid vehicle number stable" do
    assert_equal "TN01AA1234", VehiclePlateText.normalize_detected("TN01AA1234")
    assert VehiclePlateText.valid?("TN01AA1234")
  end

  test "cleans common OCR mistakes for a standard indian registration" do
    assert_equal "TN01AA1234", VehiclePlateText.normalize_detected("tn 0l aa i234")
  end

  test "cleans common OCR mistakes for a BH registration" do
    assert_equal "22BH1234AA", VehiclePlateText.normalize_detected("22 8h l234 aa")
  end

  test "does not aggressively overcorrect unrelated text" do
    assert_equal "FUEL123", VehiclePlateText.normalize_detected("fuel 123")
    assert_not VehiclePlateText.valid?("FUEL123")
  end
end
