class ThemeSetting < ApplicationRecord
  DEFAULT_PRIMARY_COLOR = "#43B05C".freeze
  DARK_TEXT_COLOR = "#081E0F".freeze
  LIGHT_TEXT_COLOR = "#F7FFF8".freeze

  before_validation :normalize_primary_color

  validates :primary_color, presence: true, format: { with: /\A#[0-9A-F]{6}\z/, message: "must be a valid hex color" }

  def self.current
    first_or_initialize.tap do |theme_setting|
      theme_setting.primary_color = DEFAULT_PRIMARY_COLOR if theme_setting.primary_color.blank?
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    new(primary_color: DEFAULT_PRIMARY_COLOR)
  end

  def light_css_variables
    color = primary_color.presence || DEFAULT_PRIMARY_COLOR

    {
      "--fl-primary" => color,
      "--fl-primary-strong" => adjust_color(color, -0.14),
      "--fl-primary-accent" => adjust_color(color, 0.18),
      "--fl-primary-soft" => rgba_color(color, 0.14),
      "--fl-primary-contrast" => contrast_color_for(color),
      "--fl-primary-contrast-rgb" => rgb_string(contrast_color_for(color)),
      "--bs-primary-rgb" => rgb_string(color)
    }
  end

  def dark_css_variables
    color = adjust_color(primary_color.presence || DEFAULT_PRIMARY_COLOR, 0.16)

    {
      "--fl-primary" => color,
      "--fl-primary-strong" => adjust_color(color, 0.12),
      "--fl-primary-accent" => adjust_color(color, 0.18),
      "--fl-primary-soft" => rgba_color(color, 0.18),
      "--fl-primary-contrast" => contrast_color_for(color),
      "--fl-primary-contrast-rgb" => rgb_string(contrast_color_for(color)),
      "--bs-primary-rgb" => rgb_string(color)
    }
  end

  private

  def normalize_primary_color
    hex = primary_color.to_s.delete("#").upcase
    self.primary_color = hex.match?(/\A[0-9A-F]{6}\z/) ? "##{hex}" : primary_color
  end

  def adjust_color(hex_color, amount)
    rgb = rgb_components(hex_color).map do |component|
      adjusted = if amount.positive?
        component + ((255 - component) * amount)
      else
        component * (1 + amount)
      end

      adjusted.round.clamp(0, 255)
    end

    format("#%02X%02X%02X", *rgb)
  end

  def contrast_color_for(hex_color)
    red, green, blue = rgb_components(hex_color)
    brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000.0

    brightness >= 150 ? DARK_TEXT_COLOR : LIGHT_TEXT_COLOR
  end

  def rgba_color(hex_color, alpha)
    "rgba(#{rgb_string(hex_color)}, #{alpha})"
  end

  def rgb_string(hex_color)
    rgb_components(hex_color).join(", ")
  end

  def rgb_components(hex_color)
    value = hex_color.delete_prefix("#")
    value.scan(/../).map { |component| component.to_i(16) }
  end
end
