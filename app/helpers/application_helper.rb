module ApplicationHelper
  CUSTOM_VEHICLE_TYPE_ICON_ASSETS = {
    VehicleType::AUTO_RICKSHAW_ICON_NAME => "vehicle_type_icons/tuk-tuk.png",
    VehicleType::PICKUP_TRUCK_ICON_NAME => "vehicle_type_icons/pickup-truck.png",
    VehicleType::BIG_TRUCK_ICON_NAME => "vehicle_type_icons/big-truck.png"
  }.freeze

  def vehicle_type_icon_tag(icon_name, class_name: nil)
    return if icon_name.blank?

    asset_name = CUSTOM_VEHICLE_TYPE_ICON_ASSETS[icon_name.to_s]

    if asset_name.present?
      vehicle_type_custom_icon_image(icon_name.to_s, asset_name, class_name: class_name)
    else
      tag.i(nil, class: ["ti", icon_name, class_name].compact.join(" "), data: { vehicle_type_icon: icon_name })
    end
  end

  def dynamic_theme_style_tag(theme_setting = ThemeSetting.current)
    css = [
      ":root { #{css_variable_string(theme_setting.light_css_variables)} }",
      "html[data-theme=\"dark\"] { #{css_variable_string(theme_setting.dark_css_variables)} }"
    ].join("\n")

    content_tag(:style, css.html_safe)
  end

  private

  def vehicle_type_custom_icon_image(icon_name, asset_name, class_name: nil)
    classes = ["vehicle-type-custom-icon", "vehicle-type-custom-icon--#{icon_name.delete_prefix('custom-')}", class_name].compact.join(" ")

    tag.span(
      nil,
      class: classes,
      data: { vehicle_type_icon: icon_name },
      style: "--vehicle-type-icon-url: url('#{asset_path(asset_name)}')",
      aria: { hidden: true }
    )
  end

  def css_variable_string(variables)
    variables.map { |key, value| "#{key}: #{value};" }.join(" ")
  end
end
