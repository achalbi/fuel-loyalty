module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin!

    private

    def ensure_admin!
      raise Pundit::NotAuthorizedError, "not allowed" unless current_user&.admin?
    end
  end
end
