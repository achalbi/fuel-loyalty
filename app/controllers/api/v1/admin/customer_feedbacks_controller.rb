module Api
  module V1
    module Admin
      # E7 — admin-captured customer feedback.
      class CustomerFeedbacksController < Api::V1::Admin::BaseController
        include CustomerFeedbackActions

        private

        def feedback_source
          "admin"
        end

        def authorize_feedback
          authorize :dashboard, :show?
        end
      end
    end
  end
end
