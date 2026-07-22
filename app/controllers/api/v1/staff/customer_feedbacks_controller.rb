module Api
  module V1
    module Staff
      # E7 — FSMs capture a customer rating at the pump.
      class CustomerFeedbacksController < Api::V1::Staff::BaseController
        include CustomerFeedbackActions

        private

        def feedback_source
          "staff"
        end

        # Any authenticated staff/admin (enforced by the base controller) may record
        # feedback for a customer.
        def authorize_feedback
          authorize @customer, :show?
        end
      end
    end
  end
end
