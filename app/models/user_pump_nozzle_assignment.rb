class UserPumpNozzleAssignment < ApplicationRecord
  belongs_to :user, inverse_of: :pump_nozzle_assignments
  belongs_to :fuel_pump_nozzle, inverse_of: :user_pump_nozzle_assignments

  validates :fuel_pump_nozzle_id, uniqueness: { scope: :user_id }
end
