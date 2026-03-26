class AttendanceRun < ApplicationRecord
  belongs_to :shift_template
  belongs_to :recorded_by, class_name: "User"
  has_many :attendance_entries, dependent: :destroy, inverse_of: :attendance_run

  accepts_nested_attributes_for :attendance_entries

  scope :invalid_records, -> { where(stale: true) }
  scope :valid_records, -> { where(stale: false) }

  validates :starts_at, :ends_at, :shift_name_snapshot, :duration_snapshot_minutes, presence: true
  validate :ends_at_must_follow_starts_at
  validate :must_include_attendance_entries
  validate :shift_window_must_be_unique

  before_validation :capture_shift_snapshot

  def status_counts
    attendance_entries.group_by(&:status).transform_values(&:count)
  end

  def record_state_label
    stale? ? "Invalid" : "Valid"
  end

  def conflicting_shift_window_exists?
    return false if exact_shift_window_scope.none?

    stale? ? exact_shift_window_scope.exists? : exact_shift_window_scope.valid_records.exists?
  end

  def can_mark_valid?
    stale? && !exact_shift_window_scope.exists?
  end

  private

  def exact_shift_window_scope
    return self.class.none if shift_template.blank? || starts_at.blank? || ends_at.blank?

    duplicate_scope = self.class.where(
      shift_template_id: shift_template_id,
      starts_at: starts_at,
      ends_at: ends_at
    )
    duplicate_scope = duplicate_scope.where.not(id: id) if persisted?
    duplicate_scope
  end

  def capture_shift_snapshot
    return unless shift_template.present?

    self.shift_name_snapshot = shift_template.name
    self.duration_snapshot_minutes = shift_template.duration_minutes
  end

  def ends_at_must_follow_starts_at
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "must be after the start time")
  end

  def must_include_attendance_entries
    return if attendance_entries.reject(&:marked_for_destruction?).any?

    errors.add(:attendance_entries, "must include at least one staff member")
  end

  def shift_window_must_be_unique
    return unless conflicting_shift_window_exists?

    errors.add(:base, "Attendance has already been recorded for this shift and time window.")
  end
end
