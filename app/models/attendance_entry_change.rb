class AttendanceEntryChange < ApplicationRecord
  belongs_to :attendance_entry
  belongs_to :changed_by, class_name: "User"

  validates :change_reason, presence: true
end
