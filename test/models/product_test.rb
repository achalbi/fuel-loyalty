require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "a valid lube product with a pack size" do
    product = Product.new(name: "AdBlue", category: "additive", pack_size: 20, pack_unit: "L", mrp: 1730, selling_price: 1730)
    assert product.valid?, product.errors.full_messages.to_sentence
    assert_equal "AdBlue 20L", product.display_name
  end

  test "fuel product requires a fuel_type_code; non-fuel forbids it" do
    fuel = Product.new(name: "HSD", category: "fuel", pack_unit: "litre", mrp: 98.95, selling_price: 98.95)
    assert_not fuel.valid?
    assert_includes fuel.errors[:fuel_type_code], "is required for a fuel product"

    lube = Product.new(name: "2T", category: "lubricant", fuel_type_code: "petrol", pack_size: 20, pack_unit: "ml")
    assert_not lube.valid?
    assert_includes lube.errors[:fuel_type_code], "is only allowed for a fuel product"
  end

  test "selling price above mrp is rejected" do
    product = Product.new(name: "X", category: "additive", mrp: 100, selling_price: 120)
    assert_not product.valid?
    assert_includes product.errors[:selling_price], "cannot be greater than the MRP"
  end

  test "only one active fuel product per fuel type" do
    Product.create!(name: "HSD", category: "fuel", fuel_type_code: "diesel", pack_unit: "litre", mrp: 98.95, selling_price: 98.95)
    dup = Product.new(name: "HSD Premium", category: "fuel", fuel_type_code: "diesel", pack_unit: "litre", mrp: 100, selling_price: 100)

    assert_not dup.valid?
    assert_match(/already prices diesel/, dup.errors[:base].join)
  end

  test "fuel_price_for returns the active fuel product's selling price" do
    Product.create!(name: "MS", category: "fuel", fuel_type_code: "petrol", pack_unit: "litre", mrp: 111.36, selling_price: 111.36)

    assert_equal BigDecimal("111.36"), Product.fuel_price_for("petrol")
    assert_nil Product.fuel_price_for("diesel")
  end
end
