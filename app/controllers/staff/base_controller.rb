module Staff
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_staff_access

    private

    def ensure_staff_access
      return if current_user&.admin? || current_user&.staff?

      raise Pundit::NotAuthorizedError, "not allowed"
    end
  end
end
