module Api
  module V1
    class ThemeSerializer
      def self.call(theme_setting)
        {
          primary_color: theme_setting.primary_color,
          updated_at: theme_setting.updated_at&.iso8601,
        }
      end
    end
  end
end
