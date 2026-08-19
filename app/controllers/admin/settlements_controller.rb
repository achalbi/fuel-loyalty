module Admin
  # D9 / Admin-12 / Admin-13 (+ G1) — the admin settlement console: list/filter
  # across pumps by date, pump, status and the FSM who recorded the sheet, with
  # cross-pump and per-FSM totals; view a settlement with its audit trail; edit
  # any current/past settlement on the FSM's behalf (mandatory change reason;
  # authorship never moves; loyalty points recompute on a customer-linked
  # change); reconcile; and record a fresh sheet ON BEHALF OF a named FSM who
  # could not settle themselves (new/create). Capturing one's OWN sheet is still
  # the FSM's job — see DailySettlementPolicy#create? / #create_on_behalf?.
  class SettlementsController < BaseController
    before_action :set_settlement, only: %i[show edit update reconcile]

    def index
      authorize DailySettlement, :admin_manage?
      @business_date = parse_date(params[:business_date])
      # Filter on the raw ids; the records are looked up only to label the page.
      # Narrowing on the record instead would silently DROP the filter when the
      # id has no row behind it (stale bookmark, deleted user) and list every
      # pump and every FSM while the selects still read "All" — where the same
      # id returns an empty list on the API. Applied verbatim, the two agree.
      @fuel_pump_id = params[:fuel_pump_id].presence
      @recorded_by_id = params[:recorded_by_id].presence
      # Only the FSM needs a record: they name the cross-pump card when the day
      # is narrowed to one recorder. A pump filter suppresses that card outright,
      # so there is nothing left to look a pump up for.
      @recorded_by = User.find_by(id: @recorded_by_id)
      # `:entered_by` because every row renders "entered by ‹admin›" when an
      # admin typed the sheet on the FSM's behalf; without it the list fires one
      # extra query per on-behalf row.
      scope = DailySettlement.recent_first.includes(:fuel_pump, :recorded_by, :entered_by)
      scope = scope.for_date(@business_date) if @business_date
      scope = scope.where(fuel_pump_id: @fuel_pump_id) if @fuel_pump_id
      scope = scope.recorded_by_user(@recorded_by_id) if @recorded_by_id
      scope = scope.where(status: params[:status]) if params[:status].present?
      @settlements = scope.to_a
      # "Across all pumps" means no pump filter was asked for at all — same rule
      # as the API's single_date_all_pumps?, on the raw id for the same reason.
      @cross_pump_totals = DailySettlement.totals_for(@settlements) if @business_date && @fuel_pump_id.blank?
      # Admin-12 — the same day split by the FSM who recorded each sheet, so
      # "the settlement report of the users for a particular day" is on the page.
      @per_fsm_totals = DailySettlement.per_recorder_totals(@settlements)
      @fsm_options = User.settlement_recorders.to_a
      @fuel_pumps = FuelPump.active.ordered.to_a
    end

    # GET /admin/settlements/new — staff feedback item 3, final part: an admin
    # records a sheet ON BEHALF OF a named FSM who could not (absent, sick, dead
    # device). Two steps on one page. Step 1 names the operator; step 2 is the
    # very same D1–D10 form the FSM would have seen, hydrated against THEIR pump
    # — their nozzles, their yesterday-closings, their pump's pulled discounts —
    # never the admin's. Nothing is hydrated before the pick, because every one
    # of those defaults depends on whose pump it is.
    def new
      authorize DailySettlement, :create_on_behalf?
      load_on_behalf_options
      @settlement = DailySettlement.new(business_date: @business_date)
      return if @recorded_for.nil?

      result = build_on_behalf_draft
      # The slot is taken. Correcting the sheet that is already there is the
      # audited path for it; creating would only collide with the unique index.
      if result.existing
        redirect_to edit_admin_settlement_path(result.existing),
          notice: "That pump and date already has a settlement — correcting it on #{@recorded_for.display_name}'s behalf instead."
        return
      end
      @settlement = result.settlement
      apply_form_options(result)
    end

    # POST /admin/settlements — save it. Attribution is never taken from the
    # form body: `Settlement::Persister` stamps `recorded_by` from the FSM
    # resolved here and `entered_by` from the signed-in admin, and writes the
    # audit row that an ordinary FSM create does not have. Same order of checks
    # as the JSON API: reason, then FSM, then the model.
    def create
      authorize DailySettlement, :create_on_behalf?
      load_on_behalf_options
      @settlement = DailySettlement.new
      return refuse_on_behalf("A reason for recording this on their behalf is required.") if params[:change_reason].blank?
      return refuse_on_behalf("Name the FSM this settlement is being recorded for.") if @recorded_for.nil?

      Settlement::Persister.call(
        settlement: @settlement, attributes: on_behalf_params, actor: current_user,
        recorded_for: @recorded_for, change_reason: params[:change_reason]
      )
      redirect_to admin_settlement_path(@settlement),
        notice: "Settlement #{@settlement.status} for #{@recorded_for.display_name} — recorded on their behalf and audited."
    rescue ActiveRecord::RecordInvalid => error
      # The duplicate-slot message is already on errors[:base]; so is every
      # model validation. Re-render with what was typed still in the fields.
      @settlement = error.record
      render_on_behalf_form
    end

    def show
      authorize @settlement, :admin_manage?
      @changes = @settlement.audit_changes.recent_first.includes(:changed_by).to_a
      # Framing (staff feedback item 3): the sheet belongs to the FSM who
      # recorded it; an admin only ever appears as the last corrector.
      @last_change = @changes.first
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
      apply_form_options(result, fuel_pump: @settlement.fuel_pump)
    end

    # The option lists + the fixed grid rows the shared staff form renders with
    # `fields_for`. Idempotent, so an error re-render keeps what was typed.
    def apply_form_options(result, fuel_pump: nil)
      @fuel_pump = fuel_pump || result.fuel_pump
      @lube_products = result.lube_products
      @denominations = result.denominations
      @fuel_products = Product.active.fuel.to_a
      Settlement::FormRows.prepare(@settlement, lube_products: @lube_products, fuel_products: @fuel_products)
    end

    # --- record on behalf of (staff feedback item 3) ---------------------

    # The PICKER list — active, non-soft-deleted operators of BOTH roles. It is
    # deliberately not `@fsm_options` from #index, which is the backward-looking
    # FILTER list built from settlements already on the books so a departed
    # operator's history stays findable. One looks forward, one looks back.
    def load_on_behalf_options
      @fsm_options = User.settlement_recorder_candidates.includes(:assigned_fuel_pump).to_a
      # Resolved through the picker's own list, so an id that is not on offer
      # (deactivated, soft-deleted, unknown) is refused rather than accepted.
      @recorded_for = @fsm_options.find { |user| user.id.to_s == params[:recorded_by_id].to_s }
      @fuel_pumps = FuelPump.active.ordered.to_a
      @business_date = parse_date(params[:business_date]) ||
        parse_date(params.dig(:settlement, :business_date)) ||
        Settlement::Builder.default_business_date
    end

    def build_on_behalf_draft
      Settlement::Builder.call(
        user: current_user, recorded_for: @recorded_for,
        fuel_pump_id: params[:fuel_pump_id], business_date: params[:business_date],
        shift_template_id: params[:shift_template_id]
      )
    end

    def refuse_on_behalf(message)
      @settlement.assign_attributes(on_behalf_params)
      @settlement.errors.add(:base, message)
      render_on_behalf_form
    end

    def render_on_behalf_form
      result = Settlement::Builder.call(
        user: current_user, recorded_for: @recorded_for,
        fuel_pump_id: @settlement.fuel_pump_id, business_date: @settlement.business_date
      )
      apply_form_options(result, fuel_pump: @settlement.fuel_pump)
      render :new, status: :unprocessable_entity
    end

    # A create defines the slot, so unlike the admin EDIT params it must carry
    # the pump, date and shift. `recorded_by_id`/`entered_by_id` stay out —
    # attribution is applied server-side from the resolved FSM and the signed-in
    # admin, so a hand-rolled POST cannot stamp a sheet as somebody else's.
    def on_behalf_params
      @on_behalf_params ||= params.fetch(:settlement, ActionController::Parameters.new).permit(
        :fuel_pump_id, :business_date, :shift_template_id, :status, :notes,
        nozzle_readings_attributes: %i[id fuel_pump_nozzle_id opening_reading closing_reading testing_litres rollover opening_source _destroy],
        lube_lines_attributes: %i[id product_id quantity opening_stock closing_stock _destroy],
        discount_lines_attributes: %i[id visit_entry_id transport_name litres discount_amount driver_name driver_phone_number manager_name manager_phone_number owner_name owner_phone_number _destroy],
        credit_lines_attributes: %i[id credit_type litres discount_amount amount reference note _destroy],
        cash_denominations_attributes: %i[id denomination quantity _destroy],
        digital_receipts_attributes: %i[id label amount _destroy],
        expense_lines_attributes: %i[id description amount _destroy],
        stock_receipts_attributes: %i[id fuel_type_code litres_received _destroy],
        decantations_attributes: %i[id fuel_type_code tank_label opening_kl closing_kl _destroy],
        rate_comparisons_attributes: %i[id fuel_type_code competitor_name competitor_price own_price _destroy]
      )
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
