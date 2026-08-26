# Formatting for the read-only settlement sheet (shared/_settlement_sheet),
# which reprints an entered settlement in the FSM's own entry order. The numbers
# have to read the way they were typed: litres to 3 dp like the reading inputs,
# blanks as an em dash rather than a misleading 0.
module SettlementsHelper
  SETTLEMENT_BLANK = "—".freeze

  def settlement_money(value)
    return SETTLEMENT_BLANK if value.nil?

    number_to_currency(value, unit: "₹")
  end

  def settlement_litres(value)
    return SETTLEMENT_BLANK if value.nil?

    number_with_precision(value, precision: 3, strip_insignificant_zeros: true)
  end

  def settlement_price(value)
    return SETTLEMENT_BLANK if value.nil?

    number_with_precision(value, precision: 2)
  end

  def settlement_count(value)
    return SETTLEMENT_BLANK if value.nil?

    number_with_delimiter(value)
  end

  # The opening reading is offered from the last settled sheet (rule 1). Naming
  # the figure and the date it came from is what lets an FSM judge it: yesterday
  # is worth accepting, a week ago means the meter moved through days nobody
  # recorded and the offer is behind it.
  def settlement_prior_closing_note(reading)
    return nil if reading.prior_closing_reading.blank?

    note = "Last settled #{settlement_litres(reading.prior_closing_reading)}"
    note += " on #{reading.prior_closing_date.strftime('%-d %b')}" if reading.prior_closing_date.present?
    note
  end

  def settlement_unsettled_gap_note(reading, business_date)
    days = reading.unsettled_days_before(business_date)
    return nil if days.zero?

    "#{pluralize(days, 'day')} not settled — read the meter"
  end

  def settlement_status_badge_class(settlement)
    if settlement.reconciled?
      "text-bg-success"
    elsif settlement.submitted?
      "text-bg-primary"
    else
      "text-bg-secondary"
    end
  end
end
