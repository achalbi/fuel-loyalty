module Api
  module V1
    module Admin
      # E5 — outreach log for a customer. Admin-only.
      class ContactLogsController < Api::V1::Admin::BaseController
        before_action :set_customer

        def index
          authorize :dashboard, :show?
          logs = @customer.contact_logs.recent_first
          render json: { contact_logs: logs.map { |log| ContactLogSerializer.call(log) } }, status: :ok
        end

        def create
          authorize :dashboard, :show?
          log = ::Admin::Crm::ContactLogRecorder.call(customer: @customer, user: current_user, attrs: contact_log_params)
          render json: ContactLogSerializer.call(log), status: :created
        end

        private

        def set_customer
          @customer = Customer.find(params[:customer_id])
        end

        def contact_log_params
          resource_params(:contact_log)
            .permit(:channel, :outcome, :contacted_role, :customer_contact_id, :notes, :contacted_at)
        end
      end
    end
  end
end
