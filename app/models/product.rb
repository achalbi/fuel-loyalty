class Product < ApplicationRecord
  # Priced catalog of everything the outlet sells: fuels (linked to a fuel type
  # for nozzle pricing) and lubes/oils/additives (sold by pack). `selling_price`
  # is the source of truth for deriving ₹ from litres/qty in Daily Settlement.
  CATEGORIES = %w[fuel lubricant oil additive].freeze
  FUEL_CATEGORY = "fuel".freeze

  belongs_to :fuel_type_record,
    class_name: "FuelType", foreign_key: :fuel_type_code, primary_key: :code,
    inverse_of: false, optional: true

  before_validation :normalize_fields

  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :mrp, numericality: { greater_than_or_equal_to: 0 }
  validates :selling_price, numericality: { greater_than_or_equal_to: 0 }
  validates :pack_size, numericality: { greater_than: 0 }, allow_nil: true
  validates :track_stock, inclusion: { in: [true, false] }
  validates :active, inclusion: { in: [true, false] }
  validate :fuel_type_code_matches_category
  validate :selling_price_not_above_mrp
  validate :single_active_fuel_per_fuel_type

  scope :active, -> { where(active: true) }
  scope :fuel, -> { where(category: FUEL_CATEGORY) }
  scope :ordered, -> { order(Arel.sql("sl_num IS NULL, sl_num ASC, name ASC, pack_size ASC NULLS FIRST")) }

  def self.for_settings
    ordered.to_a
  end

  # The active fuel product that prices a nozzle of the given fuel type. Its
  # selling_price is what Daily Settlement multiplies litres by (D1/D6).
  def self.fuel_price_for(fuel_type_code)
    normalized = fuel_type_code.to_s.presence
    return nil if normalized.blank?

    active.fuel.find_by(fuel_type_code: normalized)&.selling_price
  end

  def fuel?
    category == FUEL_CATEGORY
  end

  # "10W30 800ml" / "AdBlue 20L" / "HSD" for pickers.
  def display_name
    return name if pack_size.blank?

    size = pack_size.to_d.frac.zero? ? pack_size.to_i : pack_size
    [name, "#{size}#{pack_unit}"].compact_blank.join(" ")
  end

  private

  def normalize_fields
    self.name = name.to_s.squish.presence
    self.category = category.to_s.strip.downcase.presence
    self.fuel_type_code = fuel_type_code.to_s.strip.downcase.presence
    self.pack_unit = pack_unit.to_s.strip.presence
    self.batch = batch.to_s.squish.presence
    self.mrp = 0 if mrp.blank?
    self.selling_price = 0 if selling_price.blank?
  end

  def fuel_type_code_matches_category
    if fuel?
      errors.add(:fuel_type_code, "is required for a fuel product") if fuel_type_code.blank?
    elsif fuel_type_code.present?
      errors.add(:fuel_type_code, "is only allowed for a fuel product")
    end
  end

  # Selling below MRP is legal (discounts); selling above MRP is not.
  def selling_price_not_above_mrp
    return if mrp.to_d.zero? || selling_price.to_d <= mrp.to_d

    errors.add(:selling_price, "cannot be greater than the MRP")
  end

  def single_active_fuel_per_fuel_type
    return unless fuel? && active? && fuel_type_code.present?

    clash = Product.active.fuel.where(fuel_type_code: fuel_type_code).where.not(id: id)
    return unless clash.exists?

    errors.add(:base, "Another active fuel product already prices #{fuel_type_code}")
  end
end
