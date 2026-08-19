module Api
  module V1
    module Admin
      # D9 / Admin-12 / Admin-13 — the admin settlement console: list/filter
      # across pumps by date, pump, status and the FSM who recorded the sheet,
      # with cross-pump and per-FSM totals; read one with its audit trail; edit
      # any current/past settlement on the FSM's behalf (change_reason required;
      # authorship never moves; points recompute on a customer-linked change);
      # record a fresh sheet on behalf of a named FSM who could not (new/create);
      # and reconcile.
      class SettlementsController < Api::V1::Admin::BaseController
        before_action :set_settlement, only: %i[show update reconcile]

        # An on-behalf sheet is not parked in `draft` waiting for the FSM to
        # submit it: the whole premise is that they cannot act (absent, sick,
        # dead device), so the admin submits it directly. A client that really
        # does want to park one passes `status: "draft"` explicitly.
        DEFAULT_ON_BEHALF_STATUS = "submitted".freeze

        # GET /api/v1/admin/settlements?business_date=&from=&to=&fuel_pump_id=&status=&recorded_by_id=
        def index
          authorize DailySettlement, :admin_manage?
          scope = filtered_scope
          rows = scope.to_a
          body = {
            settlements: rows.map { |s| Api::V1::Staff::SettlementSerializer.summary(s) },
            total: rows.size,
            # Admin-12 — the day split per FSM, plus the option list the native
            # "recorded by" FILTER needs: users who already have sheets on the
            # books (admins included — see User.settlement_recorders), so a
            # departed operator's history stays findable. Not the same list as
            # the `new` action's picker, which is forward-looking.
            per_fsm_totals: per_fsm_totals(rows),
            fsm_options: User.settlement_recorders.map { |user| { id: user.id, name: user.display_name } },
            # Which recorder the rows were narrowed to, or null. `cross_pump_totals`
            # below spans every pump but only the FSM named here, so a client that
            # renders it must qualify the label — the web heading appends
            # "· ‹FSM› only" and the native card does the same.
            filtered_by: filtered_by,
          }
          body[:cross_pump_totals] = cross_pump_totals(rows) if single_date_all_pumps?
          render json: body, status: :ok
        end

        # GET /api/v1/admin/settlements/new?recorded_by_id=&fuel_pump_id=&business_date=&shift_template_id=
        #
        # Staff feedback item 3 — hydration for "record on behalf of". Two jobs
        # in one call so the picker screen needs no second round trip: the list
        # of operators a sheet may be attributed to, and (once one is picked)
        # the same pre-filled draft the FSM would have seen — resolved against
        # THEIR pump, not the admin's.
        def new
          authorize DailySettlement, :create_on_behalf?
          return render_unknown_recorded_by if recorded_for_param.present? && recorded_for.nil?

          render json: draft_payload, status: :ok
        end

        # POST /api/v1/admin/settlements — record on behalf of a named FSM.
        #
        # `recorded_by_id` (the FSM) and `change_reason` are both required, and
        # neither lives in the settlement body: attribution is applied by the
        # persister from the resolved user, so a client cannot post itself into
        # `recorded_by_id`/`entered_by_id`. The saved sheet is the FSM's;
        # `entered_by` is this admin; a settlement_changes row records the
        # create.
        def create
          authorize DailySettlement, :create_on_behalf?
          return render_missing_reason if change_reason.blank?
          return render_missing_recorded_by if recorded_for_param.blank?
          return render_unknown_recorded_by if recorded_for.nil?

          duplicate = duplicate_settlement
          return render_settlement_exists(duplicate) if duplicate

          result = Settlement::Persister.call(
            settlement: DailySettlement.new, attributes: on_behalf_params, actor: current_user,
            recorded_for: recorded_for, change_reason: change_reason
          )
          render json: settlement_json(result.settlement), status: :created
        end

        # GET /api/v1/admin/settlements/:id — full settlement + audit trail.
        def show
          authorize @settlement, :admin_manage?
          render json: settlement_json(@settlement), status: :ok
        end

        # PATCH /api/v1/admin/settlements/:id — edit; change_reason required.
        def update
          authorize @settlement, :admin_manage?
          return render_missing_reason if change_reason.blank?

          result = Settlement::Persister.call(
            settlement: @settlement, attributes: settlement_params, actor: current_user,
            admin_edit: true, change_reason: change_reason
          )
          render json: settlement_json(result.settlement).merge(points_recomputed: result.points_recomputed), status: :ok
        end

        # PATCH /api/v1/admin/settlements/:id/reconcile
        def reconcile
          authorize @settlement, :reconcile?
          Settlement::Persister.call(
            settlement: @settlement, attributes: { status: "reconciled" }, actor: current_user,
            admin_edit: true, change_reason: change_reason.presence || "Reconciled"
          )
          render json: settlement_json(@settlement), status: :ok
        end

        # GET /api/v1/admin/settlements/summary?fuel_pump_id=&from=&to=
        def summary
          authorize DailySettlement, :admin_manage?
          scope = DailySettlement.financial.includes(:fuel_pump)
          scope = scope.where(fuel_pump_id: params[:fuel_pump_id]) if params[:fuel_pump_id].present?
          scope = scope.where(business_date: date_range) if date_range
          series = scope.recent_first.map do |s|
            {
              business_date: s.business_date.iso8601, fuel_pump: s.fuel_pump&.display_name,
              total_fuel_amount: s.total_fuel_amount.to_f, final_amount_to_settle: s.final_amount_to_settle.to_f,
              shortage_amount: s.shortage_amount.to_f,
            }
          end
          render json: { series: series }, status: :ok
        end

        private

        def set_settlement
          @settlement = DailySettlement.find(params[:id])
        end

        # --- record on behalf of (staff feedback item 3) ---------------------

        # The FSM the sheet is for. Canonically top level (like `change_reason`),
        # but also accepted inside the settlement body so a client that keeps
        # everything in one object does not have to split it out.
        def recorded_for_param
          params[:recorded_by_id].presence || nested_recorded_by_id
        end

        def nested_recorded_by_id
          nested = params[:settlement]
          return nil unless nested.is_a?(ActionController::Parameters)

          nested[:recorded_by_id].presence
        end

        # Resolved through the picker's own scope, so an id that is not offered
        # (soft-deleted, deactivated) is refused rather than quietly accepted.
        def recorded_for
          return @recorded_for if defined?(@recorded_for)

          @recorded_for = fsm_option_scope.find_by(id: recorded_for_param)
        end

        # Admins as well as staff — an admin does stand a shift on a small site,
        # and admin-recorded sheets already exist in the data (see
        # User.settlement_recorder_candidates).
        def fsm_option_scope
          User.settlement_recorder_candidates
        end

        def draft_payload
          {
            fsm_options: fsm_option_scope.includes(:assigned_fuel_pump).map { |user| fsm_option(user) },
            # Who the client should show as the enterer on the form it is about
            # to submit — this admin.
            entered_by: user_ref(current_user),
            recorded_for: recorded_for && user_ref(recorded_for),
            # Null until an FSM is named: the nozzles, the yesterday-closing
            # readings and the pulled discounts all depend on whose pump it is,
            # so there is nothing to hydrate before the pick.
            draft: recorded_for && Api::V1::Staff::SettlementDraftSerializer.call(build_draft),
          }
        end

        # `default_fuel_pump_*` is the operator's STANDING assignment, a label
        # for the picker row only. The pump a sheet is actually built against is
        # `draft.fuel_pump`, which honours a dated override for the business
        # date; the two can differ.
        def fsm_option(user)
          {
            id: user.id,
            name: user.display_name,
            role: user.role,
            default_fuel_pump_id: user.assigned_fuel_pump&.id,
            default_fuel_pump: user.assigned_fuel_pump&.display_name,
          }
        end

        def user_ref(user)
          { id: user.id, name: user.display_name }
        end

        # Everything defaults against the FSM, not the admin driving the form.
        def build_draft
          Settlement::Builder.call(
            user: current_user,
            recorded_for: recorded_for,
            fuel_pump_id: params[:fuel_pump_id],
            business_date: params[:business_date],
            shift_template_id: params[:shift_template_id]
          )
        end

        # (pump, date, shift) is unique. Check before saving so a slot that is
        # already settled comes back as a 409 naming the sheet to open instead
        # of a bare validation blob — the model validation and the unique index
        # still backstop a race (422 / 409 respectively).
        def duplicate_settlement
          fuel_pump_id = on_behalf_params[:fuel_pump_id].presence
          business_date = parse_date(on_behalf_params[:business_date])
          return nil if fuel_pump_id.blank? || business_date.nil?

          DailySettlement.find_by(
            fuel_pump_id: fuel_pump_id,
            business_date: business_date,
            shift_template_id: on_behalf_params[:shift_template_id].presence
          )
        end

        def on_behalf_params
          @on_behalf_params ||= begin
            attrs = settlement_create_params
            attrs[:status] = DEFAULT_ON_BEHALF_STATUS if attrs[:status].blank?
            attrs
          end
        end

        # Unlike the admin EDIT params, a create must carry the pump, date and
        # shift — it is defining the slot. `recorded_by_id`/`entered_by_id` stay
        # out: attribution is server-side, from the resolved FSM and the
        # authenticated admin.
        def settlement_create_params
          params.require(:settlement).permit(
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

        def render_missing_recorded_by
          render_error(status: 422, code: "recorded_by_required",
                       message: "Name the FSM this settlement is being recorded for.")
        end

        def render_unknown_recorded_by
          render_error(status: 422, code: "recorded_by_invalid",
                       message: "That operator cannot be selected — pick one from the FSM list.")
        end

        def render_settlement_exists(settlement)
          render_error(
            status: :conflict, code: "settlement_exists",
            message: "A settlement has already been recorded for this pump, date and shift.",
            details: { existing_settlement_id: settlement.id }
          )
        end

        # --- read side -------------------------------------------------------

        def filtered_scope
          scope = DailySettlement.recent_first.includes(:fuel_pump, :recorded_by, :entered_by)
          scope = scope.for_date(parse_date(params[:business_date])) if params[:business_date].present?
          scope = scope.where(business_date: date_range) if date_range
          scope = scope.where(fuel_pump_id: params[:fuel_pump_id]) if params[:fuel_pump_id].present?
          scope = scope.recorded_by_user(recorded_by_param) if recorded_by_param
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope
        end

        # A pump filter suppresses the cross-pump block outright; a recorder
        # filter deliberately does not — one FSM's day across every pump is
        # worth having, and `filtered_by` above tells the client to label it as
        # theirs. The web index applies the same two rules.
        def single_date_all_pumps?
          params[:business_date].present? && params[:fuel_pump_id].blank?
        end

        # The raw filter value, applied verbatim so an id with no user behind it
        # (stale bookmark, deleted account) narrows the list to nothing here
        # exactly as it does on the web — see Admin::SettlementsController#index.
        def recorded_by_param
          params[:recorded_by_id].presence
        end

        # Echo the applied recorder filter back so a client can qualify the
        # totals it renders. Null iff no filter was applied — the object's
        # presence, not the id inside it, is the signal: an id nobody has still
        # narrowed the list to nothing, and a card over those rows must not
        # claim to be the whole day. The id is echoed as an integer so clients
        # can type it; fsm_name is null when no user matches it.
        def filtered_by
          return nil if recorded_by_param.nil?

          {
            recorded_by_id: ActiveModel::Type::Integer.new.cast(recorded_by_param),
            fsm_name: User.find_by(id: recorded_by_param)&.display_name,
          }
        end

        # Admin-13: sum the day's financial (submitted/reconciled) settlements.
        def cross_pump_totals(rows)
          DailySettlement.totals_for(rows).transform_values(&:to_f)
        end

        # Admin-12: the same rollup per recorder. Money is rendered as floats to
        # match the rest of the payload.
        def per_fsm_totals(rows)
          DailySettlement.per_recorder_totals(rows).map do |row|
            row.merge(totals: row[:totals].transform_values(&:to_f))
          end
        end

        def settlement_json(settlement)
          Api::V1::Staff::SettlementSerializer.call(settlement).merge(
            changes: settlement.audit_changes.recent_first.map { |c| Api::V1::Admin::SettlementChangeSerializer.call(c) }
          )
        end

        def render_missing_reason
          render_error(status: 422, code: "change_reason_required",
                       message: "A reason for the change is required.")
        end

        def change_reason
          params[:change_reason]
        end

        def date_range
          return nil if params[:from].blank? || params[:to].blank?

          from = parse_date(params[:from])
          to = parse_date(params[:to])
          return nil if from.nil? || to.nil?

          from..to
        end

        def settlement_params
          params.require(:settlement).permit(
            :notes, :status,
            nozzle_readings_attributes: %i[id fuel_pump_nozzle_id opening_reading closing_reading testing_litres rollover unit_price _destroy],
            lube_lines_attributes: %i[id product_id quantity opening_stock closing_stock unit_price _destroy],
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

        def parse_date(value)
          Date.iso8601(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
