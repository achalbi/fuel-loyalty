module Staff
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_staff_access

    private

    def ensure_staff_access
      return if current_user&.admin? || current_user&.staff?

      raise Pundit::NotAuthorizedError, "not allowed"
    end

    def register_customer_prefill_path(phone_number: nil, vehicle_number: nil)
      new_staff_customer_path(
        {
          phone_number: Customer.normalize_phone_number(phone_number).presence,
          vehicle_number: Vehicle.normalize_vehicle_number(vehicle_number).presence
        }.compact_blank
      )
    end
  end
end
