module Settlement
  # Builds a pre-filled (unsaved) settlement draft for a pump/date/shift:
  # active nozzles with yesterday's closing auto-popped as today's opening
  # (business rule 1) and the catalog selling price snapshotted, plus the
  # same-day B2 discount lines (D3), the lube picklist (D2), and the cash
  # denomination grid (D7). Returns the option lists the "new" API/UI needs.
  class Builder
    Result = Struct.new(
      :settlement, :fuel_pump, :lube_products, :denominations, :existing, :recorded_for,
      keyword_init: true
    )

    def self.call(...) = new(...).call

    # The business date a settlement defaults to when none was supplied.
    def self.default_business_date = Date.yesterday

    # `user` is who is driving the form; `recorded_for` is who the sheet belongs
    # to. They are the same person for an FSM capturing their own settlement —
    # which is every caller that omits `recorded_for`, so existing behaviour is
    # unchanged. They differ only in the admin "record on behalf of" flow (staff
    # feedback item 3), and there EVERY default has to resolve against the FSM,
    # not the admin: their pump, and therefore their nozzles, their nozzles'
    # yesterday-closing readings, and their pump's same-day discount lines. An
    # admin's own pump assignment must never leak into a sheet attributed to
    # someone else.
    def initialize(user:, fuel_pump_id: nil, business_date: nil, shift_template_id: nil, recorded_for: nil)
      @user = user
      @recorded_for = recorded_for || user
      # Date first: the pump has to resolve against the BUSINESS date, not today.
      # A settlement is filed the morning after (and an on-behalf one later still),
      # and `User#transaction_fuel_pump` reads the dated assignment for the day —
      # so resolving on Date.current would post the sheet to whatever pump the FSM
      # stands now and pull that pump's opening readings, corrupting the day's math.
      @business_date = parse_date(business_date)
      @fuel_pump = resolve_pump(fuel_pump_id)
      @shift_template_id = shift_template_id.presence
    end

    def call
      settlement = DailySettlement.new(
        fuel_pump: @fuel_pump,
        business_date: @business_date,
        shift_template_id: @shift_template_id,
        recorded_by: @recorded_for,
        fsm_name_snapshot: @recorded_for&.display_name
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
        existing: existing_settlement,
        recorded_for: @recorded_for
      )
    end

    private

    # An explicit pump wins; otherwise fall back to the pump of the person the
    # sheet is FOR (which is the caller themselves in the ordinary FSM flow).
    def resolve_pump(fuel_pump_id)
      pump = FuelPump.active.find_by(id: fuel_pump_id) if fuel_pump_id.present?
      pump || dated_pump || @recorded_for&.transaction_fuel_pump
    end

    # The pump they were actually posted to on the BUSINESS date, which is what a
    # late-filed sheet must be built from — a settlement is written the morning
    # after, and an on-behalf one later still, so "today" is the wrong question.
    # Falls through to `transaction_fuel_pump` (their standing pump) when no dated
    # override exists for that day; note that method deliberately restricts the
    # standing pump to today, so it cannot serve as the dated lookup itself.
    def dated_pump
      pump = @recorded_for&.pump_assignment_for(on: @business_date)&.fuel_pump
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
