module Admin
  # D9 / Admin-12 / Admin-13 (+ G1) — the admin settlement console: list/filter
  # across pumps with cross-pump totals, view a settlement with its audit trail,
  # edit any current/past settlement (mandatory change reason; loyalty points
  # recompute on a customer-linked change), and reconcile.
  class SettlementsController < BaseController
    before_action :set_settlement, only: %i[show edit update reconcile]

    def index
      authorize DailySettlement, :admin_manage?
      @business_date = parse_date(params[:business_date])
      @fuel_pump = FuelPump.find_by(id: params[:fuel_pump_id])
      scope = DailySettlement.recent_first.includes(:fuel_pump)
      scope = scope.for_date(@business_date) if @business_date
      scope = scope.where(fuel_pump_id: @fuel_pump.id) if @fuel_pump
      scope = scope.where(status: params[:status]) if params[:status].present?
      @settlements = scope.to_a
      @cross_pump_totals = cross_pump_totals(@settlements) if @business_date && @fuel_pump.nil?
      @fuel_pumps = FuelPump.active.ordered.to_a
    end

    def show
      authorize @settlement, :admin_manage?
      @changes = @settlement.audit_changes.recent_first.to_a
    end

    def edit
      authorize @settlement, :admin_manage?
      hydrate_form
    end

    def update
      authorize @settlement, :admin_manage?
      if params[:change_reason].blank?
        @settlement.errors.add(:base, "A reason for the change is required.")
        hydrate_form
        return render :edit, status: :unprocessable_entity
      end
      Settlement::Persister.call(
        settlement: @settlement, attributes: settlement_params, actor: current_user,
        admin_edit: true, change_reason: params[:change_reason]
      )
      redirect_to admin_settlement_path(@settlement), notice: "Settlement updated and audited."
    rescue ActiveRecord::RecordInvalid => error
      @settlement = error.record
      hydrate_form
      render :edit, status: :unprocessable_entity
    end

    def reconcile
      authorize @settlement, :reconcile?
      Settlement::Persister.call(
        settlement: @settlement, attributes: { status: "reconciled" }, actor: current_user,
        admin_edit: true, change_reason: params[:change_reason].presence || "Reconciled"
      )
      redirect_to admin_settlement_path(@settlement), notice: "Settlement reconciled and locked."
    end

    private

    def set_settlement
      @settlement = DailySettlement.find(params[:id])
    end

    def hydrate_form
      result = Settlement::Builder.call(user: current_user, fuel_pump_id: @settlement.fuel_pump_id, business_date: @settlement.business_date)
      @fuel_pump = @settlement.fuel_pump
      @lube_products = result.lube_products
      @denominations = result.denominations
      @fuel_products = Product.active.fuel.to_a
      Settlement::FormRows.prepare(@settlement, lube_products: @lube_products, fuel_products: @fuel_products)
    end

    def cross_pump_totals(rows)
      financial = rows.select { |s| s.submitted? || s.reconciled? }
      %i[total_fuel_amount total_lube_amount total_discount_amount total_credit_amount
         final_amount_to_settle counted_cash_amount shortage_amount]
        .index_with { |field| financial.sum { |s| s.public_send(field).to_d } }
    end

    def settlement_params
      params.require(:settlement).permit(
        :phonepe_pos_amount, :phonepe_scanner_amount, :notes, :status,
        nozzle_readings_attributes: %i[id fuel_pump_nozzle_id opening_reading closing_reading testing_litres rollover _destroy],
        lube_lines_attributes: %i[id product_id quantity opening_stock closing_stock _destroy],
        discount_lines_attributes: %i[id visit_entry_id transport_name litres discount_amount _destroy],
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
