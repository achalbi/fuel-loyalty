module Admin
  # D9 / Admin-12 / Admin-13 (+ G1) — the admin settlement console: list/filter
  # across pumps and staff with cross-pump + per-FSM totals, view a settlement
  # with its audit trail, edit any current/past settlement (mandatory change
  # reason, recorded against the FSM it was entered for; loyalty points recompute
  # on a customer-linked change), and reconcile.
  class SettlementsController < BaseController
    ON_BEHALF_OF_REQUIRED_MESSAGE =
      "Select the staff member this settlement is being entered on behalf of.".freeze

    FINANCIAL_FIELDS = %i[total_fuel_amount total_lube_amount total_discount_amount total_credit_amount
                          final_amount_to_settle counted_cash_amount shortage_amount].freeze

    before_action :set_settlement, only: %i[show edit update reconcile]

    def index
      authorize DailySettlement, :admin_manage?
      @business_date = parse_date(params[:business_date])
      @fuel_pump = FuelPump.find_by(id: params[:fuel_pump_id])
      # Not scoped to `kept`: a soft-deleted FSM still owns their history, and the
      # rollup row below links straight to this filter.
      @staff_member = User.find_by(id: params[:user_id])
      scope = DailySettlement.recent_first.includes(:fuel_pump, :recorded_by)
      scope = scope.for_date(@business_date) if @business_date
      scope = scope.where(fuel_pump_id: @fuel_pump.id) if @fuel_pump
      scope = scope.where(recorded_by_id: @staff_member.id) if @staff_member
      scope = scope.where(status: params[:status]) if params[:status].present?
      @settlements = scope.to_a
      @cross_pump_totals = cross_pump_totals(@settlements) if @business_date && @fuel_pump.nil?
      # Admin-12: "the settlement reports of the users for a particular day" —
      # one row per FSM who recorded a settlement in the current filter.
      @per_user_totals = per_user_totals(@settlements)
      @fuel_pumps = FuelPump.active.ordered.to_a
      @staff_members = settlement_recorders
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
      # Admin-12: an admin edits only *for* someone — the FSM who could not do it
      # themselves — so the audit row always names them.
      if on_behalf_of.nil?
        @settlement.errors.add(:base, ON_BEHALF_OF_REQUIRED_MESSAGE)
        hydrate_form
        return render :edit, status: :unprocessable_entity
      end
      Settlement::Persister.call(
        settlement: @settlement, attributes: settlement_params, actor: current_user,
        admin_edit: true, change_reason: params[:change_reason], on_behalf_of: on_behalf_of
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

    # The FSM this edit is being made for. Never the admin doing it — naming
    # yourself is exactly what Admin-12 rules out.
    def on_behalf_of
      return @on_behalf_of if defined?(@on_behalf_of)

      requested = params[:on_behalf_of_id].to_s
      @on_behalf_of = assignable_staff.find { |staff_member| staff_member.id.to_s == requested }
    end

    def hydrate_form
      result = Settlement::Builder.call(user: current_user, fuel_pump_id: @settlement.fuel_pump_id, business_date: @settlement.business_date)
      @fuel_pump = @settlement.fuel_pump
      @lube_products = result.lube_products
      @denominations = result.denominations
      @fuel_products = Product.active.fuel.to_a
      @on_behalf_of_options = assignable_staff
      Settlement::FormRows.prepare(@settlement, lube_products: @lube_products, fuel_products: @fuel_products)
    end

    # Filter list: everyone who could own a settlement row on this screen — current
    # staff plus anyone who has already recorded one, including a since-deleted or
    # since-promoted user, so no rollup row is unreachable by its own filter link.
    def settlement_recorders
      User.where(id: DailySettlement.select(:recorded_by_id))
        .or(User.kept.where(role: :staff))
        .order(active: :desc)
        .order(:name, :username)
        .to_a
    end

    # Form list: the staff members an admin may act for — everyone who still has
    # an account, plus whoever already owns this settlement (so a legacy row whose
    # recorder was later promoted stays selectable), minus the admin themselves.
    def assignable_staff
      return @assignable_staff if defined?(@assignable_staff)

      scope = User.kept.where(role: :staff)
      scope = scope.or(User.kept.where(id: @settlement.recorded_by_id)) if @settlement&.recorded_by_id
      @assignable_staff = scope.where.not(id: current_user.id)
        .order(active: :desc).order(:name, :username).to_a
    end

    def per_user_totals(rows)
      rows.group_by(&:recorded_by_id).map do |_user_id, user_rows|
        settlement = user_rows.first
        financial, drafts = user_rows.partition { |row| row.submitted? || row.reconciled? }
        {
          user: settlement.recorded_by,
          name: settlement.recorded_by&.display_name || settlement.fsm_name_snapshot.presence || "Unknown",
          # Counts only what the money columns cover, so the row cannot contradict
          # its own caption; drafts are reported separately.
          count: financial.size,
          drafts: drafts.size,
          pumps: user_rows.filter_map { |row| row.fuel_pump&.display_name }.uniq.sort,
          totals: financial_totals(financial),
        }
      end.sort_by { |row| row[:name].to_s }
    end

    def cross_pump_totals(rows)
      financial_totals(rows)
    end

    # Only submitted/reconciled rows carry money worth summing; drafts are still
    # being typed.
    def financial_totals(rows)
      financial = rows.select { |s| s.submitted? || s.reconciled? }
      FINANCIAL_FIELDS.index_with { |field| financial.sum { |s| s.public_send(field).to_d } }
    end

    def settlement_params
      params.require(:settlement).permit(
        :notes, :status,
        nozzle_readings_attributes: %i[id fuel_pump_nozzle_id opening_reading closing_reading testing_litres rollover _destroy],
        lube_lines_attributes: %i[id product_id quantity opening_stock closing_stock _destroy],
        discount_lines_attributes: %i[id visit_entry_id transport_name litres discount_amount _destroy],
        credit_lines_attributes: %i[id credit_type litres discount_amount amount reference note _destroy],
        cash_denominations_attributes: %i[id denomination quantity _destroy],
        digital_receipts_attributes: %i[id label amount _destroy],
        expense_lines_attributes: %i[id description amount _destroy],
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
