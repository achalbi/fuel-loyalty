class ShiftCycle < ApplicationRecord
  has_many :shift_cycle_steps, -> { order(:position) }, dependent: :destroy, inverse_of: :shift_cycle
  has_many :shift_templates, through: :shift_cycle_steps
  has_many :shift_assignments, dependent: :restrict_with_exception

  scope :active, -> { where(active: true) }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :starts_on, presence: true
  validate :must_have_shift_cycle_steps

  def first_shift_template
    shift_cycle_steps.first&.shift_template
  end

  def effective_starts_at
    return if starts_on.blank? || first_shift_template.blank?

    Time.zone.parse("#{starts_on} #{first_shift_template.start_time_input_value}")
  rescue ArgumentError, TypeError
    nil
  end

  def shift_template_for(moment)
    window_for(moment)&.fetch(:shift_template, nil) || first_shift_template
  end

  def window_for(moment)
    return if shift_cycle_steps.empty?

    cycle_start_at = effective_starts_at
    return if cycle_start_at.blank?

    point_in_time = ShiftAssignment.normalize_effective_point(moment)
    return if point_in_time < cycle_start_at

    cycle_duration = cycle_duration_minutes
    return if cycle_duration <= 0

    elapsed_minutes = ((point_in_time - cycle_start_at) / 60).floor
    cycle_offset_minutes = elapsed_minutes - (elapsed_minutes % cycle_duration)
    position_in_cycle = elapsed_minutes % cycle_duration
    step_offset_minutes = 0

    shift_cycle_steps.each do |step|
      step_duration = step.shift_template.duration_minutes.to_i
      next_step_offset = step_offset_minutes + step_duration

      if position_in_cycle < next_step_offset
        step_starts_at = cycle_start_at + (cycle_offset_minutes + step_offset_minutes).minutes
        step_ends_at = step_starts_at + step_duration.minutes

        return {
          shift_template: step.shift_template,
          starts_at: step_starts_at,
          ends_at: step_ends_at,
          position: step.position
        }
      end

      step_offset_minutes = next_step_offset
    end

    nil
  end

  def valid_window_for?(shift_template:, starts_at:, ends_at:)
    window = window_for(starts_at)
    return false if window.blank?

    normalized_starts_at = ShiftAssignment.normalize_effective_point(starts_at).change(sec: 0)
    normalized_ends_at = ShiftAssignment.normalize_effective_point(ends_at).change(sec: 0)

    window[:shift_template] == shift_template &&
      window[:starts_at].change(sec: 0) == normalized_starts_at &&
      window[:ends_at].change(sec: 0) == normalized_ends_at
  end

  def sequence_label
    shift_cycle_steps.map { |step| step.shift_template.name }.join(" -> ")
  end

  def schedule_label
    "Each shift uses its saved duration"
  end

  def cycle_duration_minutes
    shift_cycle_steps.sum { |step| step.shift_template.duration_minutes.to_i }
  end

  def cycle_duration_label
    minutes = cycle_duration_minutes
    hours, remaining_minutes = minutes.divmod(60)
    parts = []
    parts << "#{hours} hour#{'s' unless hours == 1}" if hours.positive?
    parts << "#{remaining_minutes} min" if remaining_minutes.positive?
    parts.join(" ").presence || "0 min"
  end

  def starts_at_label
    return if effective_starts_at.blank?

    I18n.l(effective_starts_at, format: "%d %b %Y %I:%M %p")
  end

  def deletable?
    shift_assignments.none?
  end

  private

  def must_have_shift_cycle_steps
    errors.add(:base, "Choose at least one shift in the cycle.") if shift_cycle_steps.empty?
  end
end
