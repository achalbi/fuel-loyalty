class ShiftTemplatePolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin?
  end
end
