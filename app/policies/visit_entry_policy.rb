class VisitEntryPolicy < ApplicationPolicy
  def index?
    staff_access?
  end

  def new?
    staff_access?
  end

  def create?
    staff_access?
  end

  private

  def staff_access?
    user&.admin? || user&.staff?
  end
end
