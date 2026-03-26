class SchedulerLease < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  scope :running, -> { where(running: true) }
end
