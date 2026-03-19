module Staff
  class RedemptionsController < BaseController
    def new
      authorize PointsLedger, :redeem?
      assign_prefill_values
    end

    def create
      authorize PointsLedger, :redeem?
      result = PointsRedeemer.call(**redemption_params.to_h.symbolize_keys)

      redirect_to customer_path(result.customer), notice: "#{result.points_redeemed} points redeemed successfully."
    rescue ActiveRecord::RecordInvalid => e
      @errors = e.record.errors.full_messages
      assign_prefill_values
      render :new, status: :unprocessable_entity
    end

    private

    def assign_prefill_values
      return unless params[:redemption].present?

      @prefill_phone_number = redemption_params[:phone_number]
      @prefill_points = redemption_params[:points]
    end

    def redemption_params
      params.require(:redemption).permit(:phone_number, :points)
    end
  end
end
