module Api
  module V1
    module Staff
      # D1–D10 — the FSM Daily Settlement: hydrate a draft (new), create/submit,
      # list own settlements, read one, and update while still a draft. Reconcile
      # and admin edits live under the admin namespace.
      class SettlementsController < Api::V1::Staff::BaseController
        before_action :set_settlement, only: %i[show update]
        before_action :reject_edit_of_other_operators_settlement!, only: :update

        # GET /api/v1/staff/settlements/new — pre-filled draft for pump/date/shift.
        def new
          authorize DailySettlement, :new?
          result = Settlement::Builder.call(
            user: current_user,
            fuel_pump_id: params[:fuel_pump_id],
            business_date: params[:business_date],
            shift_template_id: params[:shift_template_id]
          )
          render json: SettlementDraftSerializer.call(result), status: :ok
        end

        # GET /api/v1/staff/settlements?business_date=&fuel_pump_id=
        def index
          authorize DailySettlement, :index?
          scope = viewable_settlements.recent_first.includes(:fuel_pump)
          scope = scope.for_date(parse_date(params[:business_date])) if params[:business_date].present?
          scope = scope.where(fuel_pump_id: params[:fuel_pump_id]) if params[:fuel_pump_id].present?

          rows = scope.to_a
          render json: {
            settlements: rows.map { |s| SettlementSerializer.summary(s) },
            total: rows.size,
          }, status: :ok
        end

        # GET /api/v1/staff/settlements/:id
        def show
          authorize @settlement, :show?
          render json: SettlementSerializer.call(@settlement), status: :ok
        end

        # POST /api/v1/staff/settlements
        def create
          authorize DailySettlement, :create?
          reject_reconcile_by_staff!

          result = Settlement::Persister.call(
            settlement: DailySettlement.new,
            attributes: with_legacy_phonepe_amounts(settlement_params),
            actor: current_user
          )
          render json: SettlementSerializer.call(result.settlement), status: :created
        end

        # PATCH /api/v1/staff/settlements/:id — draft edits only.
        def update
          authorize @settlement, :update?
          return render_locked if @settlement.locked?

          reject_reconcile_by_staff!
          result = Settlement::Persister.call(
            settlement: @settlement,
            attributes: with_legacy_phonepe_amounts(settlement_params),
            actor: current_user
          )
          render json: SettlementSerializer.call(result.settlement), status: :ok
        end

        private

        # Item 10 replaced the two fixed PhonePe columns with free-form digital
        # receipt lines, but an app build already on a phone still posts
        # `phonepe_pos_amount` / `phonepe_scanner_amount`. Fold those into the
        # matching labelled rows so an operator who hasn't updated keeps
        # recording receipts correctly. Only the API needs this — the web app is
        # served fresh on every request.
        LEGACY_RECEIPT_LABELS = {
          phonepe_pos_amount: "PhonePe POS",
          phonepe_scanner_amount: "PhonePe Scanner"
        }.freeze

        def with_legacy_phonepe_amounts(attributes)
          legacy = LEGACY_RECEIPT_LABELS.filter_map do |key, label|
            raw = params.dig(:settlement, key)
            next if raw.nil?

            existing = @settlement&.digital_receipts&.find { |row| row.label.to_s.casecmp?(label) }
            { id: existing&.id, label: label, amount: raw }.compact
          end
          return attributes if legacy.none?

          supplied = Array(attributes[:digital_receipts_attributes])
          already_labelled = supplied.map { |row| row[:label].to_s.downcase }
          attributes.merge(
            digital_receipts_attributes: supplied + legacy.reject { |row| already_labelled.include?(row[:label].downcase) }
          )
        end

        # Mirrors the web controller: an FSM reads any settlement for a pump
        # they're posted to, but only writes their own (staff feedback item 6).
        def viewable_settlements
          return DailySettlement.all if current_user.admin?

          DailySettlement
            .where(recorded_by: current_user)
            .or(DailySettlement.where(fuel_pump_id: current_user.settlement_pump_ids))
        end

        # No admin branch. An admin editing here would reach the persister with
        # neither `admin_edit:` nor `recorded_for:`, so the change would land with
        # no settlement_changes row and no mandatory reason — the unaudited write
        # path staff feedback item 3 closes. Admins correct via /api/v1/admin.
        def editable_settlements
          DailySettlement.where(recorded_by: current_user)
        end

        def set_settlement
          @settlement = viewable_settlements.find(params[:id])
        end

        def reject_edit_of_other_operators_settlement!
          return if editable_settlements.exists?(id: @settlement.id)

          raise Pundit::NotAuthorizedError, "settlement recorded by another operator"
        end

        # Only admins reconcile; a staff-supplied reconciled status is refused.
        def reject_reconcile_by_staff!
          return if current_user.admin?
          return unless params.dig(:settlement, :status).to_s == "reconciled"

          raise Pundit::NotAuthorizedError, "staff cannot reconcile"
        end

        def render_locked
          render_error(status: :conflict, code: "settlement_locked",
                       message: "This settlement is locked and can no longer be edited.")
        end

        def settlement_params
          params.require(:settlement).permit(
            :fuel_pump_id, :business_date, :shift_template_id, :status,
            :notes,
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

        def parse_date(value)
          Date.iso8601(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
