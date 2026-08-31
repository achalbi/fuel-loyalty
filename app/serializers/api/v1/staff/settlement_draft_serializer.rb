module Api
  module V1
    module Staff
      # The "new settlement" hydration payload from Settlement::Builder: the
      # active nozzles with yesterday's reading auto-popped and catalog prices,
      # the same-day pulled discounts, the lube picklist, and the denomination
      # grid. `existing_settlement_id` lets the client redirect to edit instead
      # of creating a duplicate.
      class SettlementDraftSerializer
        def self.call(result)
          new(result).call
        end

        def initialize(result)
          @result = result
          @settlement = result.settlement
        end

        def call
          {
            business_date: @settlement.business_date.iso8601,
            shift_template_id: @settlement.shift_template_id,
            fuel_pump: @result.fuel_pump && {
              id: @result.fuel_pump.id, display_name: @result.fuel_pump.display_name
            },
            fsm_name: @settlement.fsm_name_snapshot,
            existing_settlement_id: @result.existing&.id,
            nozzle_readings: @settlement.nozzle_readings.map { |r| nozzle_reading(r) },
            discount_lines: @settlement.discount_lines.map { |d| discount_line(d) },
            lube_products: @result.lube_products.map { |p| lube_product(p) },
            denominations: @result.denominations,
            # The means every draft starts with (item 10); the client may add more.
            default_digital_receipt_labels: SettlementDigitalReceipt::DEFAULT_LABELS,
          }
        end

        private

        def nozzle_reading(row)
          {
            fuel_pump_nozzle_id: row.fuel_pump_nozzle_id,
            display_name: row.fuel_pump_nozzle&.display_name,
            fuel_type_code: row.fuel_type_code_snapshot,
            fuel_type: row.fuel_pump_nozzle&.fuel_type_name,
            opening_reading: f(row.opening_reading),
            opening_source: row.opening_source,
            # What the last settled sheet closed at, and when. The client shows
            # both so the FSM can tell an inherited figure from a stale one and
            # correct it when days went unsettled (rule 1).
            prior_closing_reading: f(row.prior_closing_reading),
            prior_closing_date: row.prior_closing_date&.iso8601,
            unit_price: f(row.unit_price),
          }
        end

        def discount_line(row)
          {
            visit_entry_id: row.visit_entry_id, transport_name: row.transport_name,
            vehicle_number: row.vehicle_number,
            litres: f(row.litres), discount_amount: f(row.discount_amount),
            driver_name: row.driver_name, driver_phone_number: row.driver_phone_number,
            manager_name: row.manager_name, manager_phone_number: row.manager_phone_number,
            owner_name: row.owner_name, owner_phone_number: row.owner_phone_number,
          }
        end

        def lube_product(product)
          { product_id: product.id, name: product.display_name, unit_price: f(product.selling_price) }
        end

        def f(value)
          value.nil? ? nil : value.to_f
        end
      end
    end
  end
end
