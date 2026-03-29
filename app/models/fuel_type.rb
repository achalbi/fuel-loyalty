class FuelType < ApplicationRecord
  DEFAULT_OPTIONS = [
    ["Petrol", "petrol"],
    ["Diesel", "diesel"],
    ["CNG / LPG", "cng_lpg"]
  ].freeze
  DEFAULT_CODES = DEFAULT_OPTIONS.map(&:last).freeze
  CODE_FORMAT = /\A[a-z0-9]+(?:_[a-z0-9]+)*\z/

  has_many :vehicles, foreign_key: :fuel_type, primary_key: :code, inverse_of: false
  has_many :fuel_reward_rates, foreign_key: :fuel_type, primary_key: :code, inverse_of: false

  before_validation :normalize_name
  before_validation :assign_code_from_name
  before_validation :normalize_code

  before_destroy :ensure_not_used_by_vehicles
  before_destroy :destroy_reward_rates

  scope :active, -> { where(active: true) }

  validates :code, presence: true, uniqueness: { case_sensitive: false }, format: { with: CODE_FORMAT }
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :active, inclusion: { in: [true, false] }

  def self.supported_codes
    DEFAULT_CODES
  end

  def self.default_label_for(code)
    DEFAULT_OPTIONS.to_h.invert[code.to_s]
  end

  def self.for_settings
    all.to_a.sort_by { |record| [sort_index(record.code), record.name.to_s.downcase, record.code.to_s] }
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    DEFAULT_OPTIONS.map { |label, code| new(code: code, name: label, active: true) }
  end

  def self.active_codes
    active.order(:created_at, :id).pluck(:code).map(&:to_s)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    supported_codes
  end

  def self.active_options
    options_for(active_codes)
  end

  def self.active_for_settings
    for_settings.select(&:active?)
  end

  def self.available_options(selected: nil)
    selected_code = normalize_code_value(selected)
    codes = active_codes
    codes << selected_code if selected_code.present?

    options_for(codes.uniq)
  end

  def self.active_code?(code)
    active_codes.include?(normalize_code_value(code))
  end

  def self.label_for(code)
    normalized_code = normalize_code_value(code)
    return if normalized_code.blank?

    find_by(code: normalized_code)&.name.presence || default_label_for(normalized_code) || normalized_code.humanize
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    default_label_for(normalized_code) || normalized_code.humanize
  end

  def removable?
    !vehicles.exists?
  end

  def remove_error_message
    "cannot be removed while vehicles still use it"
  end

  def self.options_for(codes)
    normalized_codes = codes.filter_map { |code| normalize_code_value(code) }.uniq
    return [] if normalized_codes.empty?

    records = where(code: normalized_codes).index_by { |record| record.code.to_s }

    normalized_codes.sort_by { |code| [sort_index(code), records[code]&.name.to_s.downcase, code] }.filter_map do |code|
      label = records[code]&.name.presence || default_label_for(code) || code.humanize
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

  def self.normalize_code_value(value)
    value.to_s.parameterize(separator: "_").presence
  end
  private_class_method :normalize_code_value

  private

  def normalize_code
    self.code = code.to_s.parameterize(separator: "_").presence
  end

  def normalize_name
    self.name = name.to_s.squish.presence
  end

  def assign_code_from_name
    self.code = name if code.blank? && name.present?
  end

  def ensure_not_used_by_vehicles
    return if removable?

    errors.add(:base, remove_error_message)
    throw :abort
  end

  def destroy_reward_rates
    FuelRewardRate.where(fuel_type: code).delete_all
  end
end
