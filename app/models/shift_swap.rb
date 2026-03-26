class ShiftSwap < ApplicationRecord
  enum :swap_kind, { this_shift_only: 0, temporary: 1, permanent: 2 }, default: :this_shift_only, validate: true

  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"
  belongs_to :from_shift_template, class_name: "ShiftTemplate"
  belongs_to :to_shift_template, class_name: "ShiftTemplate", optional: true
  belongs_to :recorded_by, class_name: "User"

  validates :starts_at, :reason, presence: true
  validate :users_must_be_different
  validate :ends_at_must_follow_starts_at

  private

  def users_must_be_different
    return if from_user_id.blank? || to_user_id.blank?
    return unless from_user_id == to_user_id

    errors.add(:to_user, "must be different from the original staff member")
  end

  def ends_at_must_follow_starts_at
    return if ends_at.blank? || starts_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "must be after the start time")
  end
end
