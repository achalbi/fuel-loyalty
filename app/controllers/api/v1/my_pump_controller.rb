module Api
  module V1
    # GET/PATCH /api/v1/my_pump — self-service pump/nozzle assignment (own record).
    # Always for today, for admins as well as staff: see MyPumpsController.
    class MyPumpController < Api::V1::BaseController
      # A read always serves today, whatever date was asked for: the payload
      # echoes `assignment_date`, so a client holding a stale date (an app left
      # open past midnight, or a build from before this rule) corrects itself
      # instead of erroring. A WRITE still refuses — landing a save on the wrong
      # day silently would be much worse.
      def show
        authorize current_user, :manage_pump?
        render json: MyPumpSerializer.call(current_user, on: assignment_date), status: :ok
      end

      def update
        authorize current_user, :manage_pump?
        return render_daily_assignment_error unless assignment_date_allowed?

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
        Date.current
      end

      # An unparseable date counts as "none supplied" — the client gets today
      # rather than a 422 it cannot act on.
      def requested_assignment_date
        raw = params[:assignment_date].presence || resource_params(:user)[:assignment_date].presence
        return nil if raw.blank?

        Date.iso8601(raw.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def assignment_date_allowed?
        requested = requested_assignment_date
        requested.nil? || requested == Date.current
      end

      # Error code kept stable for already-shipped native clients.
      def render_daily_assignment_error
        render_error(status: 422, code: "daily_assignment_only",
                     message: MyPumpsController::TODAY_ONLY_MESSAGE)
      end
    end
  end
end
