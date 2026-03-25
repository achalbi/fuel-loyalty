class NotificationSchedule < ApplicationRecord
  FREQUENCIES = %w[once daily weekly monthly].freeze
  TIME_FORMAT = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/
  WEEKDAY_OPTIONS = [
    ["Sunday", 0],
    ["Monday", 1],
    ["Tuesday", 2],
    ["Wednesday", 3],
    ["Thursday", 4],
    ["Friday", 5],
    ["Saturday", 6]
  ].freeze

  scope :active, -> { where(active: true) }
  scope :recent_first, -> { order(active: :desc, created_at: :desc) }

  before_validation :normalize_scheduled_time
  before_validation :normalize_schedule_fields

  validates :title, presence: true
  validates :message, presence: true
  validates :frequency, presence: true, inclusion: { in: FREQUENCIES }
  validates :scheduled_time, presence: true, format: { with: TIME_FORMAT }
  validates :day_of_week, inclusion: { in: 0..6 }, allow_nil: true
  validates :day_of_month, inclusion: { in: 1..31 }, allow_nil: true

  validate :required_schedule_fields_for_frequency

  def scheduled_hour
    scheduled_time.to_s.split(":").first.to_i
  end

  def scheduled_minute
    scheduled_time.to_s.split(":").last.to_i
  end

  def scheduled_at_on(date, zone: Time.zone)
    zone.local(date.year, date.month, date.day, scheduled_hour, scheduled_minute)
  end

  def frequency_label
    frequency.to_s.titleize
  end

  def schedule_summary
    case frequency
    when "once"
      return "One time" if scheduled_date.blank?

      "One time on #{scheduled_date.strftime('%d %b %Y')} at #{scheduled_time}"
    when "daily"
      "Daily at #{scheduled_time}"
    when "weekly"
      weekday = WEEKDAY_OPTIONS.find { |(_label, value)| value == day_of_week }&.first || "Selected day"
      "Weekly on #{weekday} at #{scheduled_time}"
    when "monthly"
      "Monthly on day #{day_of_month} at #{scheduled_time}"
    else
      scheduled_time.to_s
    end
  end

  private

  def normalize_scheduled_time
    return if scheduled_time.blank?

    parsed = Time.zone.strptime(scheduled_time.to_s.strip, "%H:%M")
    self.scheduled_time = parsed.strftime("%H:%M")
  rescue ArgumentError
    self.scheduled_time = scheduled_time.to_s.strip
  end

  def normalize_schedule_fields
    self.scheduled_date = nil if frequency != "once"
    self.day_of_week = nil if frequency != "weekly"
    self.day_of_month = nil if frequency != "monthly"
  end

  def required_schedule_fields_for_frequency
    case frequency
    when "once"
      errors.add(:scheduled_date, "can't be blank") if scheduled_date.blank?
    when "weekly"
      errors.add(:day_of_week, "can't be blank") if day_of_week.blank?
    when "monthly"
      errors.add(:day_of_month, "can't be blank") if day_of_month.blank?
    end
  end
end
