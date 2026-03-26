class AttendanceRunPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def new?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def show?
    user&.admin?
  end

  def invalidate?
    user&.admin?
  end

  def mark_valid?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end
end
