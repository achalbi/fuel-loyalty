module Api
  module V1
    # GET/PATCH /api/v1/my_pump — self-service pump/nozzle assignment (own record).
    class MyPumpController < Api::V1::BaseController
      def show
        authorize current_user, :manage_pump?
        render json: MyPumpSerializer.call(current_user), status: :ok
      end

      def update
        authorize current_user, :manage_pump?
        if current_user.update_pump_assignment(my_pump_params)
          render json: MyPumpSerializer.call(current_user.reload)
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
    end
  end
end
