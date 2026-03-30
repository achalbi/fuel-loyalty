class FuelPumpNozzle < ApplicationRecord
  belongs_to :fuel_pump, inverse_of: :nozzles
  belongs_to :fuel_type_record,
    class_name: "FuelType",
    foreign_key: :fuel_type_code,
    primary_key: :code,
    inverse_of: false,
    optional: true
  has_many :user_pump_nozzle_assignments, dependent: :destroy, inverse_of: :fuel_pump_nozzle
  has_many :assigned_users, through: :user_pump_nozzle_assignments, source: :user
  has_many :transactions

  before_destroy :ensure_not_used_by_transactions

  before_validation :normalize_fuel_type_code

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sequence_number, :id) }

  validates :sequence_number,
    presence: true,
    uniqueness: { scope: :fuel_pump_id },
    numericality: { only_integer: true, greater_than: 0 }
  validates :fuel_type_code, presence: true
  validates :active, inclusion: { in: [true, false] }
  validate :fuel_type_must_exist_for_new_selection
  validate :fuel_type_must_be_active_for_new_selection

  def display_name
    sequence_number.present? ? "Nozzle #{sequence_number}" : "New Nozzle"
  end

  def fuel_type_name
    fuel_type_record&.name.presence ||
      FuelType.default_label_for(fuel_type_code) ||
      FuelType.label_for(fuel_type_code).presence ||
      fuel_type_code.to_s.humanize
  end

  private

  def normalize_fuel_type_code
    self.fuel_type_code = fuel_type_code.to_s.parameterize(separator: "_").presence
  end

  def fuel_type_must_exist_for_new_selection
    return if fuel_type_code.blank?
    return if FuelType.exists?(code: fuel_type_code)
    return if persisted? && fuel_type_code == fuel_type_code_in_database

    errors.add(:fuel_type_code, "is not available")
  end

  def fuel_type_must_be_active_for_new_selection
    return if fuel_type_code.blank?
    return unless FuelType.exists?(code: fuel_type_code)
    return if FuelType.active_code?(fuel_type_code)
    return if persisted? && fuel_type_code == fuel_type_code_in_database

    errors.add(:fuel_type_code, "is not currently active")
  end

  def ensure_not_used_by_transactions
    return unless transactions.exists?

    errors.add(:base, "cannot be removed while transactions still use it")
    throw :abort
  end
end
