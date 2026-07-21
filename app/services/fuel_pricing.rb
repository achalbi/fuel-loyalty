# Central fuel-price resolver: the ₹/L used to derive amounts from litres.
# The product catalog (A5) is the authority; this indirection keeps the price
# source in one place for future changes.
class FuelPricing
  def self.current_price(fuel_type_code)
    Product.fuel_price_for(fuel_type_code)
  end
end
