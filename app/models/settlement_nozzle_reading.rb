class SettlementNozzleReading < ApplicationRecord
  # D1 — one meter reading per active nozzle. Net litres and ₹ amount are derived
  # server-side (never trusted from the client): net = closing − opening −
  # testing; amount = net × unit_price. A meter that mechanically wraps past its
  # max resets to 0, so `rollover` means the closing reading is the new absolute
  # total since reset and net = closing − testing (opening ignored).
  belongs_to :daily_settlement
  belongs_to :fuel_pump_nozzle

  before_validation :recompute

  validates :testing_litres, numericality: { greater_than_or_equal_to: 0 }
  validate :closing_not_before_opening
  validate :net_not_negative

  def nozzle_label
    fuel_pump_nozzle&.display_name || "nozzle"
  end

  private

  def recompute
    self.testing_litres = 0 if testing_litres.blank?
    self.net_litres_sold = computed_net_litres
    self.amount =
      if net_litres_sold && unit_price
        (net_litres_sold.to_d * unit_price.to_d).round(2)
      end
  end

  def computed_net_litres
    return if closing_reading.blank?

    if rollover?
      (closing_reading.to_d - testing_litres.to_d).round(3)
    else
      return if opening_reading.blank?

      (closing_reading.to_d - opening_reading.to_d - testing_litres.to_d).round(3)
    end
  end

  def closing_not_before_opening
    return if rollover? || opening_reading.blank? || closing_reading.blank?
    return if closing_reading.to_d >= opening_reading.to_d

    errors.add(:closing_reading, "cannot be less than the opening reading (tick rollover if the meter reset).")
  end

  def net_not_negative
    return if net_litres_sold.blank? || net_litres_sold.to_d >= 0

    errors.add(:net_litres_sold, "cannot be negative — check testing litres and readings.")
  end
end
