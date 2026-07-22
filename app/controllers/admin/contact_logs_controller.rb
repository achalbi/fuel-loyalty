module Admin
  # E5 — log an outreach event from the customer console.
  class ContactLogsController < BaseController
    def create
      @customer = Customer.find(params[:customer_id])
      authorize @customer, :show?
      ::Admin::Crm::ContactLogRecorder.call(customer: @customer, user: current_user, attrs: contact_log_params)
      redirect_to admin_customer_path(@customer), notice: "Contact logged."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_customer_path(@customer), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def contact_log_params
      params.require(:contact_log).permit(:channel, :outcome, :contacted_role, :customer_contact_id, :notes)
    end
  end
end
