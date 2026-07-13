module Api
  module V1
    module Admin
      # Richer admin view of a User. Builds on the shared Api::V1::UserSerializer
      # (id, name, username, role, phone_number, display_name, display_phone_number,
      # email, employee_code, subtitle, avatar_initial, active) and adds the audit
      # timestamps the admin CRM lists/detail views expose.
      class UserSerializer
        def self.call(user)
          Api::V1::UserSerializer.call(user).merge(
            created_at: user.created_at&.iso8601,
            updated_at: user.updated_at&.iso8601,
          )
        end
      end
    end
  end
end
