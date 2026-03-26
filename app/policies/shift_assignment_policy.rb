class ShiftAssignmentPolicy < ApplicationPolicy
  def create?
    user&.admin?
  end
end
