class ShiftAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :shift_template
  belongs_to :shift_cycle, optional: true

  scope :active, -> { where(active: true) }
  scope :effective_at, lambda { |moment|
    point_in_time = normalize_effective_point(moment)
    where("effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)", point_in_time, point_in_time)
  }
  scope :effective_on, ->(moment) { effective_at(moment) }

  before_validation :apply_effective_from_parts, if: :effective_from_parts_provided?

  validates :shift_template, presence: true
  validates :effective_from, presence: true
  validate :effective_to_must_follow_effective_from
  validate :shift_cycle_must_have_steps, if: -> { shift_cycle.present? }

  def effective_from_date=(value)
    @effective_from_date = value
    assign_effective_from_if_ready
  end

  def effective_from_time=(value)
    @effective_from_time = value
    assign_effective_from_if_ready
  end

  def effective_from_date
    return @effective_from_date if defined?(@effective_from_date)

    effective_from&.to_date
  end

  def effective_from_time
    return @effective_from_time if defined?(@effective_from_time)

    effective_from&.strftime("%H:%M")
  end

  def self.normalize_effective_point(value)
    return Time.zone.now.change(sec: 0) if value.blank?
    return value.in_time_zone if value.respond_to?(:in_time_zone) && !value.is_a?(Date)
    return value.in_time_zone.end_of_day if value.is_a?(Date)

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    Time.zone.now.change(sec: 0)
  end

  private

  def effective_from_parts_provided?
    defined?(@effective_from_date) || defined?(@effective_from_time)
  end

  def apply_effective_from_parts
    assign_effective_from_if_ready(force: true)
  end

  def effective_to_must_follow_effective_from
    return if effective_to.blank? || effective_from.blank?
    return if effective_to >= effective_from

    errors.add(:effective_to, "must be on or after the effective from date and time")
  end

  def shift_cycle_must_have_steps
    errors.add(:shift_cycle, "must contain at least one shift.") if shift_cycle.shift_cycle_steps.empty?
  end

  def assign_effective_from_if_ready(force: false)
    return unless force || (defined?(@effective_from_date) && defined?(@effective_from_time))

    effective_time = @effective_from_time.presence || shift_template&.start_time_input_value

    if @effective_from_date.blank? || effective_time.blank?
      self.effective_from = nil
      return
    end

    self.effective_from = Time.zone.parse("#{@effective_from_date} #{effective_time}")
  rescue ArgumentError, TypeError
    self.effective_from = nil
  end

  public

  def resolved_shift_template(at: Time.current)
    shift_template
  end
end
