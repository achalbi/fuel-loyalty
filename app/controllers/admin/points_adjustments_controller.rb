module Admin
  class PointsAdjustmentsController < BaseController
    def new
      authorize PointsLedger
    end

    def create
      authorize PointsLedger
      assign_prefill_values
      normalized_phone = Customer.normalize_phone_number(points_adjustment_params[:phone_number])

      unless Customer.valid_phone_number?(normalized_phone)
        flash.now[:alert] = "Phone number must be a 10 digit number."
        return render :new, status: :unprocessable_entity
      end

      customer = Customer.find_by(phone_number: normalized_phone)

      unless customer
        flash.now[:alert] = "Customer not found."
        return render :new, status: :unprocessable_entity
      end

      customer.points_ledgers.create!(
        points: points_adjustment_params[:points],
        entry_type: :adjust
      )

      redirect_to customer_path(customer), notice: "Points adjusted successfully."
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end

    private

    def points_adjustment_params
      params.require(:points_adjustment).permit(:phone_number, :points)
    end

    def assign_prefill_values
      return unless params[:points_adjustment].present?

      @prefill_phone_number = points_adjustment_params[:phone_number]
      @prefill_points = points_adjustment_params[:points]
    end
  end
end
