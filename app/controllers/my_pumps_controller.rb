class MyPumpsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_staff_or_admin!

  def show
    authorize current_user, :manage_pump?
    load_form_state
  end

  def update
    authorize current_user, :manage_pump?

    if current_user.update_pump_assignment(my_pump_params, on: assignment_date, assigned_by: current_user)
      redirect_to my_pump_path(assignment_date: assignment_date), notice: "My pump updated successfully."
    else
      load_form_state
      render :show, status: :unprocessable_entity
    end
  end

  private

  def ensure_staff_or_admin!
    return if current_user&.admin? || current_user&.staff?

    raise Pundit::NotAuthorizedError, "not allowed"
  end

  def my_pump_params
    params.require(:user).permit(:fuel_pump_id, :assignment_date, assigned_fuel_pump_nozzle_ids: [])
  end

  def load_form_state
    @assignable_fuel_pumps = FuelPump.includes(nozzles: :fuel_type_record).ordered.to_a
    @assignable_fuel_pump_nozzles = @assignable_fuel_pumps.index_with do |fuel_pump|
      fuel_pump.nozzles.active.ordered.to_a
    end
    @assignment_date = assignment_date
    @daily_pump_assignment = current_user.pump_assignment_for(on: @assignment_date)
  end

  def assignment_date
    raw = params[:assignment_date].presence || params.dig(:user, :assignment_date).presence
    Date.iso8601(raw.to_s)
  rescue ArgumentError, TypeError
    Date.current
  end
end
