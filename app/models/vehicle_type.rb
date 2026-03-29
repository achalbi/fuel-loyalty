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
  AUTO_RICKSHAW_ICON_NAME = "custom-tuk-tuk"
  AUTO_RICKSHAW_ICON_LABEL = "Auto Rickshaw / 3 Wheeler"
  PICKUP_TRUCK_ICON_NAME = "custom-pickup-truck"
  PICKUP_TRUCK_ICON_LABEL = "Pickup Truck"
  BIG_TRUCK_ICON_NAME = "custom-big-truck"
  BIG_TRUCK_ICON_LABEL = "Big Truck"
  REMOVED_ICON_REPLACEMENTS = {
    "ti-car-suv" => "ti-car",
    "ti-car-4wd" => "ti-car",
    "ti-truck-delivery" => PICKUP_TRUCK_ICON_NAME,
    "ti-truck-loading" => BIG_TRUCK_ICON_NAME,
    "ti-rv-truck" => "ti-truck",
    "ti-ambulance" => "ti-truck",
    "ti-firetruck" => "ti-truck",
    "ti-forklift" => "ti-truck",
    "ti-caravan" => "ti-bus"
  }.freeze
  REMOVED_TWO_WHEELER_ICON_NAMES = %w[ti-motorbike ti-scooter ti-scooter-electric ti-moped].freeze
  ICON_OPTIONS = [
    { label: "Bike", value: "ti-bike" },
    { label: AUTO_RICKSHAW_ICON_LABEL, value: AUTO_RICKSHAW_ICON_NAME },
    { label: "Car", value: "ti-car" },
    { label: PICKUP_TRUCK_ICON_LABEL, value: PICKUP_TRUCK_ICON_NAME },
    { label: "Truck", value: "ti-truck" },
    { label: BIG_TRUCK_ICON_LABEL, value: BIG_TRUCK_ICON_NAME },
    { label: "Bus", value: "ti-bus" },
    { label: "Tractor", value: "ti-tractor" }
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

  def self.supported_icon_name_for(icon_name, code: nil, name: nil)
    normalized_icon_name = icon_name.to_s.squish.presence
    return if normalized_icon_name.blank?

    return suggested_icon_name_for(code: code, name: name) if REMOVED_TWO_WHEELER_ICON_NAMES.include?(normalized_icon_name)

    REMOVED_ICON_REPLACEMENTS.fetch(normalized_icon_name, normalized_icon_name)
  end

  def self.icon_label_for(icon_name, code: nil, name: nil)
    supported_icon_name = supported_icon_name_for(icon_name, code: code, name: name) || icon_name.to_s

    ICON_OPTIONS.find { |option| option[:value] == supported_icon_name }&.fetch(:label, nil).presence || supported_icon_name
  end

  def self.icon_name_for(code)
    normalized_code = normalize_code(code)
    return DEFAULT_ICON_NAME if normalized_code.blank?

    record = find_by(code: normalized_code)

    supported_icon_name_for(record&.icon_name, code: normalized_code, name: record&.name).presence ||
      suggested_icon_name_for(code: normalized_code, name: record&.name)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    suggested_icon_name_for(code: normalized_code)
  end

  def self.icon_map_for(codes)
    normalized_codes = codes.filter_map { |code| normalize_code(code) }.uniq
    return {} if normalized_codes.empty?

    records = where(code: normalized_codes).index_by { |record| record.code.to_s }

    normalized_codes.index_with do |code|
      record = records[code]

      supported_icon_name_for(record&.icon_name, code: code, name: record&.name).presence ||
        suggested_icon_name_for(code: code, name: record&.name)
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
    when /ambulance|firetruck|fire_truck|fire_engine|forklift/
      "ti-truck"
    when /tractor/
      "ti-tractor"
    when /bus|coach|caravan|camper|motorhome|rv/
      "ti-bus"
    when /three_wheeler|three_wheel|rickshaw|auto|trike/
      AUTO_RICKSHAW_ICON_NAME
    when /pickup/
      PICKUP_TRUCK_ICON_NAME
    when /big_truck|big_trucks|heavy_truck|heavy_trucks|delivery|cargo|goods|lorry|hcv|mcv|lcv/
      BIG_TRUCK_ICON_NAME
    when /truck/
      "ti-truck"
    when /suv|jeep|4wd|four_wheel_drive/
      "ti-car"
    when /motorbike|motor_cycle|motorcycle|moped|scooter|electric|ev|bike|bicycle|cycle|two_wheeler|two_wheel/
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
    self.icon_name = self.class.supported_icon_name_for(icon_name, code: code, name: name)
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
