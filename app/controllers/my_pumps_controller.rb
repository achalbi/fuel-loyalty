class MyPumpsController < ApplicationController
  before_action :authenticate_user!

  def show
    authorize current_user, :manage_pump?

    load_form_state
  end

  def update
    authorize current_user, :manage_pump?

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
end
