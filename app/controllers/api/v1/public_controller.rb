module Api
  module V1
    # Base for unauthenticated /api/v1 endpoints (loyalty lookup, theme, …).
    # Inherits the JSON error envelope but skips bearer authentication.
    class PublicController < BaseController
      skip_before_action :authenticate_api_user!
    end
  end
end
