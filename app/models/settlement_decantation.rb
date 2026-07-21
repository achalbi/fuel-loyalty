class SettlementDecantation < ApplicationRecord
  # D8 — tank KL readings before/after a tanker drop.
  belongs_to :daily_settlement

  before_validation :normalize

  validates :fuel_type_code, presence: true
  validates :opening_kl, :closing_kl, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :closing_not_before_opening

  private

  def normalize
    self.fuel_type_code = fuel_type_code.to_s.strip.downcase.presence
    self.tank_label = tank_label.to_s.strip.presence
  end

  def closing_not_before_opening
    return if opening_kl.blank? || closing_kl.blank?
    return if closing_kl.to_d >= opening_kl.to_d

    errors.add(:closing_kl, "cannot be less than the opening KL.")
  end
end
