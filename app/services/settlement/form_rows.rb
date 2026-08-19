module Settlement
  # Pre-builds the fixed grid rows a server-rendered settlement form needs so
  # `fields_for` has stable rows to render: one lube row per catalog lube, the
  # full denomination grid, a per-fuel rate-comparison and stock-receipt row,
  # and a couple of blank credit/decantation rows. Idempotent — it only adds
  # rows not already represented (so an error re-render keeps the FSM's input),
  # and every blank row is dropped on submit by the model's reject_if.
  module FormRows
    module_function

    def prepare(settlement, lube_products:, fuel_products:)
      ensure_lube_rows(settlement, lube_products)
      ensure_denomination_rows(settlement)
      ensure_rate_comparison_rows(settlement, fuel_products)
      ensure_stock_receipt_rows(settlement, fuel_products)
      ensure_digital_receipt_rows(settlement)
      ensure_blank_credit_rows(settlement, 2)
      ensure_blank_expense_rows(settlement, 2)
      ensure_blank_decantation_rows(settlement, 2)
      settlement
    end

    def ensure_lube_rows(settlement, lube_products)
      existing = settlement.lube_lines.map(&:product_id).compact
      lube_products.each do |product|
        next if existing.include?(product.id)

        settlement.lube_lines.build(
          product_id: product.id, product_name_snapshot: product.display_name,
          unit_price: product.selling_price, quantity: 0
        )
      end
    end

    def ensure_denomination_rows(settlement)
      existing = settlement.cash_denominations.map(&:denomination).compact
      SettlementCashDenomination::DENOMINATIONS.each do |denom|
        next if existing.include?(denom)

        settlement.cash_denominations.build(denomination: denom, quantity: 0)
      end
    end

    def ensure_rate_comparison_rows(settlement, fuel_products)
      existing = settlement.rate_comparisons.map(&:fuel_type_code).compact
      fuel_products.each do |product|
        next if existing.include?(product.fuel_type_code)

        settlement.rate_comparisons.build(
          fuel_type_code: product.fuel_type_code, competitor_name: "JIO-BP", own_price: product.selling_price
        )
      end
    end

    def ensure_stock_receipt_rows(settlement, fuel_products)
      existing = settlement.stock_receipts.map(&:fuel_type_code).compact
      fuel_products.each do |product|
        next if existing.include?(product.fuel_type_code)

        settlement.stock_receipts.build(fuel_type_code: product.fuel_type_code, litres_received: 0)
      end
    end

    # PhonePe POS and Scanner are entered every day, so seed them; any other
    # means the FSM adds is a free-form row (staff feedback item 10).
    def ensure_digital_receipt_rows(settlement)
      existing = settlement.digital_receipts.map { |row| row.label.to_s.downcase }
      SettlementDigitalReceipt::DEFAULT_LABELS.each do |label|
        next if existing.include?(label.downcase)

        settlement.digital_receipts.build(label: label, amount: 0)
      end
      ensure_blank_digital_receipt_rows(settlement, 1)
    end

    # One spare blank row so a new means can be typed without a round trip.
    def ensure_blank_digital_receipt_rows(settlement, count)
      blanks = settlement.digital_receipts.count { |row| row.label.blank? }
      (count - blanks).clamp(0, count).times { settlement.digital_receipts.build }
    end

    def ensure_blank_expense_rows(settlement, count)
      blanks = settlement.expense_lines.count { |row| row.description.blank? }
      (count - blanks).clamp(0, count).times { settlement.expense_lines.build }
    end

    def ensure_blank_credit_rows(settlement, count)
      (count - settlement.credit_lines.size).clamp(0, count).times do
        settlement.credit_lines.build(credit_type: :fleet_otp)
      end
    end

    def ensure_blank_decantation_rows(settlement, count)
      (count - settlement.decantations.size).clamp(0, count).times do
        settlement.decantations.build
      end
    end
  end
end
