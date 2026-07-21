module Api
  module V1
    module Staff
      # B2 — the FSM per-visit CustomerDetailsEntry capture + a per-pump/day list.
      class VisitEntriesController < Api::V1::Staff::BaseController
        # GET /api/v1/staff/visit_entries?date=&fuel_pump_id=
        # Defaults to the caller's My Pump + today (the settlement-day view).
        def index
          authorize VisitEntry, :index?
          date = parse_date(params[:date]) || Date.current
          pump = FuelPump.find_by(id: params[:fuel_pump_id]) || current_user.transaction_fuel_pump

          entries = pump ? VisitEntry.for_pump_day(pump, date).recent_first.includes(:customer, :fuel_pump) : VisitEntry.none
          render json: {
            visit_entries: entries.map { |entry| VisitEntrySerializer.call(entry) },
            total: entries.size,
            date: date.iso8601,
            fuel_pump_id: pump&.id,
          }, status: :ok
        end

        # POST /api/v1/staff/visit_entries  { visit_entry: {...}, create_transaction: bool }
        def create
          authorize VisitEntry, :create?

          result = VisitEntryRecorder.call(
            user: current_user,
            attributes: visit_entry_params,
            create_transaction: params[:create_transaction],
            fuel_pump_nozzle_id: params[:fuel_pump_nozzle_id],
          )

          render json: {
            visit_entry: VisitEntrySerializer.call(result.visit_entry),
            points_earned: result.points_earned,
            transaction_id: result.transaction&.id,
          }, status: :created
        end

        private

        def visit_entry_params
          params.require(:visit_entry).permit(
            :customer_id, :vehicle_id, :fuel_pump_id, :entry_date, :vehicle_number,
            :driver_name, :driver_phone_number, :litres, :fuel_type_code, :discount_amount,
            :fleet_otp, :transport_name, :manager_name, :manager_phone_number,
            :owner_name, :owner_phone_number, :approx_vehicle_count
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
