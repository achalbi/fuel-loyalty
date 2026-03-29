class VehicleType < ApplicationRecord
  DEFAULT_OPTIONS = [
    ["Two-Wheeler", "two_wheeler"],
    ["Three-Wheeler", "three_wheeler"],
    ["LMV", "lmv"],
    ["LCV", "lcv"],
    ["MCV", "mcv"],
    ["HCV", "hcv"]
  ].freeze
  DEFAULT_CODES = DEFAULT_OPTIONS.map(&:last).freeze
  APP_LABEL_SOURCES = %w[name short_name].freeze
  DEFAULT_APP_LABEL_SOURCE = "short_name"
  ICON_OPTIONS = [
    { label: "Bike", value: "ti-bike" },
    { label: "Motorbike", value: "ti-motorbike" },
    { label: "Auto Rickshaw / 3 Wheeler", value: "ti-moped" },
    { label: "Scooter", value: "ti-scooter" },
    { label: "Electric Scooter", value: "ti-scooter-electric" },
    { label: "Car", value: "ti-car" },
    { label: "SUV", value: "ti-car-suv" },
    { label: "4WD", value: "ti-car-4wd" },
    { label: "Truck", value: "ti-truck" },
    { label: "Delivery Truck", value: "ti-truck-delivery" },
    { label: "RV Truck", value: "ti-rv-truck" },
    { label: "Bus", value: "ti-bus" },
    { label: "Ambulance", value: "ti-ambulance" },
    { label: "Firetruck", value: "ti-firetruck" },
    { label: "Tractor", value: "ti-tractor" },
    { label: "Caravan", value: "ti-caravan" },
    { label: "Forklift", value: "ti-forklift" }
  ].freeze
  ICON_NAMES = ICON_OPTIONS.map { |option| option[:value] }.freeze
  DEFAULT_ICON_NAME = "ti-car"
  CODE_FORMAT = /\A[a-z]+(?:_[a-z]+)*\z/

  has_many :vehicles, foreign_key: :vehicle_kind, primary_key: :code, inverse_of: false

  before_validation :assign_default_app_label_source
  before_validation :normalize_name
  before_validation :normalize_short_name
  before_validation :normalize_app_label_source
  before_validation :assign_short_name_from_name
  before_validation :assign_code_from_name
  before_validation :normalize_code
  before_validation :normalize_icon_name
  before_validation :assign_icon_name

  before_destroy :ensure_not_used_by_vehicles

  scope :active, -> { where(active: true) }

  validates :code,
    presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: CODE_FORMAT, message: "only allows lowercase letters and underscores" }
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :short_name, presence: true
  validates :app_label_source, inclusion: { in: APP_LABEL_SOURCES }
  validates :icon_name, presence: true, inclusion: { in: ICON_NAMES }
  validates :active, inclusion: { in: [true, false] }

  def self.supported_codes
    DEFAULT_CODES
  end

  def self.default_label_for(code)
    DEFAULT_OPTIONS.to_h.invert[normalize_code(code)]
  end

  def self.for_settings
    all.to_a.sort_by { |record| [sort_index(record.code), record.name.to_s.downcase, record.code.to_s] }
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    DEFAULT_OPTIONS.map do |label, code|
      new(
        code: code,
        name: label,
        short_name: label,
        app_label_source: DEFAULT_APP_LABEL_SOURCE,
        icon_name: suggested_icon_name_for(code: code, name: label),
        active: true
      )
    end
  end

  def self.active_codes
    active.order(:created_at, :id).pluck(:code).map(&:to_s)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    supported_codes
  end

  def self.active_options
    options_for(active_codes)
  end

  def self.available_options(selected: nil)
    selected_code = normalize_code(selected)
    codes = active_codes
    codes << selected_code if selected_code.present?

    options_for(codes.uniq)
  end

  def self.active_code?(code)
    active_codes.include?(normalize_code(code))
  end

  def self.icon_options
    ICON_OPTIONS
  end

  def self.icon_name_for(code)
    normalized_code = normalize_code(code)
    return DEFAULT_ICON_NAME if normalized_code.blank?

    find_by(code: normalized_code)&.icon_name.presence || suggested_icon_name_for(code: normalized_code)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    suggested_icon_name_for(code: normalized_code)
  end

  def self.icon_map_for(codes)
    normalized_codes = codes.filter_map { |code| normalize_code(code) }.uniq
    return {} if normalized_codes.empty?

    records = where(code: normalized_codes).index_by { |record| record.code.to_s }

    normalized_codes.index_with do |code|
      records[code]&.icon_name.presence || suggested_icon_name_for(code: code)
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    normalized_codes.index_with { |code| suggested_icon_name_for(code: code) }
  end

  def self.label_for(code)
    normalized_code = normalize_code(code)
    return if normalized_code.blank?

    record = find_by(code: normalized_code)
    record&.app_label.presence || record&.name.presence || default_label_for(normalized_code) || normalized_code.humanize
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    default_label_for(normalized_code) || normalized_code.humanize
  end

  def app_label
    preferred_app_label.presence || name
  end

  def app_label_source_name?
    app_label_source == "name"
  end

  def app_label_source_short_name?
    app_label_source == "short_name"
  end

  def self.suggested_icon_name_for(code: nil, name: nil)
    normalized_text = [code, name].filter_map { |value| normalize_code(value) }.join("_")
    return DEFAULT_ICON_NAME if normalized_text.blank?

    case normalized_text
    when /ambulance/
      "ti-ambulance"
    when /firetruck|fire_truck|fire_engine/
      "ti-firetruck"
    when /tractor/
      "ti-tractor"
    when /bus|coach/
      "ti-bus"
    when /caravan|camper|motorhome|rv/
      "ti-caravan"
    when /forklift/
      "ti-forklift"
    when /three_wheeler|three_wheel|rickshaw|auto|trike/
      "ti-moped"
    when /pickup|delivery|cargo|goods|lorry|truck|hcv|mcv|lcv/
      "ti-truck"
    when /suv|jeep|4wd|four_wheel_drive/
      "ti-car-suv"
    when /motorbike|motor_cycle|motorcycle/
      "ti-motorbike"
    when /moped/
      "ti-moped"
    when /scooter|electric|ev/
      "ti-scooter-electric"
    when /bike|bicycle|cycle|two_wheeler|two_wheel/
      "ti-bike"
    else
      DEFAULT_ICON_NAME
    end
  end

  def removable?
    !vehicles.exists?
  end

  def remove_error_message
    "cannot be removed while vehicles still use it"
  end

  def self.options_for(codes)
    normalized_codes = codes.filter_map { |code| normalize_code(code) }.uniq
    return [] if normalized_codes.empty?

    records = where(code: normalized_codes).index_by { |record| record.code.to_s }

    normalized_codes.sort_by { |code| [sort_index(code), records[code]&.name.to_s.downcase, code] }.filter_map do |code|
      label = records[code]&.app_label.presence || records[code]&.name.presence || default_label_for(code) || code.humanize
      [label, code] if label.present?
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    DEFAULT_OPTIONS.select { |_label, code| normalized_codes.include?(code) }
  end
  private_class_method :options_for

  def self.sort_index(code)
    DEFAULT_CODES.index(code.to_s) || DEFAULT_CODES.length
  end
  private_class_method :sort_index

  def self.normalize_code(value)
    value.to_s.tr("-", "_").parameterize(separator: "_").tr("-", "_").presence
  end

  private

  def normalize_code
    self.code = self.class.normalize_code(code)
  end

  def normalize_name
    self.name = name.to_s.squish.presence
  end

  def normalize_short_name
    self.short_name = short_name.to_s.squish.presence
  end

  def normalize_app_label_source
    self.app_label_source = app_label_source.to_s.presence
  end

  def normalize_icon_name
    self.icon_name = icon_name.to_s.squish.presence
  end

  def assign_short_name_from_name
    self.short_name = name if short_name.blank? && name.present?
  end

  def assign_default_app_label_source
    self.app_label_source = DEFAULT_APP_LABEL_SOURCE if app_label_source.blank?
  end

  def assign_code_from_name
    self.code = name if code.blank? && name.present?
  end

  def assign_icon_name
    self.icon_name = self.class.suggested_icon_name_for(code: code, name: name) if icon_name.blank?
  end

  def preferred_app_label
    if app_label_source_short_name?
      short_name
    else
      name
    end
  end

  def ensure_not_used_by_vehicles
    return if removable?

    errors.add(:base, remove_error_message)
    throw :abort
  end
end
