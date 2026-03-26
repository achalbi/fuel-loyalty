class ShiftCycleStep < ApplicationRecord
  belongs_to :shift_cycle
  belongs_to :shift_template

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :shift_cycle_id }
end
