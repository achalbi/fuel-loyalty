class UserPumpAssignment < ApplicationRecord
  belongs_to :user, inverse_of: :daily_pump_assignments
  belongs_to :fuel_pump
  belongs_to :assigned_by, class_name: "User", optional: true

  before_validation :normalize_nozzle_ids

  validates :assigned_on, presence: true
  validates :fuel_pump, presence: true
  validates :assigned_on, uniqueness: { scope: :user_id }
  validate :nozzles_required_when_pump_selected
  validate :fuel_pump_must_be_active
  validate :nozzles_must_belong_to_pump
  validate :nozzles_must_be_active

  def assigned_fuel_pump_nozzles
    FuelPumpNozzle.where(id: assigned_fuel_pump_nozzle_ids)
  end

  def ready?
    fuel_pump&.active? && assigned_fuel_pump_nozzles.exists?
  end

  private

  def nozzles_required_when_pump_selected
    return if fuel_pump_id.blank? || assigned_fuel_pump_nozzle_ids.present?

    errors.add(:assigned_fuel_pump_nozzle_ids, "must include at least one nozzle")
  end

  def normalize_nozzle_ids
    self.assigned_fuel_pump_nozzle_ids = Array(assigned_fuel_pump_nozzle_ids)
      .filter_map { |id| Integer(id, exception: false) }
      .uniq
  end

  def fuel_pump_must_be_active
    return if fuel_pump.blank? || fuel_pump.active?

    errors.add(:fuel_pump_id, "must be active")
  end

  def nozzles_must_belong_to_pump
    return if fuel_pump_id.blank? || assigned_fuel_pump_nozzle_ids.blank?

    missing = assigned_fuel_pump_nozzles.count != assigned_fuel_pump_nozzle_ids.length
    invalid = assigned_fuel_pump_nozzles.where.not(fuel_pump_id: fuel_pump_id)
    errors.add(:assigned_fuel_pump_nozzle_ids, "must belong to the selected pump") if missing || invalid.exists?
  end

  def nozzles_must_be_active
    inactive = assigned_fuel_pump_nozzles.where(active: false)
    errors.add(:assigned_fuel_pump_nozzle_ids, "must all be active") if inactive.exists?
  end
end
