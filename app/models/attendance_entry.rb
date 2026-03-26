class AttendanceEntry < ApplicationRecord
  enum :status, { present: 0, absent: 1, late: 2, half_day: 3, leave: 4, off: 5 }, default: :present, validate: true

  belongs_to :attendance_run
  belongs_to :scheduled_user, class_name: "User"
  belongs_to :actual_user, class_name: "User", optional: true
  belongs_to :replacement_user, class_name: "User", optional: true
  belongs_to :last_overridden_by, class_name: "User", optional: true

  has_many :attendance_entry_changes, dependent: :destroy

  validates :scheduled_user, presence: true
  validate :check_out_must_follow_check_in

  before_validation :sync_actual_user

  def worker_name
    return actual_user.display_name if actual_user.present?
    return external_replacement_name if external_replacement_name.present?
    return "Not covered" if absent?

    scheduled_user.display_name
  end

  private

  def sync_actual_user
    self.actual_user = replacement_user if replacement_user.present?
    return if actual_user.present? || external_replacement_name.present? || absent?

    self.actual_user = scheduled_user
  end

  def check_out_must_follow_check_in
    return if check_in_at.blank? || check_out_at.blank?
    return if check_out_at >= check_in_at

    errors.add(:check_out_at, "must be after check in")
  end
end
