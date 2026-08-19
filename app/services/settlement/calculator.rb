module Settlement
  # Pure recompute of a settlement's parent aggregates from its (in-memory)
  # children. Line-level derivation (net litres, line amounts) lives in the child
  # models' before_validation; this owns the D6 final-amount and D7 shortage math.
  # Called on every save so stored totals always reconcile with the line items
  # and client-supplied totals are never trusted.
  module Calculator
    module_function

    # D6: Final Amount to Settle =
    #   (fuel + lubes) − (discounts + credit + digital receipts + expenses)
    # Digital receipts and expenses are line items rather than fixed columns
    # (staff feedback items 10 and 12): any means can be recorded, and cash taken
    # out during the day — a salary advance — reduces what the FSM hands over so
    # the counted cash still reconciles.
    # D7: counted cash = Σ denomination amounts; shortage = final − counted.
    def recompute!(settlement)
      settlement.total_fuel_amount = sum(settlement.nozzle_readings, :amount)
      settlement.total_lube_amount = sum(settlement.lube_lines, :amount)
      settlement.total_discount_amount = sum(settlement.discount_lines, :discount_amount)
      settlement.total_credit_amount = sum(settlement.credit_lines, :amount)
      settlement.total_digital_receipt_amount = sum(settlement.digital_receipts, :amount)
      settlement.total_expense_amount = sum(settlement.expense_lines, :amount)
      settlement.counted_cash_amount = sum(settlement.cash_denominations, :amount)

      final = settlement.total_fuel_amount + settlement.total_lube_amount -
        (settlement.total_discount_amount + settlement.total_credit_amount +
          settlement.total_digital_receipt_amount + settlement.total_expense_amount)

      settlement.final_amount_to_settle = final.round(2)
      settlement.shortage_amount = (final - settlement.counted_cash_amount).round(2)
      settlement
    end

    def sum(association, attribute)
      live_records(association).sum { |record| record.public_send(attribute).to_d }.round(2)
    end

    def live_records(association)
      association.reject(&:marked_for_destruction?)
    end
  end
end
