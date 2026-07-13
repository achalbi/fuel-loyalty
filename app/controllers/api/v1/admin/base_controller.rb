module Api
  module V1
    module Admin
      # Base for admin-only API endpoints. Every /api/v1/admin action requires an
      # authenticated admin (mirrors the web Admin::BaseController gate).
      class BaseController < Api::V1::BaseController
        before_action :ensure_admin

        private

        def ensure_admin
          raise Pundit::NotAuthorizedError, "not allowed" unless current_user&.admin?
        end
      end
    end
  end
end
