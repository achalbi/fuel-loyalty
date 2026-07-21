module Staff
  # B2 — the FSM per-visit CustomerDetailsEntry capture (web). Litres are the
  # source of truth; ₹ is derived later. See docs/acefuels/13-spec-customer-crm-capture.md.
  class VisitEntriesController < BaseController
    def index
      authorize VisitEntry, :index?
      @entry_date = parse_date(params[:date]) || Date.current
      @fuel_pump = FuelPump.find_by(id: params[:fuel_pump_id]) || current_user.transaction_fuel_pump
      @visit_entries =
        if @fuel_pump
          VisitEntry.for_pump_day(@fuel_pump, @entry_date).recent_first.includes(:customer, :fuel_pump)
        else
          VisitEntry.none
        end
      @fuel_pumps = FuelPump.active.ordered.to_a
    end

    def new
      authorize VisitEntry, :new?
      @visit_entry = VisitEntry.new(entry_date: Date.current, fuel_pump: current_user.transaction_fuel_pump)
      load_form_options
    end

    def create
      authorize VisitEntry, :create?
      result = VisitEntryRecorder.call(user: current_user, attributes: visit_entry_params)
      redirect_to staff_visit_entries_path(date: result.visit_entry.entry_date, fuel_pump_id: result.visit_entry.fuel_pump_id),
        notice: "Visit captured: #{format_litres(result.visit_entry.litres)} L for #{result.visit_entry.vehicle_number}."
    rescue ActiveRecord::RecordInvalid => error
      @visit_entry = VisitEntry.new(visit_entry_params)
      error.record.errors.each { |e| @visit_entry.errors.add(e.attribute, e.message) }
      load_form_options
      render :new, status: :unprocessable_entity
    end

    private

    def load_form_options
      @fuel_pumps = FuelPump.active.ordered.to_a
      @fuel_type_options = FuelType.active_options
    end

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

    def format_litres(value)
      value.to_d.to_s("F").sub(/\.?0+\z/, "")
    end
  end
end
