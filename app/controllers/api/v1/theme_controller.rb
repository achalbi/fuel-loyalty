module Api
  module V1
    # GET /api/v1/theme — the admin-configured primary color. The client derives
    # the full palette (strong/accent/soft/contrast) per docs/native-handoff/10.
    class ThemeController < Api::V1::PublicController
      def show
        render json: Api::V1::ThemeSerializer.call(ThemeSetting.current), status: :ok
      end
    end
  end
end
