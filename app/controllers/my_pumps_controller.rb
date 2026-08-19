class MyPumpsController < ApplicationController
  # Self-service "which pump am I on right now?" for whoever records fill-ups.
  # Admins see it as well as staff because TransactionPolicy/VisitEntryPolicy let
  # an admin record a transaction or visit entry, and TransactionCreator needs a
  # pump + nozzle for the caller in nozzle mode.
  #
  # The assignment is always for TODAY (admin feedback). A back-dated override
  # cannot change already-recorded rows — they snapshot their pump at capture —
  # so it only ever looks like it did something; forward-dating a roster belongs
  # on the admin's Assign Pump screen, not here.
  TODAY_ONLY_MESSAGE = "My Pump always applies to today.".freeze

  before_action :authenticate_user!

  def show
    authorize current_user, :manage_pump?
    return unless today_only!

    load_form_state
  end

  def update
    authorize current_user, :manage_pump?
    return unless today_only!

    if current_user.update_pump_assignment(my_pump_params, on: assignment_date, assigned_by: current_user)
      redirect_to my_pump_path, notice: "My pump updated successfully."
    else
      load_form_state
      render :show, status: :unprocessable_entity
    end
  end

  private

  def my_pump_params
    params.require(:user).permit(:fuel_pump_id, assigned_fuel_pump_nozzle_ids: [])
  end

  def load_form_state
    @assignable_fuel_pumps = FuelPump.includes(nozzles: :fuel_type_record).ordered.to_a
    @assignable_fuel_pump_nozzles = @assignable_fuel_pumps.index_with do |fuel_pump|
      fuel_pump.nozzles.active.ordered.to_a
    end
    @assignment_date = assignment_date
    @daily_pump_assignment = current_user.pump_assignment_for(on: @assignment_date)
  end

  # My Pump always applies to today — the screen no longer offers a date picker,
  # and any supplied date param is ignored so an override can't be back/post-dated.
  def assignment_date
    Date.current
  end

  # An unparseable date is treated as "none supplied" so a stale bookmark still
  # lands on today rather than erroring.
  def requested_assignment_date
    raw = params[:assignment_date].presence || params.dig(:user, :assignment_date).presence
    return nil if raw.blank?

    Date.iso8601(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def today_only!
    requested = requested_assignment_date
    return true if requested.nil? || requested == Date.current

    redirect_to my_pump_path, alert: TODAY_ONLY_MESSAGE
    false
  end
end
