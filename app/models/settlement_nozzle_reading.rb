class SettlementNozzleReading < ApplicationRecord
  # D1 — one meter reading per active nozzle. Net litres and ₹ amount are derived
  # server-side (never trusted from the client): net = closing − opening −
  # testing; amount = net × unit_price. A meter that mechanically wraps past its
  # max resets to 0, so `rollover` means the closing reading is the new absolute
  # total since reset and net = closing − testing (opening ignored).
  belongs_to :daily_settlement
  belongs_to :fuel_pump_nozzle

  # How the opening reading got the value it has.
  #   prior_settlement — auto-popped from the last settled sheet (rule 1).
  #   manual           — there was nothing to pop from, so the meter was read.
  #   corrected        — a figure was offered and the FSM overrode it. This is
  #                      the missed-days case: the pump kept selling while no
  #                      sheet was filed, so the last recorded closing is behind
  #                      the meter and only the operator can say where it now is.
  # Derived server-side on every save (Settlement::Persister) and never taken
  # from the request — a field the client can set is not an audit field.
  OPENING_SOURCES = %w[prior_settlement manual corrected].freeze

  before_validation :recompute

  validates :testing_litres, numericality: { greater_than_or_equal_to: 0 }
  validates :opening_source, inclusion: { in: OPENING_SOURCES }
  validate :closing_not_before_opening
  validate :net_not_negative

  def nozzle_label
    fuel_pump_nozzle&.display_name || "nozzle"
  end

  def opening_corrected? = opening_source == "corrected"

  def derive_opening_source!
    self.opening_source =
      if prior_closing_reading.blank? || opening_reading.blank?
        "manual"
      elsif opening_reading.to_d == prior_closing_reading.to_d
        "prior_settlement"
      else
        "corrected"
      end
  end

  # Days between the sheet the opening was offered from and this one. Zero when
  # they are consecutive (or when there is nothing to compare); anything above
  # that is a stretch the pump was selling through unrecorded.
  def unsettled_days_before(business_date = daily_settlement&.business_date)
    return 0 if prior_closing_date.blank? || business_date.blank?

    ((business_date.to_date - prior_closing_date).to_i - 1).clamp(0, nil)
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
