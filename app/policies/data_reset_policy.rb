class DataResetPolicy < ApplicationPolicy
  def show?
    user&.admin?
  end

  def create?
    show?
  end
end
