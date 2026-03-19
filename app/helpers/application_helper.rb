module ApplicationHelper
  def dynamic_theme_style_tag
    theme_setting = ThemeSetting.current
    css = [
      ":root { #{css_variable_string(theme_setting.light_css_variables)} }",
      "html[data-theme=\"dark\"] { #{css_variable_string(theme_setting.dark_css_variables)} }"
    ].join("\n")

    content_tag(:style, css.html_safe)
  end

  private

  def css_variable_string(variables)
    variables.map { |key, value| "#{key}: #{value};" }.join(" ")
  end
end
