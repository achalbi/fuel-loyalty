module Admin
  # E7 — capture a customer rating from the admin customer console.
  class FeedbacksController < BaseController
    def create
      @customer = Customer.find(params[:customer_id])
      authorize @customer, :show?
      feedback = @customer.customer_feedbacks.new(feedback_params)
      feedback.source = "admin"
      feedback.recorded_by = current_user
      feedback.save!
      redirect_to admin_customer_path(@customer), notice: "Feedback recorded."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_customer_path(@customer), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def feedback_params
      params.require(:feedback).permit(:rating, :comment)
    end
  end
end
