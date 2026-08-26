module Staff
  # D1–D10 — the FSM shift-end Daily Settlement (web). The form mirrors the
  # settlement sheet; ₹ is derived from the catalog (LOCKED Q1) and recomputed
  # server-side on submit. See docs/acefuels/12-spec-daily-settlement.md.
  #
  # Admins reach this same flow. Admin-12 says an admin should not be entering
  # settlement data as himself, so when the actor is an admin the settlement must
  # name the FSM it is being entered for; `entered_by` keeps the admin on record.
  class SettlementsController < BaseController
    ON_BEHALF_OF_REQUIRED_MESSAGE =
      "Select the staff member this settlement is being entered on behalf of.".freeze

    before_action :set_settlement, only: %i[show edit update]
    before_action :ensure_editable_settlement, only: %i[edit update]

    def index
      authorize DailySettlement, :index?
      @business_date = parse_date(params[:business_date])
      @fuel_pump = FuelPump.find_by(id: params[:fuel_pump_id])
      scope = viewable_settlements.recent_first.includes(:fuel_pump, :recorded_by)
      scope = scope.for_date(@business_date) if @business_date
      scope = scope.where(fuel_pump_id: @fuel_pump.id) if @fuel_pump
      @settlements = scope.to_a
      @fuel_pumps = FuelPump.active.ordered.to_a
    end

    def new
      authorize DailySettlement, :new?
      result = build_draft
      if result.existing
        redirect_to edit_existing_settlement_path(result.existing),
          notice: "A settlement already exists for that pump and date — editing it."
        return
      end
      @settlement = result.settlement
      hydrate_form(result)
    end

    def create
      authorize DailySettlement, :create?
      @settlement = DailySettlement.new
      return render_missing_on_behalf_of(:new) if on_behalf_of_missing?

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

    # Only an admin may file a settlement under someone else's name, and only
    # under a *staff member's* — naming himself would be the very thing Admin-12
    # rules out. A staff member's own settlement is always their own.
    def assignable_recorders
      return [] unless current_user.admin?

      User.kept.where(role: :staff).where.not(id: current_user.id)
        .order(active: :desc).order(:name, :username).to_a
    end
    helper_method :assignable_recorders

    def on_behalf_of_missing?
      return false unless current_user.admin?

      assignable_recorders.none? { |staff_member| staff_member.id.to_s == params.dig(:settlement, :recorded_by_id).to_s }
    end

    def render_missing_on_behalf_of(template)
      @settlement.assign_attributes(settlement_params)
      @settlement.errors.add(:base, ON_BEHALF_OF_REQUIRED_MESSAGE)
      hydrate_form(Settlement::Builder.call(user: current_user, fuel_pump_id: @settlement.fuel_pump_id, business_date: @settlement.business_date))
      render template, status: :unprocessable_entity
    end

    # An FSM needs to read the day's sheet for their own pump — including the
    # shift a colleague recorded (staff feedback item 6) — but may still only
    # edit their own. Admins read everything here; what they may edit is decided
    # by `editable_settlements` below, not by this scope.
    def viewable_settlements
      return DailySettlement.all if current_user.admin?

      DailySettlement
        .where(recorded_by: current_user)
        .or(DailySettlement.where(fuel_pump_id: current_user.settlement_pump_ids))
    end

    # An admin has no editable set here. This flow calls the Persister without
    # `admin_edit:`, so it writes no `settlement_changes` row — an admin editing
    # through it would rewrite an FSM's figures with no audit trail and no
    # mandatory reason. Every admin edit of a recorded sheet belongs in the D9
    # console (`Admin::SettlementsController`), which demands both. Filing a sheet
    # *for* an FSM (create, Admin-12) is untouched — only editing one moves.
    def editable_settlements
      return DailySettlement.none if current_user.admin?

      DailySettlement.where(recorded_by: current_user)
    end

    def set_settlement
      @settlement = viewable_settlements.find(params[:id])
    end

    # Someone else's settlement is readable but not writable; say so instead of
    # 404-ing on a record the FSM can plainly see in their list. An admin is not
    # turned away — they are handed the same sheet in the audited console, so
    # they never lose track of which settlement they came for.
    def ensure_editable_settlement
      return if editable_settlements.exists?(id: @settlement.id)

      if current_user.admin?
        redirect_to edit_admin_settlement_path(@settlement),
          notice: "Admin edits are recorded — this settlement opens in the audited admin console."
        return
      end

      redirect_to staff_settlement_path(@settlement),
        alert: "#{@settlement.fsm_name_snapshot.presence || 'Another operator'} recorded this settlement — you can view it but not edit it."
    end

    # Where "edit this existing sheet" leads, for whoever is asking: an FSM edits
    # their own in place, an admin goes to the audited console (see
    # `editable_settlements`). Shared with the views so an Edit control on this
    # side can never point somewhere the actor is bounced out of.
    def edit_existing_settlement_path(settlement)
      return edit_admin_settlement_path(settlement) if current_user.admin?

      edit_staff_settlement_path(settlement)
    end
    helper_method :edit_existing_settlement_path

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
      permitted = params.require(:settlement).permit(
        :fuel_pump_id, :business_date, :shift_template_id, :status,
        :notes,
        nozzle_readings_attributes: %i[id fuel_pump_nozzle_id opening_reading closing_reading testing_litres rollover _destroy],
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
      # Who a settlement belongs to is decided once, when it is created. An admin
      # may name the FSM then; nothing may re-point an existing settlement at a
      # different user, which would move money between people with no audit row.
      recorded_by_id = params.dig(:settlement, :recorded_by_id)
      if current_user.admin? && action_name == "create" && recorded_by_id.present?
        permitted[:recorded_by_id] = recorded_by_id
      end
      permitted
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
