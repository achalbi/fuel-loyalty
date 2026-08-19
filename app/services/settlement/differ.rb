module Settlement
  # Builds the field-level diff stored on a settlement_changes audit row. Takes a
  # before/after snapshot of the parent's meaningful columns plus a per-line
  # fingerprint of each child collection, and returns a flat map of changed
  # paths → [old, new]. Mirrors the intent of attendance_entry_changes'
  # before/after payloads.
  module Differ
    module_function

    # The identity/attribution columns lead the list on purpose. They can never
    # change on an admin edit (the admin strong params omit them), so they
    # normally contribute nothing to a diff — but they are exactly what an
    # on-behalf CREATE has to put on the record: which pump/date/shift the sheet
    # is for, which FSM it is attributed to, and which admin actually typed it.
    # Keeping them here also means that if authorship ever did move, the audit
    # row would say so instead of hiding it.
    PARENT_FIELDS = %w[
      business_date fuel_pump_id shift_template_id
      recorded_by_id fsm_name_snapshot entered_by_id
      status notes
      total_fuel_amount total_lube_amount total_discount_amount total_credit_amount
      total_digital_receipt_amount total_expense_amount
      final_amount_to_settle counted_cash_amount shortage_amount
    ].freeze

    # The "before" side of a settlement that did not exist yet. Diffing a fresh
    # on-behalf create against this yields only the values that were actually
    # entered — an untouched zero total stays out of the audit row, where an
    # empty `{}` baseline would have listed every default as a change.
    def blank_snapshot
      snapshot(DailySettlement.new)
    end

    def snapshot(settlement)
      parent = PARENT_FIELDS.index_with { |field| stringify(settlement.public_send(field)) }
      parent.merge(
        "nozzle_readings" => fingerprint(settlement.nozzle_readings, %i[fuel_pump_nozzle_id closing_reading testing_litres net_litres_sold unit_price amount]),
        "lube_lines" => fingerprint(settlement.lube_lines, %i[product_id quantity unit_price amount]),
        "discount_lines" => fingerprint(settlement.discount_lines, %i[visit_entry_id litres discount_amount]),
        "credit_lines" => fingerprint(settlement.credit_lines, %i[credit_type litres amount reference]),
        "cash_denominations" => fingerprint(settlement.cash_denominations, %i[denomination quantity]),
        "digital_receipts" => fingerprint(settlement.digital_receipts, %i[label amount]),
        "expense_lines" => fingerprint(settlement.expense_lines, %i[description amount]),
        "stock_receipts" => fingerprint(settlement.stock_receipts, %i[fuel_type_code litres_received]),
        "decantations" => fingerprint(settlement.decantations, %i[fuel_type_code tank_label opening_kl closing_kl]),
        "rate_comparisons" => fingerprint(settlement.rate_comparisons, %i[fuel_type_code competitor_price own_price])
      )
    end

    # Returns { "field" => [old, new], ... } for every key whose value changed.
    def diff(before, after)
      (before.keys | after.keys).each_with_object({}) do |key, changes|
        old_value = before[key]
        new_value = after[key]
        changes[key] = [old_value, new_value] if old_value != new_value
      end
    end

    def fingerprint(association, attributes)
      association.reject(&:marked_for_destruction?).map do |record|
        attributes.to_h { |attr| [attr.to_s, stringify(record.public_send(attr))] }
      end
    end

    def stringify(value)
      case value
      when BigDecimal then value.to_s("F")
      when nil then nil
      else value.to_s
      end
    end
  end
end
