module Settlement
  # Builds a pre-filled (unsaved) settlement draft for a pump/date/shift:
  # active nozzles with yesterday's closing auto-popped as today's opening
  # (business rule 1) and the catalog selling price snapshotted, plus the
  # same-day B2 discount lines (D3), the lube picklist (D2), and the cash
  # denomination grid (D7). Returns the option lists the "new" API/UI needs.
  class Builder
    Result = Struct.new(
      :settlement, :fuel_pump, :lube_products, :denominations, :existing,
      keyword_init: true
    )

    def self.call(...) = new(...).call

    # The business date a settlement defaults to when none was supplied.
    def self.default_business_date = Date.yesterday

    def initialize(user:, fuel_pump_id: nil, business_date: nil, shift_template_id: nil)
      @user = user
      # The business date has to be settled first: it decides which pump the
      # caller was on, and the pump in turn decides the opening readings and the
      # discount lines pulled into the draft.
      @business_date = parse_date(business_date)
      @fuel_pump = resolve_pump(fuel_pump_id)
      @shift_template_id = shift_template_id.presence
    end

    def call
      settlement = DailySettlement.new(
        fuel_pump: @fuel_pump,
        business_date: @business_date,
        shift_template_id: @shift_template_id,
        recorded_by: @user,
        fsm_name_snapshot: @user&.display_name
      )

      if @fuel_pump
        build_nozzle_readings(settlement)
        build_discount_lines(settlement)
      end

      Result.new(
        settlement: settlement,
        fuel_pump: @fuel_pump,
        lube_products: lube_products,
        denominations: SettlementCashDenomination::DENOMINATIONS,
        existing: existing_settlement
      )
    end

    private

    # The pump the caller was assigned ON the business date, falling back to their
    # standing default. Never today's one-day override: filing a late settlement
    # would otherwise pre-fill another pump's opening readings and pull that
    # pump's discount lines for the date.
    def resolve_pump(fuel_pump_id)
      pump = FuelPump.active.find_by(id: fuel_pump_id) if fuel_pump_id.present?
      pump ||= @user&.transaction_fuel_pump(on: @business_date)
      pump ||= @user&.assigned_fuel_pump
      pump if pump&.active?
    end

    # Staff record the day's transactions as they happen and settle the next
    # morning, so an unspecified business date means "yesterday", not today.
    def parse_date(value)
      return self.class.default_business_date if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      self.class.default_business_date
    end

    def existing_settlement
      return nil if @fuel_pump.nil?

      DailySettlement.find_by(
        fuel_pump: @fuel_pump,
        business_date: @business_date,
        shift_template_id: @shift_template_id
      )
    end

    def build_nozzle_readings(settlement)
      @fuel_pump.nozzles.active.ordered.each do |nozzle|
        prior = DailySettlement.prior_closing_reading(nozzle.id, @business_date)
        settlement.nozzle_readings.build(
          fuel_pump_nozzle: nozzle,
          fuel_type_code_snapshot: nozzle.fuel_type_code,
          opening_reading: prior,
          opening_source: prior.present? ? "prior_settlement" : "manual",
          unit_price: FuelPricing.current_price(nozzle.fuel_type_code)
        )
      end
    end

    # D3 — same-day captures for this pump that promised a discount.
    def build_discount_lines(settlement)
      VisitEntry
        .for_pump_day(@fuel_pump, @business_date)
        .where("discount_amount > 0")
        .order(:created_at)
        .each { |entry| settlement.discount_lines << SettlementDiscountLine.from_visit_entry(entry) }
    end

    def lube_products
      Product.active.where.not(category: Product::FUEL_CATEGORY).ordered.to_a
    end
  end
end
