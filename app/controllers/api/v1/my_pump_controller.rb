module Api
  module V1
    # GET/PATCH /api/v1/my_pump — the caller's own pump/nozzle assignment.
    #
    # Writing is admin-only: staff must not set their own pump (S-MYPUMP), which
    # UserPolicy#manage_pump? enforces — no extra role guard is needed here.
    # Reading stays open to the owner (read_pump?) because the native transaction
    # and visit-entry screens fetch this endpoint to learn which nozzles to offer.
    class MyPumpController < Api::V1::BaseController
      def show
        authorize current_user, :read_pump?

        render json: MyPumpSerializer.call(current_user, on: assignment_date), status: :ok
      end

      def update
        authorize current_user, :manage_pump?

        if current_user.update_pump_assignment(my_pump_params, on: assignment_date, assigned_by: current_user)
          render json: MyPumpSerializer.call(current_user.reload, on: assignment_date)
            .merge(message: "My pump updated successfully."), status: :ok
        else
          render_error(
            status: 422,
            code: "validation_failed",
            message: current_user.errors.full_messages.to_sentence.presence || "Could not update My Pump.",
            details: current_user.errors.messages,
          )
        end
      end

      private

      def my_pump_params
        resource_params(:user).permit(:fuel_pump_id, assigned_fuel_pump_nozzle_ids: [])
      end

      # The assignment always lands on today. Older app builds still transmit a
      # device-local assignment_date; it is deliberately IGNORED rather than
      # rejected, so a clock-skewed device can still open and save My Pump.
      def assignment_date
        Date.current
      end
    end
  end
end
