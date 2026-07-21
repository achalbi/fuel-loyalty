module Api
  module V1
    module Staff
      # Full Daily Settlement detail (parent + all child lines + derived totals)
      # and a compact list summary. Money/litres are rendered as floats to match
      # the rest of the staff API (see VisitEntrySerializer).
      class SettlementSerializer
        def self.call(settlement)
          new(settlement).full
        end

        def self.summary(settlement)
          new(settlement).summary
        end

        def initialize(settlement)
          @settlement = settlement
        end

        def summary
          {
            id: @settlement.id,
            business_date: @settlement.business_date.iso8601,
            status: @settlement.status,
            locked: @settlement.locked,
            fuel_pump_id: @settlement.fuel_pump_id,
            fuel_pump: @settlement.fuel_pump&.display_name,
            shift_template_id: @settlement.shift_template_id,
            fsm_name: @settlement.fsm_name_snapshot,
            total_fuel_amount: f(@settlement.total_fuel_amount),
            total_lube_amount: f(@settlement.total_lube_amount),
            total_discount_amount: f(@settlement.total_discount_amount),
            total_credit_amount: f(@settlement.total_credit_amount),
            final_amount_to_settle: f(@settlement.final_amount_to_settle),
            counted_cash_amount: f(@settlement.counted_cash_amount),
            shortage_amount: f(@settlement.shortage_amount),
            submitted_at: @settlement.submitted_at&.iso8601,
            created_at: @settlement.created_at&.iso8601,
          }
        end

        def full
          summary.merge(
            recorded_by_id: @settlement.recorded_by_id,
            phonepe_pos_amount: f(@settlement.phonepe_pos_amount),
            phonepe_scanner_amount: f(@settlement.phonepe_scanner_amount),
            notes: @settlement.notes,
            nozzle_readings: @settlement.nozzle_readings.map { |r| nozzle_reading(r) },
            lube_lines: @settlement.lube_lines.map { |l| lube_line(l) },
            discount_lines: @settlement.discount_lines.map { |d| discount_line(d) },
            credit_lines: @settlement.credit_lines.map { |c| credit_line(c) },
            cash_denominations: @settlement.cash_denominations.map { |c| denomination(c) },
            stock_receipts: @settlement.stock_receipts.map { |s| stock_receipt(s) },
            decantations: @settlement.decantations.map { |d| decantation(d) },
            rate_comparisons: @settlement.rate_comparisons.map { |r| rate_comparison(r) },
            updated_at: @settlement.updated_at&.iso8601,
          )
        end

        private

        def nozzle_reading(row)
          {
            id: row.id,
            fuel_pump_nozzle_id: row.fuel_pump_nozzle_id,
            display_name: row.fuel_pump_nozzle&.display_name,
            fuel_type_code: row.fuel_type_code_snapshot,
            fuel_type: row.fuel_pump_nozzle&.fuel_type_name,
            opening_reading: f(row.opening_reading),
            opening_source: row.opening_source,
            closing_reading: f(row.closing_reading),
            testing_litres: f(row.testing_litres),
            rollover: row.rollover,
            net_litres_sold: f(row.net_litres_sold),
            unit_price: f(row.unit_price),
            amount: f(row.amount),
          }
        end

        def lube_line(row)
          {
            id: row.id, product_id: row.product_id, product_name: row.product_name_snapshot,
            quantity: row.quantity, unit_price: f(row.unit_price), amount: f(row.amount),
            opening_stock: row.opening_stock, closing_stock: row.closing_stock,
          }
        end

        def discount_line(row)
          {
            id: row.id, visit_entry_id: row.visit_entry_id, transport_name: row.transport_name,
            litres: f(row.litres), discount_amount: f(row.discount_amount),
            driver_name: row.driver_name, driver_phone_number: row.driver_phone_number,
            manager_name: row.manager_name, manager_phone_number: row.manager_phone_number,
            owner_name: row.owner_name, owner_phone_number: row.owner_phone_number,
          }
        end

        def credit_line(row)
          {
            id: row.id, credit_type: row.credit_type, litres: f(row.litres),
            discount_amount: f(row.discount_amount), amount: f(row.amount),
            reference: row.reference, note: row.note,
          }
        end

        def denomination(row)
          { id: row.id, denomination: row.denomination, quantity: row.quantity, amount: f(row.amount) }
        end

        def stock_receipt(row)
          { id: row.id, fuel_type_code: row.fuel_type_code, litres_received: f(row.litres_received) }
        end

        def decantation(row)
          {
            id: row.id, fuel_type_code: row.fuel_type_code, tank_label: row.tank_label,
            opening_kl: f(row.opening_kl), closing_kl: f(row.closing_kl),
          }
        end

        def rate_comparison(row)
          {
            id: row.id, fuel_type_code: row.fuel_type_code, competitor_name: row.competitor_name,
            competitor_price: f(row.competitor_price), own_price: f(row.own_price),
          }
        end

        def f(value)
          value.nil? ? nil : value.to_f
        end
      end
    end
  end
end
