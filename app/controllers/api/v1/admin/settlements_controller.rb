module Api
  module V1
    module Admin
      # D9 / Admin-12 / Admin-13 — the admin settlement console: list/filter
      # across pumps with cross-pump totals, read one with its audit trail, edit
      # any current/past settlement (change_reason required; points recompute on
      # a customer-linked change), and reconcile.
      class SettlementsController < Api::V1::Admin::BaseController
        before_action :set_settlement, only: %i[show update reconcile]

        # GET /api/v1/admin/settlements?business_date=&from=&to=&fuel_pump_id=&status=
        def index
          authorize DailySettlement, :admin_manage?
          scope = filtered_scope
          rows = scope.to_a
          body = {
            settlements: rows.map { |s| Api::V1::Staff::SettlementSerializer.summary(s) },
            total: rows.size,
          }
          body[:cross_pump_totals] = cross_pump_totals(rows) if single_date_all_pumps?
          render json: body, status: :ok
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

        def filtered_scope
          scope = DailySettlement.recent_first.includes(:fuel_pump)
          scope = scope.for_date(parse_date(params[:business_date])) if params[:business_date].present?
          scope = scope.where(business_date: date_range) if date_range
          scope = scope.where(fuel_pump_id: params[:fuel_pump_id]) if params[:fuel_pump_id].present?
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope
        end

        def single_date_all_pumps?
          params[:business_date].present? && params[:fuel_pump_id].blank?
        end

        # Admin-13: sum the day's financial (submitted/reconciled) settlements.
        def cross_pump_totals(rows)
          financial = rows.select { |s| s.submitted? || s.reconciled? }
          %i[total_fuel_amount total_lube_amount total_discount_amount total_credit_amount
             final_amount_to_settle counted_cash_amount shortage_amount]
            .index_with { |field| financial.sum { |s| s.public_send(field).to_d }.to_f }
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
