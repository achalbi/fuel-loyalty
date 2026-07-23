module Api
  module V1
    # GET/PATCH /api/v1/my_pump — self-service pump/nozzle assignment (own record).
    class MyPumpController < Api::V1::BaseController
      def show
        authorize current_user, :manage_pump?
        return render_daily_assignment_error unless staff_daily_assignment_date_allowed?

        render json: MyPumpSerializer.call(current_user, on: assignment_date), status: :ok
      end

      def update
        authorize current_user, :manage_pump?
        return render_daily_assignment_error unless staff_daily_assignment_date_allowed?

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
        resource_params(:user).permit(:fuel_pump_id, :assignment_date, assigned_fuel_pump_nozzle_ids: [])
      end

      def assignment_date
        raw = params[:assignment_date].presence || resource_params(:user)[:assignment_date].presence
        Date.iso8601(raw.to_s)
      rescue ArgumentError, TypeError
        Date.current
      end

      def staff_daily_assignment_date_allowed?
        !current_user.staff? || assignment_date == Date.current
      end

      def render_daily_assignment_error
        render_error(status: 422, code: "daily_assignment_only",
                     message: "Staff can only set a daily pump assignment for today.")
      end
    end
  end
end
