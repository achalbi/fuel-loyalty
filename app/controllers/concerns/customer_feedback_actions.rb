# E7 — shared feedback index/create for the admin and staff APIs. The including
# controller supplies #feedback_source (who is recording) and #authorize_feedback.
module CustomerFeedbackActions
  extend ActiveSupport::Concern

  included do
    before_action :set_feedback_customer
  end

  def index
    authorize_feedback
    scope = @customer.customer_feedbacks.recent_first
    render json: Api::V1::CustomerFeedbackSerializer.collection(scope), status: :ok
  end

  def create
    authorize_feedback
    feedback = @customer.customer_feedbacks.new(feedback_params)
    feedback.source = feedback_source
    feedback.recorded_by = current_user
    feedback.save!
    render json: Api::V1::CustomerFeedbackSerializer.call(feedback), status: :created
  end

  private

  def set_feedback_customer
    @customer = Customer.find(params[:customer_id])
  end

  def feedback_params
    resource_params(:feedback).permit(:rating, :comment, :transaction_id, :visit_entry_id)
  end
end
