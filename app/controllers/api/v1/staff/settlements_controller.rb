module Api
  module V1
    module Staff
      # D1–D10 — the FSM Daily Settlement: hydrate a draft (new), create/submit,
      # list own settlements, read one, and update while still a draft. Reconcile
      # and admin edits live under the admin namespace.
      class SettlementsController < Api::V1::Staff::BaseController
        before_action :set_settlement, only: %i[show update]

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
          scope = accessible_settlements.recent_first.includes(:fuel_pump)
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
            attributes: settlement_params,
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
            attributes: settlement_params,
            actor: current_user
          )
          render json: SettlementSerializer.call(result.settlement), status: :ok
        end

        private

        def accessible_settlements
          current_user.admin? ? DailySettlement.all : DailySettlement.where(recorded_by: current_user)
        end

        def set_settlement
          @settlement = accessible_settlements.find(params[:id])
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
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
