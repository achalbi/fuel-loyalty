module Api
  module V1
    class UserSerializer
      def self.call(user)
        {
          id: user.id,
          name: user.name,
          username: user.username,
          role: user.role, # "admin" | "staff"
          phone_number: user.phone_number,
          display_name: user.display_name,
          display_phone_number: user.display_phone_number,
          email: user.explicit_email,
          employee_code: user.employee_code,
          subtitle: user.subtitle,
          avatar_initial: user.avatar_initial,
          active: user.active,
        }
      end
    end
  end
end
