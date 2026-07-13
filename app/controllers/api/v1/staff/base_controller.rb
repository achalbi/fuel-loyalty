module Api
  module V1
    module Staff
      # Base for authenticated staff+admin API endpoints. Mirrors the web
      # Staff::BaseController gate: any authenticated user must be admin OR staff.
      class BaseController < Api::V1::BaseController
        before_action :ensure_staff_access

        private

        def ensure_staff_access
          return if current_user&.admin? || current_user&.staff?

          raise Pundit::NotAuthorizedError, "not allowed"
        end
      end
    end
  end
end
