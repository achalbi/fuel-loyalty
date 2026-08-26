module Api
  module V1
    module Admin
      # D9 / Admin-12 / Admin-13 — the admin settlement console: list/filter
      # across pumps with cross-pump totals, read one with its audit trail, edit
      # any current/past settlement (change_reason required; points recompute on
      # a customer-linked change), and reconcile.
      class SettlementsController < Api::V1::Admin::BaseController
        before_action :set_settlement, only: %i[show update reconcile]

        # GET /api/v1/admin/settlements?business_date=&from=&to=&fuel_pump_id=&user_id=&status=&q=
        def index
          authorize DailySettlement, :admin_manage?
          scope = filtered_scope
          rows = scope.to_a
          body = {
            settlements: rows.map { |s| Api::V1::Staff::SettlementSerializer.summary(s) },
            total: rows.size,
            per_user_totals: per_user_totals(rows),
          }
          body[:cross_pump_totals] = cross_pump_totals(rows) if date_filtered_all_pumps?
          render json: body, status: :ok
        end

        # GET /api/v1/admin/settlements/:id — full settlement + audit trail.
        def show
          authorize @settlement, :admin_manage?
          render json: settlement_json(@settlement), status: :ok
        end

        # PATCH /api/v1/admin/settlements/:id — edit; change_reason + on_behalf_of_id required.
        def update
          authorize @settlement, :admin_manage?
          return render_missing_reason if change_reason.blank?
          return render_missing_on_behalf_of if on_behalf_of.nil?

          result = Settlement::Persister.call(
            settlement: @settlement, attributes: settlement_params, actor: current_user,
            admin_edit: true, change_reason: change_reason, on_behalf_of: on_behalf_of
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
          scope = DailySettlement.recent_first.includes(:fuel_pump, :recorded_by)
          scope = scope.where(business_date: date_range) if date_range
          scope = scope.where(fuel_pump_id: params[:fuel_pump_id]) if params[:fuel_pump_id].present?
          # Admin-12 — the per-user ("which FSM settled what") report cut.
          scope = scope.where(recorded_by_id: params[:user_id]) if params[:user_id].present?
          scope = scope.where(status: params[:status]) if params[:status].present?
          # Rule 17 — merged, so the search narrows the filters above rather than
          # escaping them. Same scope the web console uses, so the two cannot drift.
          scope.merge(DailySettlement.matching_text(params[:q]))
        end

        # A cross-pump rollup only means something once the rows are cut to a
        # period, and only while every pump is still in the cut. `date_range`
        # already folds `business_date` in, and returns nil for an unparseable
        # one, so a junk date reports no rollup rather than an all-zero one.
        def date_filtered_all_pumps?
          date_range.present? && params[:fuel_pump_id].blank?
        end

        FINANCIAL_FIELDS = %i[total_fuel_amount total_lube_amount total_discount_amount total_credit_amount
                              final_amount_to_settle counted_cash_amount shortage_amount].freeze

        # Admin-13: sum the day's financial (submitted/reconciled) settlements.
        def cross_pump_totals(rows)
          financial_totals(rows)
        end

        def financial_totals(rows)
          financial = rows.select { |s| s.submitted? || s.reconciled? }
          FINANCIAL_FIELDS.index_with { |field| financial.sum { |s| s.public_send(field).to_d }.to_f }
        end

        # Admin-12: the same rollup the web console shows — one row per FSM.
        def per_user_totals(rows)
          rows.group_by(&:recorded_by_id).map do |user_id, user_rows|
            settlement = user_rows.first
            {
              user_id: user_id,
              name: settlement.recorded_by&.display_name || settlement.fsm_name_snapshot,
              count: user_rows.size,
              pumps: user_rows.filter_map { |row| row.fuel_pump&.display_name }.uniq.sort,
              totals: financial_totals(user_rows),
            }
          end.sort_by { |row| row[:name].to_s }
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

        def render_missing_on_behalf_of
          render_error(status: 422, code: "on_behalf_of_required",
                       message: ::Admin::SettlementsController::ON_BEHALF_OF_REQUIRED_MESSAGE)
        end

        def change_reason
          params[:change_reason]
        end

        # Admin-12 — the FSM the admin is entering this edit for.
        def on_behalf_of
          return @on_behalf_of if defined?(@on_behalf_of)

          @on_behalf_of = User.kept.find_by(id: params[:on_behalf_of_id])
        end

        # `business_date` is the single-day cut the older clients still send; an
        # explicit from/to overrides it, resolved exactly as the web console
        # resolves it so the same query string cannot answer differently on the
        # two surfaces. Either end may stand alone — "everything since the 1st"
        # is as ordinary a question as a closed range.
        def date_range
          return @date_range if defined?(@date_range)

          @date_range = resolve_date_range
        end

        def resolve_date_range
          business_date = parse_date(params[:business_date])
          from = parse_date(params[:from]) || business_date
          to = parse_date(params[:to]) || business_date
          return from..to if from && to
          return (from..) if from
          return (..to) if to

          nil
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
