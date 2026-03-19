module Admin
  class ThemeSettingsController < BaseController
    def show
      @theme_setting = ThemeSetting.current
      authorize @theme_setting
    end

    def update
      @theme_setting = ThemeSetting.current
      authorize @theme_setting

      if @theme_setting.update(theme_setting_params)
        redirect_to admin_theme_settings_path, notice: "Theme color updated successfully."
      else
        flash.now[:alert] = @theme_setting.errors.full_messages.to_sentence
        render :show, status: :unprocessable_entity
      end
    end

    private

    def theme_setting_params
      params.require(:theme_setting).permit(:primary_color)
    end
  end
end
