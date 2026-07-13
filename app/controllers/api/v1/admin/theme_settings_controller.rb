module Api
  module V1
    module Admin
      # GET/PATCH /api/v1/admin/theme_settings
      #
      # JSON mirror of the web Admin::ThemeSettingsController. Operates on the
      # ThemeSetting.current singleton. On PATCH, the CDN cache is purged only
      # when primary_color actually changed (saved_change_to_primary_color?),
      # matching the web side effect. An invalid hex color raises
      # ActiveRecord::RecordInvalid ("must be a valid hex color") which
      # Api::V1::BaseController renders as 422.
      class ThemeSettingsController < Api::V1::Admin::BaseController
        # GET /api/v1/admin/theme_settings
        def show
          @theme_setting = ThemeSetting.current
          authorize @theme_setting, :show?
          render json: Api::V1::ThemeSerializer.call(@theme_setting), status: :ok
        end

        # PATCH /api/v1/admin/theme_settings  { theme_setting: { primary_color } }
        def update
          @theme_setting = ThemeSetting.current
          authorize @theme_setting, :update?

          @theme_setting.update!(theme_setting_params)
          Cdn::Purger.call if @theme_setting.saved_change_to_primary_color?

          render json: Api::V1::ThemeSerializer.call(@theme_setting).merge(
            message: "Theme color updated successfully.",
          ), status: :ok
        end

        private

        def theme_setting_params
          resource_params(:theme_setting).permit(:primary_color)
        end
      end
    end
  end
end
