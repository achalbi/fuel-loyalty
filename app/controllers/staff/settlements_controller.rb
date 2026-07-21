module Staff
  # D1–D10 — the FSM shift-end Daily Settlement (web). The form mirrors the
  # settlement sheet; ₹ is derived from the catalog (LOCKED Q1) and recomputed
  # server-side on submit. See docs/acefuels/12-spec-daily-settlement.md.
  class SettlementsController < BaseController
    before_action :set_settlement, only: %i[show edit update]

    def index
      authorize DailySettlement, :index?
      @business_date = parse_date(params[:business_date])
      @fuel_pump = FuelPump.find_by(id: params[:fuel_pump_id])
      scope = accessible_settlements.recent_first.includes(:fuel_pump)
      scope = scope.for_date(@business_date) if @business_date
      scope = scope.where(fuel_pump_id: @fuel_pump.id) if @fuel_pump
      @settlements = scope.to_a
      @fuel_pumps = FuelPump.active.ordered.to_a
    end

    def new
      authorize DailySettlement, :new?
      result = build_draft
      if result.existing
        redirect_to edit_staff_settlement_path(result.existing),
          notice: "A settlement already exists for that pump and date — editing it."
        return
      end
      @settlement = result.settlement
      hydrate_form(result)
    end

    def create
      authorize DailySettlement, :create?
      @settlement = DailySettlement.new
      Settlement::Persister.call(settlement: @settlement, attributes: settlement_params, actor: current_user)
      redirect_to staff_settlement_path(@settlement), notice: settlement_saved_notice(@settlement)
    rescue ActiveRecord::RecordInvalid => error
      @settlement = error.record
      hydrate_form(Settlement::Builder.call(user: current_user, fuel_pump_id: @settlement.fuel_pump_id, business_date: @settlement.business_date))
      render :new, status: :unprocessable_entity
    end

    def show
      authorize @settlement, :show?
    end

    def edit
      authorize @settlement, :update?
      if @settlement.locked?
        redirect_to staff_settlement_path(@settlement), alert: "This settlement is locked and can no longer be edited."
        return
      end
      hydrate_form(Settlement::Builder.call(user: current_user, fuel_pump_id: @settlement.fuel_pump_id, business_date: @settlement.business_date))
    end

    def update
      authorize @settlement, :update?
      if @settlement.locked?
        redirect_to staff_settlement_path(@settlement), alert: "This settlement is locked and can no longer be edited."
        return
      end
      Settlement::Persister.call(settlement: @settlement, attributes: settlement_params, actor: current_user)
      redirect_to staff_settlement_path(@settlement), notice: settlement_saved_notice(@settlement)
    rescue ActiveRecord::RecordInvalid => error
      @settlement = error.record
      hydrate_form(Settlement::Builder.call(user: current_user, fuel_pump_id: @settlement.fuel_pump_id, business_date: @settlement.business_date))
      render :edit, status: :unprocessable_entity
    end

    private

    def accessible_settlements
      current_user.admin? ? DailySettlement.all : DailySettlement.where(recorded_by: current_user)
    end

    def set_settlement
      @settlement = accessible_settlements.find(params[:id])
    end

    def build_draft
      Settlement::Builder.call(
        user: current_user,
        fuel_pump_id: params[:fuel_pump_id],
        business_date: params[:business_date],
        shift_template_id: params[:shift_template_id]
      )
    end

    # Prepare the option lists + pre-build the fixed grid rows (lubes,
    # denominations, per-fuel rate/stock, blank credit/decantation rows) so the
    # server-rendered fields_for has stable rows; empties are dropped by reject_if.
    def hydrate_form(result)
      @fuel_pump = result.fuel_pump
      @lube_products = result.lube_products
      @denominations = result.denominations
      @fuel_products = Product.active.fuel.to_a
      Settlement::FormRows.prepare(@settlement, lube_products: @lube_products, fuel_products: @fuel_products)
    end

    def settlement_saved_notice(settlement)
      "Settlement #{settlement.status} for #{settlement.fuel_pump&.display_name} on #{settlement.business_date}."
    end

    def settlement_params
      params.require(:settlement).permit(
        :fuel_pump_id, :business_date, :shift_template_id, :status,
        :phonepe_pos_amount, :phonepe_scanner_amount, :notes,
        nozzle_readings_attributes: %i[id fuel_pump_nozzle_id opening_reading closing_reading testing_litres rollover opening_source _destroy],
        lube_lines_attributes: %i[id product_id quantity opening_stock closing_stock _destroy],
        discount_lines_attributes: %i[id visit_entry_id transport_name litres discount_amount driver_name driver_phone_number manager_name manager_phone_number owner_name owner_phone_number _destroy],
        credit_lines_attributes: %i[id credit_type litres discount_amount amount reference note _destroy],
        cash_denominations_attributes: %i[id denomination quantity _destroy],
        stock_receipts_attributes: %i[id fuel_type_code litres_received _destroy],
        decantations_attributes: %i[id fuel_type_code tank_label opening_kl closing_kl _destroy],
        rate_comparisons_attributes: %i[id fuel_type_code competitor_name competitor_price own_price _destroy]
      )
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
