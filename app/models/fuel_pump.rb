class FuelPump < ApplicationRecord
  has_many :nozzles,
    -> { order(:sequence_number, :id) },
    class_name: "FuelPumpNozzle",
    dependent: :destroy,
    inverse_of: :fuel_pump
  has_many :assigned_users,
    class_name: "User",
    foreign_key: :fuel_pump_id,
    inverse_of: :assigned_fuel_pump,
    dependent: :nullify
  has_many :transactions

  accepts_nested_attributes_for :nozzles, allow_destroy: true, reject_if: :reject_nozzle_attributes?

  before_validation :assign_sequence_number, on: :create
  before_validation :assign_missing_nozzle_sequence_numbers
  before_destroy :ensure_not_used_by_transactions
  validate :must_include_at_least_one_nozzle

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sequence_number, :id) }

  validates :sequence_number, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }
  validates :active, inclusion: { in: [true, false] }

  def self.for_settings
    includes(nozzles: :fuel_type_record).ordered.to_a
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    []
  end

  def self.next_sequence_number
    ordered.maximum(:sequence_number).to_i + 1
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    1
  end

  def self.next_display_name
    "Pump #{next_sequence_number}"
  end

  def display_name
    sequence_number.present? ? "Pump #{sequence_number}" : self.class.next_display_name
  end

  def active_nozzles_count
    if association(:nozzles).loaded?
      nozzles.count(&:active?)
    else
      nozzles.active.count
    end
  end

  def transaction_remove_error_message
    "cannot be removed while transactions still use it"
  end

  private

  def assign_sequence_number
    self.sequence_number ||= self.class.next_sequence_number
  end

  def assign_missing_nozzle_sequence_numbers
    retained_nozzles = nozzles.reject(&:marked_for_destruction?)
    return if retained_nozzles.empty?

    reserved_sequence_number = nozzles.map(&:sequence_number).compact.max.to_i + 1

    nozzles.select(&:marked_for_destruction?).each do |nozzle|
      nozzle.sequence_number = reserved_sequence_number
      reserved_sequence_number += 1
    end

    taken_sequence_numbers = retained_nozzles.map(&:sequence_number).compact

    retained_nozzles.each do |nozzle|
      next if nozzle.sequence_number.present?

      next_sequence_number = 1
      next_sequence_number += 1 while taken_sequence_numbers.include?(next_sequence_number)

      nozzle.sequence_number = next_sequence_number
      taken_sequence_numbers << next_sequence_number
    end
  end

  def must_include_at_least_one_nozzle
    return if nozzles.reject(&:marked_for_destruction?).any?

    errors.add(:nozzles, "must include at least one nozzle")
  end

  def reject_nozzle_attributes?(attributes)
    attributes["id"].blank? && attributes["fuel_type_code"].to_s.blank?
  end

  def ensure_not_used_by_transactions
    return unless transactions.exists?

    errors.add(:base, transaction_remove_error_message)
    throw :abort
  end
end
