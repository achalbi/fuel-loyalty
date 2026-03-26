class ShiftTemplate < ApplicationRecord
  attr_writer :duration_hours
  START_TIME_FORMAT = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/

  has_many :shift_assignments, dependent: :restrict_with_exception
  has_many :shift_cycle_steps, dependent: :restrict_with_exception
  has_many :shift_cycles, through: :shift_cycle_steps
  has_many :staff_members, through: :shift_assignments, source: :user
  has_many :attendance_runs, dependent: :restrict_with_exception
  has_many :shift_swaps_from, class_name: "ShiftSwap", foreign_key: :from_shift_template_id, dependent: :restrict_with_exception
  has_many :shift_swaps_to, class_name: "ShiftSwap", foreign_key: :to_shift_template_id, dependent: :restrict_with_exception

  scope :active, -> { where(active: true) }

  before_validation :normalize_start_time
  before_validation :apply_duration_hours_input, if: :duration_hours_input_provided?

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :start_time, presence: true, format: { with: START_TIME_FORMAT, message: "must use HH:MM" }
  validates :duration_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }

  def duration_hours
    return @duration_hours if defined?(@duration_hours)
    return if duration_minutes.blank?

    format_duration_hours(duration_minutes / 60.0)
  end

  def duration_label
    hours, minutes = duration_minutes.divmod(60)
    parts = []
    parts << "#{hours} hour#{'s' unless hours == 1}" if hours.positive?
    parts << "#{minutes} min" if minutes.positive?

    parts.join(" ").presence || "0 min"
  end

  def start_time_input_value
    start_time
  end

  def start_time_label
    return if start_time.blank?

    Time.zone.parse("2000-01-01 #{start_time}")&.strftime("%I:%M %p")
  rescue ArgumentError, TypeError
    start_time
  end

  def schedule_label
    [start_time.present? ? "Starts #{start_time_label}" : nil, duration_label].compact.join(" · ")
  end

  def current_shift_cycle(at: Time.current)
    active_cycles = shift_cycles.active.includes(:shift_cycle_steps).order(:starts_on, :name)
    return if active_cycles.empty?

    active_cycles.detect { |cycle| cycle.shift_template_for(at) == self } || active_cycles.first
  end

  def current_shift_cycle_label(at: Time.current)
    current_shift_cycle(at:)&.name || "No linked cycle"
  end

  private

  def normalize_start_time
    return if start_time.blank?

    parsed_time = Time.zone.parse("2000-01-01 #{start_time}")
    self.start_time = parsed_time.strftime("%H:%M")
  rescue ArgumentError, TypeError
    self.start_time = start_time.to_s.strip
  end

  def duration_hours_input_provided?
    defined?(@duration_hours)
  end

  def apply_duration_hours_input
    if @duration_hours.blank?
      self.duration_minutes = nil
      return
    end

    hours_value = BigDecimal(@duration_hours.to_s)
    self.duration_minutes = (hours_value * 60).round
    self.duration_minutes = nil if self.duration_minutes <= 0
  rescue ArgumentError
    self.duration_minutes = nil
  end

  def format_duration_hours(value)
    formatted = format("%.2f", value)
    formatted.sub(/\.00\z/, "").sub(/(\.\d)0\z/, '\1')
  end

end
