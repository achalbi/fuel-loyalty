module Settlement
  # Builds the field-level diff stored on a settlement_changes audit row. Takes a
  # before/after snapshot of the parent's meaningful columns plus a per-line
  # fingerprint of each child collection, and returns a flat map of changed
  # paths → [old, new]. Mirrors the intent of attendance_entry_changes'
  # before/after payloads.
  module Differ
    module_function

    PARENT_FIELDS = %w[
      status phonepe_pos_amount phonepe_scanner_amount notes
      total_fuel_amount total_lube_amount total_discount_amount total_credit_amount
      final_amount_to_settle counted_cash_amount shortage_amount
    ].freeze

    def snapshot(settlement)
      parent = PARENT_FIELDS.index_with { |field| stringify(settlement.public_send(field)) }
      parent.merge(
        "nozzle_readings" => fingerprint(settlement.nozzle_readings, %i[fuel_pump_nozzle_id closing_reading testing_litres net_litres_sold unit_price amount]),
        "lube_lines" => fingerprint(settlement.lube_lines, %i[product_id quantity unit_price amount]),
        "discount_lines" => fingerprint(settlement.discount_lines, %i[visit_entry_id litres discount_amount]),
        "credit_lines" => fingerprint(settlement.credit_lines, %i[credit_type litres amount reference]),
        "cash_denominations" => fingerprint(settlement.cash_denominations, %i[denomination quantity]),
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
